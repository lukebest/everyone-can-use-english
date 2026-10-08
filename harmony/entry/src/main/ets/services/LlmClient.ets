import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { LlmCacheDao, LlmUsageDao } from '../data/Db';
import {
  LOOKUP_REPAIR,
  SUGGEST_REPAIR,
  analyzePrompt,
  chatMessages,
  lookupPrompt,
  messagesOf,
  refinePrompt,
  suggestPrompt,
  translatePrompt
} from './Prompts';
import {
  ChatHandlers,
  ChatTurn,
  LlmError,
  LookupResult,
  Suggestion,
  UsageInfo,
  turn
} from './Types';

const GLM_BASE: string = 'https://open.bigmodel.cn/api/coding/paas/v4';
const GLM_MODEL: string = 'glm-5.3';
const MINIMAX_BASE: string = 'https://api.minimaxi.com/v1';
const MINIMAX_MODEL: string = 'MiniMax-M2.7';

class ProviderConfig {
  id: string = 'glm';
  label: string = 'GLM';
  baseUrl: string = GLM_BASE;
  apiKey: string = '';
  model: string = GLM_MODEL;
  splitReasoning: boolean = false;
}

class Completion {
  text: string = '';
  inputTokens: number = 0;
  outputTokens: number = 0;
  totalTokens: number = 0;
}

class GlmBody {
  model: string = '';
  messages: ChatTurn[] = [];
  temperature: number = 0.2;
  stream: boolean = false;
}

class MiniBody {
  model: string = '';
  messages: ChatTurn[] = [];
  temperature: number = 0.2;
  stream: boolean = false;
  reasoning_split: boolean = true;
}

class AuthHeaders {
  'Content-Type': string = 'application/json';
  Authorization: string = '';
  Accept: string = 'application/json';
}

interface UsageJson {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface MessageJson {
  content: string;
  reasoning_content: string;
}

interface ChoiceJson {
  message: MessageJson;
  delta: MessageJson;
}

interface ChatJson {
  choices: ChoiceJson[];
  usage: UsageJson;
  error: NestedMessage;
  message: string;
}

interface NestedMessage {
  message: string;
}

interface LookupJson {
  word: string;
  lemma: string;
  pronunciation: string;
  pos: string;
  definition: string;
  translation: string;
  context_translation: string;
}

interface SuggestItemJson {
  text: string;
  explaination: string;
  content: string;
}

interface SuggestJson {
  suggestions: SuggestItemJson[];
  words: SuggestItemJson[];
}

class SseEvent {
  event: string = 'message';
  data: string = '';
}

class SseBuffer {
  private buf: string = '';

  feed(chunk: string): SseEvent[] {
    this.buf = (this.buf + chunk).replace(/\r\n/g, '\n');
    const events: SseEvent[] = [];
    let idx = this.buf.indexOf('\n\n');
    while (idx >= 0) {
      const raw = this.buf.substring(0, idx);
      this.buf = this.buf.substring(idx + 2);
      const ev = this.parse(raw);
      if (ev.data.length > 0 || ev.event.length > 0) {
        events.push(ev);
      }
      idx = this.buf.indexOf('\n\n');
    }
    return events;
  }

  private parse(raw: string): SseEvent {
    const ev = new SseEvent();
    const lines = raw.split('\n');
    let data = '';
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      if (line.indexOf('event:') === 0) {
        ev.event = line.substring(6).trim();
      } else if (line.indexOf('data:') === 0) {
        if (data.length > 0) {
          data = data + '\n';
        }
        data = data + line.substring(5).trim();
      }
    }
    ev.data = data;
    return ev;
  }
}

class ThinkStrip {
  private inside: boolean = false;
  private hold: string = '';

  push(chunk: string): string {
    this.hold = this.hold + chunk;
    let out = '';
    while (this.hold.length > 0) {
      if (this.inside) {
        const end = this.hold.indexOf('</think>');
        if (end < 0) {
          const keep = tailPartial(this.hold, '</think>');
          this.hold = this.hold.substring(this.hold.length - keep);
          return out;
        }
        this.hold = this.hold.substring(end + 8);
        this.inside = false;
      } else {
        const start = this.hold.indexOf('<think>');
        if (start < 0) {
          const keep = tailPartial(this.hold, '<think>');
          out = out + this.hold.substring(0, this.hold.length - keep);
          this.hold = this.hold.substring(this.hold.length - keep);
          return out;
        }
        out = out + this.hold.substring(0, start);
        this.hold = this.hold.substring(start + 7);
        this.inside = true;
      }
    }
    return out;
  }
}

function tailPartial(text: string, tag: string): number {
  const max = tag.length - 1;
  const n = text.length < max ? text.length : max;
  for (let len = n; len > 0; len--) {
    if (tag.indexOf(text.substring(text.length - len)) === 0) {
      return len;
    }
  }
  return 0;
}

function stripThink(text: string): string {
  let out = text;
  let start = out.indexOf('<think>');
  while (start >= 0) {
    const end = out.indexOf('</think>', start);
    if (end < 0) {
      out = out.substring(0, start);
      break;
    }
    out = out.substring(0, start) + out.substring(end + 8);
    start = out.indexOf('<think>');
  }
  return out.trim();
}

function stored(name: string): string {
  const value = AppStorage.get<string>(name);
  return value === undefined ? '' : value.trim();
}

function orDefault(value: string, fallback: string): string {
  return value.length > 0 ? value : fallback;
}

function activeConfig(): ProviderConfig {
  const config = new ProviderConfig();
  const active = stored('activeProvider');
  if (active === 'minimax') {
    config.id = 'minimax';
    config.label = 'MiniMax';
    config.baseUrl = orDefault(stored('minimaxBaseUrl'), MINIMAX_BASE);
    config.apiKey = stored('minimaxApiKey');
    config.model = orDefault(stored('minimaxModel'), MINIMAX_MODEL);
    config.splitReasoning = true;
    return config;
  }
  config.baseUrl = orDefault(stored('glmBaseUrl'), GLM_BASE);
  config.apiKey = stored('glmApiKey');
  config.model = orDefault(stored('glmModel'), GLM_MODEL);
  return config;
}

function endpoint(base: string): string {
  let url = base.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.endsWith('/chat/completions')) {
    return url;
  }
  return url + '/chat/completions';
}

function payloadOf(config: ProviderConfig, messages: ChatTurn[], temperature: number, stream: boolean): string {
  if (config.splitReasoning) {
    const body = new MiniBody();
    body.model = config.model;
    body.messages = messages;
    body.temperature = temperature;
    body.stream = stream;
    body.reasoning_split = true;
    return JSON.stringify(body);
  }
  const body = new GlmBody();
  body.model = config.model;
  body.messages = messages;
  body.temperature = temperature;
  body.stream = stream;
  return JSON.stringify(body);
}

function applyUsage(completion: Completion, usage: UsageJson | undefined): void {
  if (usage === undefined) {
    return;
  }
  completion.inputTokens = usage.prompt_tokens ?? 0;
  completion.outputTokens = usage.completion_tokens ?? 0;
  completion.totalTokens = usage.total_tokens ?? 0;
  if (completion.totalTokens === 0) {
    completion.totalTokens = completion.inputTokens + completion.outputTokens;
  }
}

function remember(provider: string, completion: Completion): void {
  LlmUsageDao.add(provider, completion.inputTokens, completion.outputTokens, completion.totalTokens).catch(() => {
  });
}

function answerText(message: MessageJson | undefined): string {
  if (message === undefined) {
    return '';
  }
  const content = message.content ?? '';
  return stripThink(content);
}

function extractJson(text: string): Object {
  const trimmed = text.trim();
  let body = trimmed;
  const fence = trimmed.indexOf('```');
  if (fence >= 0) {
    const startFence = trimmed.indexOf('\n', fence);
    const endFence = trimmed.lastIndexOf('```');
    if (startFence >= 0 && endFence > startFence) {
      body = trimmed.substring(startFence + 1, endFence).trim();
    }
  }
  const start = body.indexOf('{');
  const end = body.lastIndexOf('}');
  if (start < 0 || end <= start) {
    throw new LlmError('invalid_json', '模型没有返回 JSON');
  }
  try {
    return JSON.parse(body.substring(start, end + 1)) as Object;
  } catch (err) {
    throw new LlmError('invalid_json', '无法解析模型返回的 JSON');
  }
}

function errorMessage(text: string, code: number): string {
  if (text.length > 0) {
    try {
      const raw = JSON.parse(text) as ChatJson;
      if (raw.error !== undefined && raw.error.message !== undefined && raw.error.message.length > 0) {
        return raw.error.message;
      }
      if (raw.message !== undefined && raw.message.length > 0 && raw.choices === undefined) {
        return raw.message;
      }
    } catch (err) {
      return text;
    }
  }
  return '请求失败（' + code.toString() + '）';
}

function readBody(code: number, result: string | Object | ArrayBuffer): string {
  const text = typeof result === 'string' ? result : '';
  if (code < 200 || code >= 300) {
    throw new LlmError('http', errorMessage(text, code));
  }
  return text;
}

export class LlmClient {
  private static instance: LlmClient | null = null;

  static shared(): LlmClient {
    if (LlmClient.instance === null) {
      LlmClient.instance = new LlmClient();
    }
    return LlmClient.instance;
  }

  async ping(): Promise<string> {
    const messages: ChatTurn[] = [];
    messages.push(turn('user', 'Reply with the single word ok.'));
    const completion = await this.complete(messages, 0);
    return completion.text;
  }

  async usage(): Promise<UsageInfo> {
    const config = activeConfig();
    return LlmUsageDao.get(config.id);
  }

  async lookup(word: string, context: string): Promise<LookupResult> {
    const config = activeConfig();
    const cacheKey = config.id + '\n' + config.model + '\nlookup\n' + word + '\n' + context;
    const cached = await LlmCacheDao.get(cacheKey);
    if (cached.length > 0) {
      return parseLookup(cached, word);
    }
    const prompt = lookupPrompt(word, context, 'en-US', 'zh-CN');
    const raw = await this.completeJson(messagesOf(prompt), LOOKUP_REPAIR, 0.2);
    const text = JSON.stringify(raw);
    await LlmCacheDao.put(cacheKey, 'lookup', text);
    return parseLookup(text, word);
  }

  async translate(text: string): Promise<string> {
    const config = activeConfig();
    const cacheKey = config.id + '\n' + config.model + '\ntranslate\n' + text;
    const cached = await LlmCacheDao.get(cacheKey);
    if (cached.length > 0) {
      return cached;
    }
    const prompt = translatePrompt(text, 'zh-CN');
    const completion = await this.complete(messagesOf(prompt), 0.2);
    await LlmCacheDao.put(cacheKey, 'translate', completion.text);
    return completion.text;
  }

  async analyze(text: string): Promise<string> {
    const prompt = analyzePrompt(text, 'en-US', 'zh-CN');
    const completion = await this.complete(messagesOf(prompt), 0.4);
    return completion.text;
  }

  async refine(text: string, context: string): Promise<string> {
    const prompt = refinePrompt(text, context, 'en-US', 'zh-CN');
    const completion = await this.complete(messagesOf(prompt), 0.4);
    return completion.text;
  }

  async suggest(context: string): Promise<Suggestion[]> {
    const prompt = suggestPrompt(context, 'en-US', 'zh-CN');
    const raw = await this.completeJson(messagesOf(prompt), SUGGEST_REPAIR, 0.4) as SuggestJson;
    return normalizeSuggestions(raw);
  }

  chat(role: string, messages: ChatTurn[], message: string, handlers: ChatHandlers): http.HttpRequest {
    const config = requireConfig();
    const client = http.createHttp();
    const parser = new SseBuffer();
    const strip = new ThinkStrip();
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    const payload = payloadOf(config, chatMessages(role, messages, message), 0.7, true);
    let settled = false;
    let counted = false;
    client.on('dataReceive', (data: ArrayBuffer) => {
      const text = decoder.decodeWithStream(new Uint8Array(data), { stream: true });
      const events = parser.feed(text);
      for (let i = 0; i < events.length; i++) {
        const dataText = events[i].data;
        if (dataText === '[DONE]') {
          if (!settled) {
            settled = true;
            if (!counted) {
              remember(config.id, new Completion());
            }
            handlers.onDone();
          }
          continue;
        }
        try {
          const chunk = JSON.parse(dataText) as ChatJson;
          const choices = chunk.choices ?? [];
          if (choices.length > 0 && choices[0].delta !== undefined) {
            const piece = strip.push(choices[0].delta.content ?? '');
            if (piece.length > 0) {
              handlers.onDelta(piece);
            }
          }
          if (chunk.usage !== undefined) {
            const completion = new Completion();
            applyUsage(completion, chunk.usage);
            remember(config.id, completion);
            counted = true;
          }
        } catch (err) {
          handlers.onError('无法解析回复');
        }
      }
    });
    client.on('dataEnd', () => {
      if (!settled) {
        settled = true;
        handlers.onDone();
      }
      client.destroy();
    });
    const headers = new AuthHeaders();
    headers.Authorization = 'Bearer ' + config.apiKey;
    headers.Accept = 'text/event-stream';
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: payload,
      connectTimeout: 60000,
      readTimeout: 120000,
      expectDataType: http.HttpDataType.STRING
    };
    client.requestInStream(endpoint(config.baseUrl), options, (err: BusinessError, code: number) => {
      if (err) {
        handlers.onError(err.message);
        return;
      }
      if (code >= 400) {
        handlers.onError('对话失败（' + code.toString() + '）');
      }
    });
    return client;
  }

  private async complete(messages: ChatTurn[], temperature: number): Promise<Completion> {
    const config = requireConfig();
    const client = http.createHttp();
    const headers = new AuthHeaders();
    headers.Authorization = 'Bearer ' + config.apiKey;
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: payloadOf(config, messages, temperature, false),
      connectTimeout: 60000,
      readTimeout: 90000,
      expectDataType: http.HttpDataType.STRING
    };
    try {
      const response = await client.request(endpoint(config.baseUrl), options);
      const text = readBody(response.responseCode, response.result);
      const raw = JSON.parse(text) as ChatJson;
      const choices = raw.choices ?? [];
      const completion = new Completion();
      if (choices.length > 0) {
        completion.text = answerText(choices[0].message);
      }
      applyUsage(completion, raw.usage);
      remember(config.id, completion);
      return completion;
    } finally {
      client.destroy();
    }
  }

  private async completeJson(messages: ChatTurn[], repair: string, temperature: number): Promise<Object> {
    const first = await this.complete(messages, temperature);
    try {
      return extractJson(first.text);
    } catch (err) {
      const retry: ChatTurn[] = [];
      for (let i = 0; i < messages.length; i++) {
        retry.push(messages[i]);
      }
      retry.push(turn('assistant', first.text));
      retry.push(turn('user', repair));
      const second = await this.complete(retry, 0);
      return extractJson(second.text);
    }
  }
}

function requireConfig(): ProviderConfig {
  const config = activeConfig();
  if (config.apiKey.length === 0) {
    throw new LlmError('config', '请先在「我的」里填写 ' + config.label + ' API Key');
  }
  if (config.baseUrl.length === 0) {
    throw new LlmError('config', '请先在「我的」里填写 ' + config.label + ' 接口地址');
  }
  return config;
}

function parseLookup(text: string, word: string): LookupResult {
  const raw = JSON.parse(text) as LookupJson;
  const result = new LookupResult();
  result.word = raw.word ?? word;
  result.lemma = raw.lemma ?? '';
  result.pronunciation = raw.pronunciation ?? '';
  result.pos = raw.pos ?? '';
  result.definition = raw.definition ?? '';
  result.translation = raw.translation ?? '';
  result.contextTranslation = raw.context_translation ?? '';
  return result;
}

function normalizeSuggestions(raw: SuggestJson): Suggestion[] {
  const items: Suggestion[] = [];
  const fromSuggestions = raw.suggestions ?? [];
  const source = fromSuggestions.length > 0 ? fromSuggestions : (raw.words ?? []);
  for (let i = 0; i < source.length; i++) {
    const item = new Suggestion();
    const text = source[i].text ?? source[i].content ?? '';
    item.text = text;
    item.explanation = source[i].explaination ?? '';
    if (item.text.length > 0) {
      items.push(item);
    }
  }
  return items;
}
