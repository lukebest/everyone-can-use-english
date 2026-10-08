import { spawn } from "node:child_process";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { Semaphore } from "./limit.js";

export interface TranscriptSegment {
  startMs: number;
  endMs: number;
  text: string;
}

export class ServiceError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
  ) {
    super(message);
    this.name = "ServiceError";
  }
}

const slots = new Semaphore(1);

function run(cmd: string, args: string[]): Promise<void> {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { stdio: ["ignore", "pipe", "pipe"] });
    let err = "";
    child.stderr.on("data", (chunk: Buffer) => {
      err += chunk.toString();
    });
    child.on("error", (error) => {
      reject(error);
    });
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`${cmd} exited ${code}: ${err.slice(-800)}`));
    });
  });
}

function timestampToMs(value: string): number {
  const match = value.trim().match(/(\d+):(\d+):(\d+)[,.](\d+)/);
  if (!match) return 0;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  const seconds = Number(match[3]);
  const fraction = (match[4] ?? "0").padEnd(3, "0").slice(0, 3);
  return ((hours * 60 + minutes) * 60 + seconds) * 1000 + Number(fraction);
}

interface OffsetPair {
  from?: number;
  to?: number;
}

interface TimestampPair {
  from?: string;
  to?: string;
}

interface WhisperItem {
  text?: string;
  offsets?: OffsetPair;
  timestamps?: TimestampPair;
  start?: number;
  end?: number;
}

function itemToSegment(item: WhisperItem): TranscriptSegment | null {
  const text = (item.text ?? "").trim();
  if (!text) return null;
  if (item.timestamps?.from && item.timestamps.to) {
    return {
      startMs: timestampToMs(item.timestamps.from),
      endMs: timestampToMs(item.timestamps.to),
      text,
    };
  }
  if (typeof item.start === "number" && typeof item.end === "number") {
    return {
      startMs: Math.round(item.start * 1000),
      endMs: Math.round(item.end * 1000),
      text,
    };
  }
  if (item.offsets && typeof item.offsets.from === "number" && typeof item.offsets.to === "number") {
    return { startMs: item.offsets.from, endMs: item.offsets.to, text };
  }
  return { startMs: 0, endMs: 0, text };
}

export function parseWhisperJson(raw: string): TranscriptSegment[] {
  const parsed = JSON.parse(raw) as {
    transcription?: WhisperItem[];
    segments?: WhisperItem[];
  };
  const items = parsed.transcription ?? parsed.segments ?? [];
  const segments: TranscriptSegment[] = [];
  for (const item of items) {
    const segment = itemToSegment(item);
    if (segment) segments.push(segment);
  }
  return segments;
}

export function resolveWhisper(bin: string, model: string): { bin: string; model: string } {
  if (!bin || !model) {
    throw new ServiceError(
      503,
      "whisper_not_configured",
      "Set WHISPER_BIN and WHISPER_MODEL, or run scripts/install-whisper.sh",
    );
  }
  return { bin, model };
}

export async function transcribeFile(input: {
  bin: string;
  model: string;
  audio: Buffer;
  filename: string;
}): Promise<TranscriptSegment[]> {
  const resolved = resolveWhisper(input.bin, input.model);
  const release = await slots.acquire();
  const dir = await mkdtemp(path.join(os.tmpdir(), "enjoy-whisper-"));
  try {
    const source = path.join(dir, path.basename(input.filename || "audio.bin"));
    const wav = path.join(dir, "audio.wav");
    const outPrefix = path.join(dir, "out");
    await writeFile(source, input.audio);
    try {
      await run("ffmpeg", ["-y", "-i", source, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wav]);
    } catch (err) {
      const missing = err instanceof Error && "code" in err && err.code === "ENOENT";
      if (missing) {
        throw new ServiceError(503, "ffmpeg_missing", "ffmpeg is required for transcription");
      }
      throw err;
    }
    const args = ["-m", resolved.model, "-f", wav, "-l", "en", "-oj", "-of", outPrefix];
    try {
      await run(resolved.bin, [...args, "--no-prints"]);
    } catch (err) {
      try {
        await run(resolved.bin, args);
      } catch {
        throw err;
      }
    }
    const json = await readFile(`${outPrefix}.json`, "utf8");
    return parseWhisperJson(json);
  } finally {
    await rm(dir, { recursive: true, force: true });
    release();
  }
}
