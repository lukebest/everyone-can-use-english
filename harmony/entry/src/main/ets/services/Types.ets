export class LookupResult {
  word: string = '';
  lemma: string = '';
  pronunciation: string = '';
  pos: string = '';
  definition: string = '';
  translation: string = '';
  contextTranslation: string = '';
}

export class Suggestion {
  text: string = '';
  explanation: string = '';
}

export class UsageInfo {
  requests: number = 0;
  totalTokens: number = 0;
  inputTokens: number = 0;
  outputTokens: number = 0;
}

export class WordMark {
  expected: string = '';
  actual: string = '';
  status: string = '';
}

export class AssessResult {
  score: number = 0;
  hypothesis: string = '';
  words: WordMark[] = [];
}

export class ChatTurn {
  role: string = '';
  content: string = '';
}

export function turn(role: string, content: string): ChatTurn {
  const item = new ChatTurn();
  item.role = role;
  item.content = content;
  return item;
}

export class ChatHandlers {
  onDelta: (text: string) => void = (text: string): void => {
    if (text.length < 0) {
      return;
    }
  };
  onDone: () => void = (): void => {
  };
  onError: (message: string) => void = (message: string): void => {
    if (message.length < 0) {
      return;
    }
  };
}

export class LlmError extends Error {
  code: string = '';

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}
