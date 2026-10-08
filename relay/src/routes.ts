import { Hono } from "hono";
import { sendError } from "./http.js";
import { scoreSpeech } from "./score.js";
import { ServiceError, transcribeFile } from "./whisper.js";

function readField(value: unknown, name: string, max: number): string {
  if (typeof value !== "string") {
    throw new ServiceError(400, "bad_request", `${name} is required`);
  }
  const text = value.trim();
  if (!text) {
    throw new ServiceError(400, "bad_request", `${name} is required`);
  }
  if (text.length > max) {
    throw new ServiceError(400, "bad_request", `${name} is too long`);
  }
  return text;
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

export function mountRoutes(app: Hono, whisperBin: string, whisperModel: string): void {
  app.post("/v1/score", async (c) => {
    try {
      const body = (await c.req.json()) as Record<string, unknown>;
      const reference = readField(body["reference"], "reference", 8000);
      const hypothesis = typeof body["hypothesis"] === "string" ? body["hypothesis"] : "";
      if (hypothesis.length > 8000) {
        throw new ServiceError(400, "bad_request", "hypothesis is too long");
      }
      return c.json(scoreSpeech(reference, hypothesis));
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
