import { ChatTurn, turn } from './Types';

export class PromptPair {
  system: string = '';
  user: string = '';
}

class LookupHuman {
  word: string = '';
  context: string = '';
  definitions: string[] = [];
}

function pair(system: string, user: string): PromptPair {
  const item = new PromptPair();
  item.system = system;
  item.user = user;
  return item;
}

function languageName(code: string, fallback: string): string {
  if (code.length === 0) {
    return fallback;
  }
  if (code === 'en-US' || code === 'en') {
    return 'English';
  }
  if (code === 'zh-CN' || code === 'zh') {
    return 'Chinese';
  }
  if (code === 'es') {
    return 'Spanish';
  }
  return code;
}

export function lookupPrompt(word: string, context: string, learningLanguage: string, nativeLanguage: string): PromptPair {
  const learning = languageName(learningLanguage, 'English');
  const native = languageName(nativeLanguage, 'Chinese');
  const system = 'You are an ' + learning + '-' + native + ' dictionary.\n' +
    'I will provide "word(it also maybe a phrase)" and "context" as input, you should return the "word", "lemma", "pronunciation", "pos", "definition", "translation" and "context_translation" as output.\n' +
    'If no context is provided, return the most common definition.\n' +
    'If you do not know the appropriate definition, return an empty string for "definition" and "translation".\n' +
    'Always return the output in JSON format as following:\n\n' +
    '{\n' +
    '  "word": "the original word or phrase",\n' +
    '  "lemma": "lemma",\n' +
    '  "pronunciation": "IPA pronunciation",\n' +
    '  "pos": "the part of speech",\n' +
    '  "definition": "the definition in ' + learning + '",\n' +
    '  "translation": "translation in ' + native + '",\n' +
    '  "context_translation": "translation of the context in ' + native + '"\n' +
    '}';
  const human = new LookupHuman();
  human.word = word;
  human.context = context;
  return pair(system, JSON.stringify(human));
}

export const LOOKUP_REPAIR: string = 'Return ONLY a JSON object with keys word, lemma, pronunciation, pos, definition, translation, context_translation. No markdown.';

export function translatePrompt(text: string, nativeLanguage: string): PromptPair {
  const native = languageName(nativeLanguage, 'Chinese');
  const system = 'You are a professional, authentic translation engine, only returns translations.';
  const human = 'Translate the text to ' + native + ' Language, please do not explain my original text.:\n\n' + text + '\n';
  return pair(system, human);
}

export function analyzePrompt(text: string, learningLanguage: string, nativeLanguage: string): PromptPair {
  const learning = languageName(learningLanguage, 'English');
  const native = languageName(nativeLanguage, 'Chinese');
  const system = 'I speak ' + native + '. You\'re my ' + learning + ' coach, I\'ll provide ' + learning +
    ' text, you\'ll help me analyze the sentence structure, grammar, and vocabulary/phrases, and provide a detailed explanation of the text. Please return the results in the following format(but in ' +
    native + '):\n\n' +
    '### Sentence Structure\n' +
    '(Explain each element of the sentence)\n\n' +
    '### Grammar\n' +
    '(Explain the grammar of the sentence)\n\n' +
    '### Vocabulary/Phrases\n' +
    '(Explain the key vocabulary and phrases used)';
  return pair(system, text);
}

export function refinePrompt(text: string, context: string, learningLanguage: string, nativeLanguage: string): PromptPair {
  const learning = languageName(learningLanguage, 'English');
  const native = languageName(nativeLanguage, 'Chinese');
  const shown = context.trim().length > 0 ? context : 'None';
  const system = 'I speak ' + native + '. You\'re my ' + learning + ' coach. I\'ll give you my expression in ' + learning +
    '. And I may also provide some context about my expression.\n\n' +
    'Please try to understand my true meaning and provide several refined expressions in the native way. And explain them in ' + native + '.\n\n' +
    '[Context]\n' + shown;
  return pair(system, text);
}

export function suggestPrompt(context: string, learningLanguage: string, nativeLanguage: string): PromptPair {
  const learning = languageName(learningLanguage, 'English');
  const native = languageName(nativeLanguage, 'Chinese');
  const system = 'I speak ' + native + '. You\'re my ' + learning + ' coach. I\'am chatting with foreign friends.\n' +
    'I\'ll provide you with the context of the chat. Please provide me with at least 5 suggestions for what counld I say in ' + learning +
    ' and explain them in ' + native + '.\n\n' +
    'Reply in JSON format only. The output should be structured like this:\n' +
    '{\n' +
    '  "suggestions": [\n' +
    '    {\n' +
    '      "text": "suggestion in ' + learning + '",\n' +
    '      "explaination": "explaination"\n' +
    '    }\n' +
    '  ]\n' +
    '}';
  return pair(system, context);
}

export const SUGGEST_REPAIR: string = 'Return ONLY a JSON object {"suggestions":[{"text":"...","explaination":"..."}]} with at least 5 items. No markdown.';

export function chatMessages(role: string, history: ChatTurn[], message: string): ChatTurn[] {
  const out: ChatTurn[] = [];
  out.push(turn('system', role + '\n\nStay in character. Reply to the latest user message only.'));
  const start = history.length > 12 ? history.length - 12 : 0;
  for (let i = start; i < history.length; i++) {
    const roleName = history[i].role === 'assistant' ? 'assistant' : 'user';
    out.push(turn(roleName, history[i].content));
  }
  out.push(turn('user', message));
  return out;
}

export function messagesOf(prompt: PromptPair): ChatTurn[] {
  const out: ChatTurn[] = [];
  out.push(turn('system', prompt.system));
  out.push(turn('user', prompt.user));
  return out;
}
