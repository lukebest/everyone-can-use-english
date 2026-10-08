import { timingSafeEqual } from "node:crypto";
import type { Context, MiddlewareHandler } from "hono";
import { TimeoutError } from "./limit.js";
import { ServiceError } from "./whisper.js";

export function bearerAuth(token: string): MiddlewareHandler {
  const expected = Buffer.from(token);
  return async (c, next) => {
    const header = c.req.header("authorization") ?? "";
    const match = /^Bearer\s+(\S+)\s*$/i.exec(header);
    const presented = Buffer.from(match?.[1] ?? "");
    const ok = presented.length === expected.length && timingSafeEqual(presented, expected);
    if (!ok) {
      return c.json({ error: "unauthorized" }, 401);
    }
    await next();
  };
}

export function httpError(err: unknown): { status: 400 | 500 | 503 | 504; body: Record<string, unknown> } {
  if (err instanceof ServiceError) {
    const status = err.status === 400 || err.status === 503 ? err.status : 500;
    return { status, body: { error: err.code, message: err.message } };
  }
  if (err instanceof TimeoutError) {
    return { status: 504, body: { error: "timeout", message: err.message } };
  }
  const message = err instanceof Error ? err.message : "internal error";
  return { status: 500, body: { error: "internal", message } };
}

export function sendError(c: Context, err: unknown) {
  const mapped = httpError(err);
  console.log(JSON.stringify({ event: "request_error", ...mapped.body }));
  return c.json(mapped.body, mapped.status);
}
