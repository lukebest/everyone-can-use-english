import { Hono } from "hono";
import { cors } from "hono/cors";
import type { Config } from "./config.js";
import { bearerAuth } from "./http.js";
import { mountRoutes } from "./routes.js";

export interface AppDeps {
  config: Config;
}

export function createApp(deps: AppDeps): Hono {
  const app = new Hono();
  app.use("*", cors());
  app.get("/health", (c) => c.json({ ok: true }));
  app.use("/v1/*", bearerAuth(deps.config.token));
  mountRoutes(app, deps.config.whisperBin, deps.config.whisperModel);
  return app;
}
