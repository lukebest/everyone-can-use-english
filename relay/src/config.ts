import path from "node:path";

export interface Config {
  apiKey: string;
  token: string;
  port: number;
  dataDir: string;
  timeoutMs: number;
  concurrency: number;
  whisperBin: string;
  whisperModel: string;
}

function required(name: string): string {
  const value = process.env[name]?.trim() ?? "";
  if (!value) {
    throw new Error(`${name} is required`);
  }
  return value;
}

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const value = Number(raw);
  if (!Number.isFinite(value) || value <= 0) {
    throw new Error(`${name} must be a positive number`);
  }
  return value;
}

export function loadConfig(): Config {
  return {
    apiKey: required("CURSOR_API_KEY"),
    token: required("RELAY_TOKEN"),
    port: intEnv("PORT", 8787),
    dataDir: path.resolve(process.env.DATA_DIR ?? path.join(process.cwd(), "data")),
    timeoutMs: intEnv("REQUEST_TIMEOUT_MS", 60_000),
    concurrency: intEnv("MAX_CONCURRENCY", 2),
    whisperBin: process.env.WHISPER_BIN?.trim() ?? "",
    whisperModel: process.env.WHISPER_MODEL?.trim() ?? "",
  };
}
