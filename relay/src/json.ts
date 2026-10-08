export class InvalidJsonError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidJsonError";
  }
}

export function extractJson(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const body = (fenced?.[1] ?? trimmed).trim();
  const start = body.indexOf("{");
  const end = body.lastIndexOf("}");
  if (start < 0 || end <= start) {
    throw new InvalidJsonError("model did not return a JSON object");
  }
  try {
    return JSON.parse(body.slice(start, end + 1)) as unknown;
  } catch (err) {
    const message = err instanceof Error ? err.message : "parse failed";
    throw new InvalidJsonError(message);
  }
}
