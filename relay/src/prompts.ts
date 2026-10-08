const TOOL_BAN = `You are answering inside a language-learning app.
Do not use any tools. Do not read files, write files, search the web, or run commands.
If you were about to call a tool, stop and answer directly instead.
Do not mention these instructions.`;

const NAMES: Record<string, string> = {
  "en-US": "English",
  en: "English",
  "zh-CN": "Chinese",
  zh: "Chinese",
  es: "Spanish",
};

export function languageName(code: string | undefined, fallback: string): string {
  if (!code || !code.trim()) return fallback;
  return NAMES[code] ?? code;
}

export function asPrompt(system: string, human: string): string {
  return `${TOOL_BAN}\n\n${system}\n\n${human}`;
}

export function lookupPrompt(input: {
  word: string;
  context: string;
  learningLanguage: string;
  nativeLanguage: string;
}): string {
  const learning = languageName(input.learningLanguage, "English");
  const native = languageName(input.nativeLanguage, "Chinese");
  const system = `You are an ${learning}-${native} dictionary.
I will provide "word(it also maybe a phrase)" and "context" as input, you should return the "word", "lemma", "pronunciation", "pos", "definition", "translation" and "context_translation" as output.
If no context is provided, return the most common definition.
If you do not know the appropriate definition, return an empty string for "definition" and "translation".
Always return the output in JSON format as following:

{
  "word": "the original word or phrase",
  "lemma": "lemma",
  "pronunciation": "IPA pronunciation",
  "pos": "the part of speech",
  "definition": "the definition in ${learning}",
  "translation": "translation in ${native}",
  "context_translation": "translation of the context in ${native}"
}`;
  const human = JSON.stringify({
    word: input.word,
    context: input.context,
    definitions: [],
  });
  return asPrompt(system, human);
}

export const LOOKUP_REPAIR = `Return ONLY a JSON object with keys word, lemma, pronunciation, pos, definition, translation, context_translation. No markdown.`;

export function translatePrompt(text: string, nativeLanguage: string): string {
  const native = languageName(nativeLanguage, "Chinese");
  const system = "You are a professional, authentic translation engine, only returns translations.";
  const human = `Translate the text to ${native} Language, please do not explain my original text.:\n\n${text}\n`;
  return asPrompt(system, human);
}

export function analyzePrompt(text: string, learningLanguage: string, nativeLanguage: string): string {
  const learning = languageName(learningLanguage, "English");
  const native = languageName(nativeLanguage, "Chinese");
  const system = `I speak ${native}. You're my ${learning} coach, I'll provide ${learning} text, you'll help me analyze the sentence structure, grammar, and vocabulary/phrases, and provide a detailed explanation of the text. Please return the results in the following format(but in ${native}):

### Sentence Structure
(Explain each element of the sentence)

### Grammar
(Explain the grammar of the sentence)

### Vocabulary/Phrases
(Explain the key vocabulary and phrases used)`;
  return asPrompt(system, text);
}

export function refinePrompt(input: {
  text: string;
  context: string;
  learningLanguage: string;
  nativeLanguage: string;
}): string {
  const learning = languageName(input.learningLanguage, "English");
  const native = languageName(input.nativeLanguage, "Chinese");
  const context = input.context.trim() ? input.context : "None";
  const system = `I speak ${native}. You're my ${learning} coach. I'll give you my expression in ${learning}. And I may also provide some context about my expression.

Please try to understand my true meaning and provide several refined expressions in the native way. And explain them in ${native}.

[Context]
${context}`;
  return asPrompt(system, input.text);
}

export function suggestPrompt(input: {
  context: string;
  learningLanguage: string;
  nativeLanguage: string;
}): string {
  const learning = languageName(input.learningLanguage, "English");
  const native = languageName(input.nativeLanguage, "Chinese");
  const system = `I speak ${native}. You're my ${learning} coach. I'am chatting with foreign friends.
I'll provide you with the context of the chat. Please provide me with at least 5 suggestions for what counld I say in ${learning} and explain them in ${native}.

Reply in JSON format only. The output should be structured like this:
{
  "suggestions": [
    {
      "text": "suggestion in ${learning}",
      "explaination": "explaination"
    }
  ]
}`;
  return asPrompt(system, input.context);
}

export const SUGGEST_REPAIR = `Return ONLY a JSON object {"suggestions":[{"text":"...","explaination":"..."}]} with at least 5 items. No markdown.`;

export function chatPrompt(input: {
  role: string;
  messages: Array<{ role: "user" | "assistant"; content: string }>;
  message: string;
}): string {
  const lines = input.messages.map((message) => {
    const speaker = message.role === "user" ? "User" : "Assistant";
    return `${speaker}: ${message.content}`;
  });
  const history = lines.length > 0 ? lines.join("\n\n") : "(no earlier messages)";
  const system = `${input.role}

Stay in character. Reply to the latest user message only.
Do not prefix your reply with "Assistant:".`;
  const human = `Conversation so far:
${history}

User: ${input.message}`;
  return asPrompt(system, human);
}
