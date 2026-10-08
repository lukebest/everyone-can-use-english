import assert from "node:assert/strict";
import test from "node:test";
import { scoreSpeech, tokenize } from "./score.js";

test("tokenize drops punctuation and keeps apostrophes inside words", () => {
  assert.deepEqual(tokenize("Hello, don't stop!"), ["hello", "don't", "stop"]);
});

test("score is 100 when the words match", () => {
  const result = scoreSpeech("She has a plan.", "she has a plan");
  assert.equal(result.score, 100);
  assert.equal(result.words.every((word) => word.status === "match"), true);
});

test("score penalizes substitutions, missing words, and extras", () => {
  const result = scoreSpeech("I like green tea", "I love tea now");
  const matches = result.words.filter((word) => word.status === "match");
  assert.deepEqual(
    matches.map((word) => word.expected),
    ["i", "tea"],
  );
  assert.equal(result.words.some((word) => word.status === "extra" && word.actual === "now"), true);
  assert.equal(result.score, 50);
});
