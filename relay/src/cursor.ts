import { mkdtemp, rm } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Agent, CursorAgentError, type RunResult, type TokenUsage } from "@cursor/sdk";
import type { ZodType } from "zod";
import type { AppDb } from "./db.js";
import { extractJson, InvalidJsonError } from "./json.js";
import { Semaphore, TimeoutError, withTimeout } from "./limit.js";

export interface Completion {
  text: string;
  runId: string;
  status: string;
  usage?: TokenUsage;
  model: string;
}

export class RunFailedError extends Error {
  constructor(
    message: string,
    readonly runId: string,
  ) {
    super(message);
    this.name = "RunFailedError";
  }
}

interface AgentLike {
  send(
    message: string,
    options?: {
      onDelta?: (args: { update: { type: string; text?: string } }) => void | Promise<void>;
    },
  ): Promise<RunLike>;
  [Symbol.asyncDispose](): Promise<void>;
}

interface RunLike {
  id: string;
  supports(op: "cancel" | "stream" | "wait" | "conversation"): boolean;
  cancel(): Promise<void>;
  wait(): Promise<RunResult>;
}


function modelId(model: RunResult["model"]): string {
  if (!model) return "";
  if (typeof model === "string") return model;
  return model.id ?? "";
}

function emptyUsage(): TokenUsage {
  return {
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    cacheWriteTokens: 0,
    totalTokens: 0,
    reasoningTokens: 0,
  };
}

export class CursorClient {
  private readonly slots: Semaphore;

  constructor(
    private readonly apiKey: string,
    private readonly timeoutMs: number,
    concurrency: number,
    private readonly db: AppDb,
  ) {
    this.slots = new Semaphore(concurrency);
  }

  async complete(kind: string, prompt: string): Promise<Completion> {
    return this.withAgent(kind, async (agent) => this.sendAndWait(agent, kind, prompt));
  }

  async completeJson<T>(kind: string, prompt: string, schema: ZodType<T>, repair: string): Promise<{ value: T; completion: Completion }> {
    return this.withAgent(kind, async (agent) => {
      const first = await this.sendAndWait(agent, kind, prompt);
      try {
        return { value: schema.parse(extractJson(first.text)), completion: first };
      } catch (err) {
        const reason = err instanceof Error ? err.message : "invalid json";
        console.log(JSON.stringify({ event: "json_retry", kind, runId: first.runId, reason }));
        const second = await this.sendAndWait(
          agent,
          kind,
          `${repair}\n\nYour previous reply was rejected (${reason}). Reply again with JSON only.\n\nPrevious reply:\n${first.text.slice(0, 2000)}`,
        );
        try {
          return { value: schema.parse(extractJson(second.text)), completion: second };
        } catch (again) {
          const message = again instanceof Error ? again.message : "invalid json";
          throw new InvalidJsonError(message);
        }
      }
    });
  }

  async stream(kind: string, prompt: string, onDelta: (text: string) => void | Promise<void>): Promise<Completion> {
    return this.withAgent(kind, async (agent) => {
      let streamed = "";
      const run = await agent.send(prompt, {
        onDelta: ({ update }) => {
          if (update.type === "text-delta" && update.text) {
            streamed += update.text;
            return onDelta(update.text);
          }
          return undefined;
        },
      });
      console.log(JSON.stringify({ event: "run", kind, runId: run.id }));
      const result = await this.waitWithTimeout(run);
      this.record(kind, run.id, result);
      if (result.status === "error") {
        throw new RunFailedError(result.error?.message ?? "run failed", run.id);
      }
      if (result.status === "cancelled") {
        throw new TimeoutError("run cancelled");
      }
      const text = result.result?.trim() ? result.result : streamed;
      if (!streamed && text) await onDelta(text);
      return {
        text,
        runId: run.id,
        status: result.status,
        usage: result.usage,
        model: modelId(result.model),
      };
    });
  }

  private async sendAndWait(agent: AgentLike, kind: string, prompt: string): Promise<Completion> {
    const run = await agent.send(prompt);
    console.log(JSON.stringify({ event: "run", kind, runId: run.id }));
    const result = await this.waitWithTimeout(run);
    this.record(kind, run.id, result);
    if (result.status === "error") {
      throw new RunFailedError(result.error?.message ?? "run failed", run.id);
    }
    if (result.status === "cancelled") {
      throw new TimeoutError("run cancelled");
    }
    return {
      text: result.result ?? "",
      runId: run.id,
      status: result.status,
      usage: result.usage,
      model: modelId(result.model),
    };
  }

  private waitWithTimeout(run: RunLike): Promise<RunResult> {
    return withTimeout(run.wait(), this.timeoutMs, () => {
      if (run.supports("cancel")) {
        void run.cancel().catch((err: unknown) => {
          const message = err instanceof Error ? err.message : "cancel failed";
          console.log(JSON.stringify({ event: "cancel_failed", runId: run.id, message }));
        });
      }
    });
  }

  private record(kind: string, runId: string, result: RunResult): void {
    const usage = result.usage ?? emptyUsage();
    this.db.addUsage({
      kind,
      runId,
      status: result.status,
      model: modelId(result.model),
      inputTokens: usage.inputTokens,
      outputTokens: usage.outputTokens,
      cacheReadTokens: usage.cacheReadTokens,
      cacheWriteTokens: usage.cacheWriteTokens,
      totalTokens: usage.totalTokens,
      reasoningTokens: usage.reasoningTokens ?? 0,
    });
  }

  private async withAgent<T>(kind: string, fn: (agent: AgentLike) => Promise<T>): Promise<T> {
    const release = await this.slots.acquire();
    const dir = await mkdtemp(path.join(os.tmpdir(), "enjoy-relay-"));
    let agent: AgentLike | null = null;
    try {
      agent = (await Agent.create({
        apiKey: this.apiKey,
        model: { id: "auto" },
        local: { cwd: dir, settingSources: [] },
      })) as AgentLike;
      return await fn(agent);
    } catch (err) {
      if (err instanceof CursorAgentError) {
        console.log(
          JSON.stringify({
            event: "startup_failed",
            kind,
            message: err.message,
            retryable: err.isRetryable,
          }),
        );
      }
      throw err;
    } finally {
      if (agent) {
        await agent[Symbol.asyncDispose]().catch(() => undefined);
      }
      await rm(dir, { recursive: true, force: true });
      release();
    }
  }
}

export { CursorAgentError };
