import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Config } from "./config.js";
import { CursorClient } from "./cursor.js";
import type { AppDb } from "./db.js";
import { bearerAuth } from "./http.js";
import { mountRoutes } from "./routes.js";

export interface AppDeps {
  config: Config;
  db: AppDb;
}

export function createApp(deps: AppDeps): Hono {
  const app = new Hono();
  app.use("*", cors());
  app.get("/health", (c) => c.json({ ok: true }));
  app.use("/v1/*", bearerAuth(deps.config.token));
  const client = new CursorClient(
    deps.config.apiKey,
    deps.config.timeoutMs,
    deps.config.concurrency,
    deps.db,
  );
  mountRoutes(app, client, deps.db, deps.config.whisperBin, deps.config.whisperModel);
  return app;
}
