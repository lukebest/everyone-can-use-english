import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";

export interface UsageInput {
  kind: string;
  runId: string;
  status: string;
  model: string;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  totalTokens: number;
  reasoningTokens: number;
}

export interface UsageTotals {
  requests: number;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  cacheWriteTokens: number;
  totalTokens: number;
  reasoningTokens: number;
}

export interface UsageByKind extends UsageTotals {
  kind: string;
}

export interface UsageRecent {
  createdAt: string;
  kind: string;
  runId: string;
  status: string;
  totalTokens: number;
  model: string;
}

export class AppDb {
  constructor(private readonly db: DatabaseSync) {}

  getCache(key: string): string | null {
    const row = this.db
      .prepare("SELECT value FROM cache WHERE key = ?")
      .get(key) as { value: string } | undefined;
    return row?.value ?? null;
  }

  setCache(key: string, kind: string, value: string): void {
    this.db
      .prepare(
        `INSERT INTO cache (key, kind, value, created_at)
         VALUES (?, ?, ?, ?)
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, created_at = excluded.created_at`,
      )
      .run(key, kind, value, new Date().toISOString());
  }

  addUsage(input: UsageInput): void {
    this.db
      .prepare(
        `INSERT INTO usage (
           created_at, kind, run_id, status, model,
           input_tokens, output_tokens, cache_read_tokens, cache_write_tokens,
           total_tokens, reasoning_tokens
         ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(
        new Date().toISOString(),
        input.kind,
        input.runId,
        input.status,
        input.model,
        input.inputTokens,
        input.outputTokens,
        input.cacheReadTokens,
        input.cacheWriteTokens,
        input.totalTokens,
        input.reasoningTokens,
      );
  }

  usageSummary(): { totals: UsageTotals; byKind: UsageByKind[]; recent: UsageRecent[] } {
    const totals = this.db
      .prepare(
        `SELECT
           COUNT(*) AS requests,
           COALESCE(SUM(input_tokens), 0) AS inputTokens,
           COALESCE(SUM(output_tokens), 0) AS outputTokens,
           COALESCE(SUM(cache_read_tokens), 0) AS cacheReadTokens,
           COALESCE(SUM(cache_write_tokens), 0) AS cacheWriteTokens,
           COALESCE(SUM(total_tokens), 0) AS totalTokens,
           COALESCE(SUM(reasoning_tokens), 0) AS reasoningTokens
         FROM usage`,
      )
      .get() as unknown as UsageTotals;
    const byKind = this.db
      .prepare(
        `SELECT
           kind,
           COUNT(*) AS requests,
           COALESCE(SUM(input_tokens), 0) AS inputTokens,
           COALESCE(SUM(output_tokens), 0) AS outputTokens,
           COALESCE(SUM(cache_read_tokens), 0) AS cacheReadTokens,
           COALESCE(SUM(cache_write_tokens), 0) AS cacheWriteTokens,
           COALESCE(SUM(total_tokens), 0) AS totalTokens,
           COALESCE(SUM(reasoning_tokens), 0) AS reasoningTokens
         FROM usage
         GROUP BY kind
         ORDER BY requests DESC`,
      )
      .all() as unknown as UsageByKind[];
    const recent = this.db
      .prepare(
        `SELECT created_at AS createdAt, kind, run_id AS runId, status,
                total_tokens AS totalTokens, model
         FROM usage
         ORDER BY id DESC
         LIMIT 20`,
      )
      .all() as unknown as UsageRecent[];
    return { totals, byKind, recent };
  }
}

export function openDatabase(dataDir: string): AppDb {
  fs.mkdirSync(dataDir, { recursive: true });
  const db = new DatabaseSync(path.join(dataDir, "relay.sqlite"));
  db.exec("PRAGMA journal_mode = WAL");
  db.exec(`
    CREATE TABLE IF NOT EXISTS cache (
      key TEXT PRIMARY KEY,
      kind TEXT NOT NULL,
      value TEXT NOT NULL,
      created_at TEXT NOT NULL
    );
    CREATE TABLE IF NOT EXISTS usage (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      created_at TEXT NOT NULL,
      kind TEXT NOT NULL,
      run_id TEXT NOT NULL,
      status TEXT NOT NULL,
      model TEXT NOT NULL DEFAULT '',
      input_tokens INTEGER NOT NULL DEFAULT 0,
      output_tokens INTEGER NOT NULL DEFAULT 0,
      cache_read_tokens INTEGER NOT NULL DEFAULT 0,
      cache_write_tokens INTEGER NOT NULL DEFAULT 0,
      total_tokens INTEGER NOT NULL DEFAULT 0,
      reasoning_tokens INTEGER NOT NULL DEFAULT 0
    );
  `);
  return new AppDb(db);
}
