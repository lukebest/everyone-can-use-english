import { Hono } from "hono";
import { streamSSE } from "hono/streaming";
import { z } from "zod";
import type { AppDb } from "./db.js";
import { CursorClient } from "./cursor.js";
import { cacheKey, httpError, sendError } from "./http.js";
import {
  LOOKUP_REPAIR,
  SUGGEST_REPAIR,
  analyzePrompt,
  chatPrompt,
  lookupPrompt,
  refinePrompt,
  suggestPrompt,
  translatePrompt,
} from "./prompts.js";
import { scoreSpeech } from "./score.js";
import { ServiceError, transcribeFile } from "./whisper.js";

const languages = {
  learningLanguage: z.string().optional(),
  nativeLanguage: z.string().optional(),
};

const lookupSchema = z.object({
  word: z.string().trim().min(1).max(200),
  context: z.string().max(4000).optional().default(""),
  ...languages,
});

const lookupResultSchema = z.object({
  word: z.string().optional().default(""),
  lemma: z.string().optional().default(""),
  pronunciation: z.string().optional().default(""),
  pos: z.string().optional().default(""),
  definition: z.string().optional().default(""),
  translation: z.string().optional().default(""),
  context_translation: z.string().optional().default(""),
});

const textSchema = z.object({
  text: z.string().trim().min(1).max(8000),
  context: z.string().max(4000).optional().default(""),
  ...languages,
});

const suggestSchema = z.object({
  context: z.string().trim().min(1).max(8000),
  ...languages,
});

const suggestResultSchema = z.object({
  suggestions: z
    .array(z.object({ text: z.string(), explaination: z.string() }))
    .optional(),
  words: z
    .array(z.object({ content: z.string(), explaination: z.string() }))
    .optional(),
});

const chatSchema = z.object({
  role: z.string().trim().min(1).max(8000),
  message: z.string().trim().min(1).max(8000),
  messages: z
    .array(
      z.object({
        role: z.enum(["user", "assistant"]),
        content: z.string().max(8000),
      }),
    )
    .max(12)
    .optional()
    .default([]),
});

const scoreSchema = z.object({
  reference: z.string().trim().min(1).max(8000),
  hypothesis: z.string().max(8000),
});

function learningOf(input: { learningLanguage?: string }): string {
  return input.learningLanguage ?? "en-US";
}

function nativeOf(input: { nativeLanguage?: string }): string {
  return input.nativeLanguage ?? "zh-CN";
}

function normalizeSuggestions(raw: z.infer<typeof suggestResultSchema>): Array<{ text: string; explanation: string }> {
  const fromSuggestions = raw.suggestions ?? [];
  if (fromSuggestions.length > 0) {
    return fromSuggestions.map((item) => ({ text: item.text, explanation: item.explaination }));
  }
  return (raw.words ?? []).map((item) => ({ text: item.content, explanation: item.explaination }));
}

async function readUpload(c: { req: { parseBody: () => Promise<Record<string, unknown>> } }): Promise<{
  audio: Buffer;
  filename: string;
  reference: string;
}> {
  const body = await c.req.parseBody();
  const audio = body["audio"];
  if (!(audio instanceof File)) {
    throw new ServiceError(400, "bad_request", "audio file is required");
  }
  if (audio.size > 80 * 1024 * 1024) {
    throw new ServiceError(400, "bad_request", "audio file must be 80MB or smaller");
  }
  const reference = typeof body["reference"] === "string" ? body["reference"] : "";
  return {
    audio: Buffer.from(await audio.arrayBuffer()),
    filename: audio.name || "audio.bin",
    reference,
  };
}

export function mountRoutes(app: Hono, client: CursorClient, db: AppDb, whisperBin: string, whisperModel: string): void {
  app.post("/v1/lookup", async (c) => {
    try {
      const input = lookupSchema.parse(await c.req.json());
      const key = cacheKey("lookup", {
        word: input.word,
        context: input.context,
        learningLanguage: learningOf(input),
        nativeLanguage: nativeOf(input),
      });
      const cached = db.getCache(key);
      if (cached) return c.json({ ...JSON.parse(cached), cached: true });
      const prompt = lookupPrompt({
        word: input.word,
        context: input.context,
        learningLanguage: learningOf(input),
        nativeLanguage: nativeOf(input),
      });
      const { value, completion } = await client.completeJson("lookup", prompt, lookupResultSchema, LOOKUP_REPAIR);
      db.setCache(key, "lookup", JSON.stringify(value));
      return c.json({ ...value, cached: false, runId: completion.runId });
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/translate", async (c) => {
    try {
      const input = textSchema.parse(await c.req.json());
      const key = cacheKey("translate", { text: input.text, nativeLanguage: nativeOf(input) });
      const cached = db.getCache(key);
      if (cached) return c.json({ text: cached, cached: true });
      const completion = await client.complete("translate", translatePrompt(input.text, nativeOf(input)));
      const text = completion.text.trim();
      db.setCache(key, "translate", text);
      return c.json({ text, cached: false, runId: completion.runId });
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/analyze", async (c) => {
    try {
      const input = textSchema.parse(await c.req.json());
      const completion = await client.complete(
        "analyze",
        analyzePrompt(input.text, learningOf(input), nativeOf(input)),
      );
      return c.json({ text: completion.text.trim(), runId: completion.runId });
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/refine", async (c) => {
    try {
      const input = textSchema.parse(await c.req.json());
      const completion = await client.complete(
        "refine",
        refinePrompt({
          text: input.text,
          context: input.context,
          learningLanguage: learningOf(input),
          nativeLanguage: nativeOf(input),
        }),
      );
      return c.json({ text: completion.text.trim(), runId: completion.runId });
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/suggest", async (c) => {
    try {
      const input = suggestSchema.parse(await c.req.json());
      const prompt = suggestPrompt({
        context: input.context,
        learningLanguage: learningOf(input),
        nativeLanguage: nativeOf(input),
      });
      const { value, completion } = await client.completeJson("suggest", prompt, suggestResultSchema, SUGGEST_REPAIR);
      return c.json({ suggestions: normalizeSuggestions(value), runId: completion.runId });
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/chat", async (c) => {
    let input: z.infer<typeof chatSchema>;
    try {
      input = chatSchema.parse(await c.req.json());
    } catch (err) {
      return sendError(c, err);
    }
    const prompt = chatPrompt(input);
    return streamSSE(c, async (stream) => {
      try {
        const completion = await client.stream("chat", prompt, async (text) => {
          await stream.writeSSE({ event: "delta", data: JSON.stringify({ text }) });
        });
        await stream.writeSSE({
          event: "done",
          data: JSON.stringify({
            runId: completion.runId,
            usage: completion.usage ?? null,
          }),
        });
      } catch (err) {
        const mapped = httpError(err);
        console.log(JSON.stringify({ event: "request_error", ...mapped.body }));
        await stream.writeSSE({
          event: "error",
          data: JSON.stringify({
            message: typeof mapped.body.message === "string" ? mapped.body.message : "chat failed",
            error: mapped.body.error ?? "error",
          }),
        });
      }
    });
  });

  app.get("/v1/usage", (c) => c.json(db.usageSummary()));

  app.post("/v1/score", async (c) => {
    try {
      const input = scoreSchema.parse(await c.req.json());
      return c.json(scoreSpeech(input.reference, input.hypothesis));
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/transcribe", async (c) => {
    try {
      const upload = await readUpload(c);
      const segments = await transcribeFile({
        bin: whisperBin,
        model: whisperModel,
        audio: upload.audio,
        filename: upload.filename,
      });
      return c.json({ segments });
    } catch (err) {
      return sendError(c, err);
    }
  });

  app.post("/v1/assess", async (c) => {
    try {
      const upload = await readUpload(c);
      if (!upload.reference.trim()) {
        throw new ServiceError(400, "bad_request", "reference text is required");
      }
      const segments = await transcribeFile({
        bin: whisperBin,
        model: whisperModel,
        audio: upload.audio,
        filename: upload.filename,
      });
      const hypothesis = segments.map((segment) => segment.text).join(" ");
      const scored = scoreSpeech(upload.reference, hypothesis);
      return c.json({ ...scored, hypothesis, segments });
    } catch (err) {
      return sendError(c, err);
    }
  });
}
