import assert from "node:assert/strict";
import test from "node:test";
import { extractJson } from "./json.js";

test("extracts a fenced JSON object", () => {
  const value = extractJson('Sure\n```json\n{"word":"plan"}\n```');
  assert.deepEqual(value, { word: "plan" });
});

test("extracts the object when the model adds a preface", () => {
  const value = extractJson('Here you go: {"translation":"计划"} thanks');
  assert.deepEqual(value, { translation: "计划" });
});
