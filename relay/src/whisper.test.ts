import assert from "node:assert/strict";
import test from "node:test";
import { parseWhisperJson } from "./whisper.js";

test("parses whisper.cpp transcription timestamps", () => {
  const segments = parseWhisperJson(
    JSON.stringify({
      transcription: [
        {
          timestamps: { from: "00:00:00,000", to: "00:00:01,840" },
          offsets: { from: 0, to: 1840 },
          text: " Hello there.",
        },
      ],
    }),
  );
  assert.deepEqual(segments, [{ startMs: 0, endMs: 1840, text: "Hello there." }]);
});

test("parses second-based segments", () => {
  const segments = parseWhisperJson(
    JSON.stringify({
      segments: [{ start: 1.5, end: 2.25, text: "tea" }],
    }),
  );
  assert.deepEqual(segments, [{ startMs: 1500, endMs: 2250, text: "tea" }]);
});
