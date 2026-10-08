export interface AlignedWord {
  expected: string;
  actual: string;
  status: "match" | "substitute" | "missing" | "extra";
}

export interface ScoreResult {
  score: number;
  words: AlignedWord[];
}

const PUNCTUATION = /[.,!?;:"“”‘’()[\]{}，。！？；：、…]/g;

export function tokenize(text: string): string[] {
  return text
    .toLowerCase()
    .replace(PUNCTUATION, " ")
    .split(/\s+/)
    .map((word) => word.replace(/^'+|'+$/g, ""))
    .filter((word) => word.length > 0);
}

type Step = "match" | "substitute" | "missing" | "extra" | "start";

interface Cell {
  dist: number;
  matches: number;
  from: Step;
}

function prefer(current: Cell | null, dist: number, matches: number, from: Step): Cell {
  if (!current || dist < current.dist || (dist === current.dist && matches > current.matches)) {
    return { dist, matches, from };
  }
  return current;
}

export function alignWords(reference: string[], hypothesis: string[]): AlignedWord[] {
  const n = reference.length;
  const m = hypothesis.length;
  const dp: Cell[][] = [];
  for (let i = 0; i <= n; i += 1) {
    const row: Cell[] = [];
    for (let j = 0; j <= m; j += 1) row.push({ dist: 0, matches: 0, from: "start" });
    dp.push(row);
  }
  for (let i = 1; i <= n; i += 1) dp[i]![0] = { dist: i, matches: 0, from: "missing" };
  for (let j = 1; j <= m; j += 1) dp[0]![j] = { dist: j, matches: 0, from: "extra" };

  for (let i = 1; i <= n; i += 1) {
    for (let j = 1; j <= m; j += 1) {
      const diag = dp[i - 1]![j - 1]!;
      const same = reference[i - 1] === hypothesis[j - 1];
      let best: Cell | null = null;
      if (same) best = prefer(best, diag.dist, diag.matches + 1, "match");
      else best = prefer(best, diag.dist + 1, diag.matches, "substitute");
      const up = dp[i - 1]![j]!;
      const left = dp[i]![j - 1]!;
      best = prefer(best, up.dist + 1, up.matches, "missing");
      best = prefer(best, left.dist + 1, left.matches, "extra");
      dp[i]![j] = best!;
    }
  }

  const words: AlignedWord[] = [];
  let i = n;
  let j = m;
  while (i > 0 || j > 0) {
    const step = dp[i]![j]!.from;
    if (step === "match" || step === "substitute") {
      words.push({
        expected: reference[i - 1]!,
        actual: hypothesis[j - 1]!,
        status: step,
      });
      i -= 1;
      j -= 1;
    } else if (step === "missing") {
      words.push({ expected: reference[i - 1]!, actual: "", status: "missing" });
      i -= 1;
    } else {
      words.push({ expected: "", actual: hypothesis[j - 1] ?? "", status: "extra" });
      j -= 1;
    }
  }
  words.reverse();
  return words;
}

export function scoreSpeech(referenceText: string, hypothesisText: string): ScoreResult {
  const reference = tokenize(referenceText);
  const hypothesis = tokenize(hypothesisText);
  const words = alignWords(reference, hypothesis);
  if (reference.length === 0 && hypothesis.length === 0) {
    return { score: 100, words };
  }
  const matches = words.filter((word) => word.status === "match").length;
  const denom = Math.max(reference.length, hypothesis.length, 1);
  return { score: Math.round((matches / denom) * 100), words };
}
