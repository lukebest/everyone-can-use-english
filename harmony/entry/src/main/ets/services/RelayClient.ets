import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { Cue } from './Subtitles';

export class RelayError extends Error {
  code: string = '';

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

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

export class ChatHandlers {
  onDelta: (text: string) => void = (text: string): void => {
    if (text.length < 0) {
      return;
    }
  };
  onDone: (runId: string) => void = (runId: string): void => {
    if (runId.length < 0) {
      return;
    }
  };
  onError: (message: string) => void = (message: string): void => {
    if (message.length < 0) {
      return;
    }
  };
}

export class ChatTurn {
  role: string = '';
  content: string = '';
}

class LookupBody {
  word: string = '';
  context: string = '';
  learningLanguage: string = 'en-US';
  nativeLanguage: string = 'zh-CN';
}

class TextBody {
  text: string = '';
  context: string = '';
  learningLanguage: string = 'en-US';
  nativeLanguage: string = 'zh-CN';
}

class SuggestBody {
  context: string = '';
  learningLanguage: string = 'en-US';
  nativeLanguage: string = 'zh-CN';
}

class ChatBody {
  role: string = '';
  message: string = '';
  messages: TurnJson[] = [];
}

class AuthHeaders {
  'Content-Type': string = 'application/json';
  Authorization: string = '';
  Accept: string = 'application/json';
}

class FileHeaders {
  Authorization: string = '';
  Accept: string = 'application/json';
}

interface ErrorJson {
  error: string;
  message: string;
}

interface TextJson {
  text: string;
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

interface SuggestJson {
  suggestions: SuggestItemJson[];
}

interface SuggestItemJson {
  text: string;
  explanation: string;
}

interface UsageJson {
  totals: UsageTotalsJson;
}

interface UsageTotalsJson {
  requests: number;
  totalTokens: number;
  inputTokens: number;
  outputTokens: number;
}

interface SegmentJson {
  startMs: number;
  endMs: number;
  text: string;
}

interface TranscribeJson {
  segments: SegmentJson[];
}

interface AssessJson {
  score: number;
  hypothesis: string;
  words: WordJson[];
}

interface WordJson {
  expected: string;
  actual: string;
  status: string;
}

interface DeltaJson {
  text: string;
}

interface DoneJson {
  runId: string;
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

export class RelayClient {
  private static instance: RelayClient | null = null;

  static shared(): RelayClient {
    if (RelayClient.instance === null) {
      RelayClient.instance = new RelayClient();
    }
    return RelayClient.instance;
  }

  async lookup(word: string, context: string): Promise<LookupResult> {
    const body = new LookupBody();
    body.word = word;
    body.context = context;
    const text = await this.postJson('/v1/lookup', JSON.stringify(body));
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

  async translate(text: string): Promise<string> {
    const body = new TextBody();
    body.text = text;
    const raw = JSON.parse(await this.postJson('/v1/translate', JSON.stringify(body))) as TextJson;
    return raw.text ?? '';
  }

  async analyze(text: string): Promise<string> {
    const body = new TextBody();
    body.text = text;
    const raw = JSON.parse(await this.postJson('/v1/analyze', JSON.stringify(body))) as TextJson;
    return raw.text ?? '';
  }

  async refine(text: string, context: string): Promise<string> {
    const body = new TextBody();
    body.text = text;
    body.context = context;
    const raw = JSON.parse(await this.postJson('/v1/refine', JSON.stringify(body))) as TextJson;
    return raw.text ?? '';
  }

  async suggest(context: string): Promise<Suggestion[]> {
    const body = new SuggestBody();
    body.context = context;
    const raw = JSON.parse(await this.postJson('/v1/suggest', JSON.stringify(body))) as SuggestJson;
    const items: Suggestion[] = [];
    const list = raw.suggestions ?? [];
    for (let i = 0; i < list.length; i++) {
      const item = new Suggestion();
      item.text = list[i].text ?? '';
      item.explanation = list[i].explanation ?? '';
      items.push(item);
    }
    return items;
  }

  async usage(): Promise<UsageInfo> {
    const text = await this.getJson('/v1/usage');
    const raw = JSON.parse(text) as UsageJson;
    const info = new UsageInfo();
    if (raw.totals !== undefined) {
      info.requests = raw.totals.requests ?? 0;
      info.totalTokens = raw.totals.totalTokens ?? 0;
      info.inputTokens = raw.totals.inputTokens ?? 0;
      info.outputTokens = raw.totals.outputTokens ?? 0;
    }
    return info;
  }

  async transcribe(filePath: string): Promise<Cue[]> {
    const text = await this.postFile('/v1/transcribe', filePath, '');
    const raw = JSON.parse(text) as TranscribeJson;
    return cuesFrom(raw.segments ?? []);
  }

  async assess(filePath: string, reference: string): Promise<AssessResult> {
    const text = await this.postFile('/v1/assess', filePath, reference);
    const raw = JSON.parse(text) as AssessJson;
    const result = new AssessResult();
    result.score = raw.score ?? 0;
    result.hypothesis = raw.hypothesis ?? '';
    const words = raw.words ?? [];
    for (let i = 0; i < words.length; i++) {
      const mark = new WordMark();
      mark.expected = words[i].expected ?? '';
      mark.actual = words[i].actual ?? '';
      mark.status = words[i].status ?? '';
      result.words.push(mark);
    }
    return result;
  }

  chat(role: string, messages: ChatTurn[], message: string, handlers: ChatHandlers): http.HttpRequest {
    const client = http.createHttp();
    const parser = new SseBuffer();
    const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
    const payloadBody = new ChatBody();
    payloadBody.role = role;
    payloadBody.message = message;
    payloadBody.messages = turnsPayload(messages);
    const payload = JSON.stringify(payloadBody);
    client.on('dataReceive', (data: ArrayBuffer) => {
      const text = decoder.decodeWithStream(new Uint8Array(data), { stream: true });
      const events = parser.feed(text);
      for (let i = 0; i < events.length; i++) {
        dispatchSse(events[i], handlers);
      }
    });
    client.on('dataEnd', () => {
      client.destroy();
    });
    const headers = new AuthHeaders();
    headers.Authorization = 'Bearer ' + this.token();
    headers.Accept = 'text/event-stream';
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: payload,
      connectTimeout: 60000,
      readTimeout: 120000,
      expectDataType: http.HttpDataType.STRING
    };
    client.requestInStream(this.base() + '/v1/chat', options, (err: BusinessError, code: number) => {
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

  private async postJson(path: string, payload: string): Promise<string> {
    const client = http.createHttp();
    const headers = new AuthHeaders();
    headers.Authorization = 'Bearer ' + this.token();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      extraData: payload,
      connectTimeout: 60000,
      readTimeout: 90000,
      expectDataType: http.HttpDataType.STRING
    };
    try {
      const response = await client.request(this.base() + path, options);
      return readBody(response.responseCode, response.result);
    } finally {
      client.destroy();
    }
  }

  private async getJson(path: string): Promise<string> {
    const client = http.createHttp();
    const headers = new AuthHeaders();
    headers.Authorization = 'Bearer ' + this.token();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: headers,
      connectTimeout: 30000,
      readTimeout: 30000,
      expectDataType: http.HttpDataType.STRING
    };
    try {
      const response = await client.request(this.base() + path, options);
      return readBody(response.responseCode, response.result);
    } finally {
      client.destroy();
    }
  }

  private async postFile(path: string, filePath: string, reference: string): Promise<string> {
    const client = http.createHttp();
    const audio: http.MultiFormData = {
      name: 'audio',
      contentType: 'application/octet-stream',
      filePath: filePath,
      remoteFileName: 'audio.m4a'
    };
    const parts: Array<http.MultiFormData> = [audio];
    if (reference.length > 0) {
      const ref: http.MultiFormData = {
        name: 'reference',
        contentType: 'text/plain',
        data: reference
      };
      parts.push(ref);
    }
    const headers = new FileHeaders();
    headers.Authorization = 'Bearer ' + this.token();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      multiFormDataList: parts,
      connectTimeout: 60000,
      readTimeout: 300000,
      expectDataType: http.HttpDataType.STRING
    };
    try {
      const response = await client.request(this.base() + path, options);
      return readBody(response.responseCode, response.result);
    } finally {
      client.destroy();
    }
  }

  private base(): string {
    const stored = AppStorage.get<string>('relayUrl');
    let url = stored === undefined ? '' : stored.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    if (url.length === 0) {
      throw new RelayError('config', '请先在「我的」里填写中转地址');
    }
    return url;
  }

  private token(): string {
    const stored = AppStorage.get<string>('relayToken');
    const token = stored === undefined ? '' : stored.trim();
    if (token.length === 0) {
      throw new RelayError('config', '请先在「我的」里填写访问 Token');
    }
    return token;
  }
}

function readBody(code: number, result: string | Object | ArrayBuffer): string {
  const text = typeof result === 'string' ? result : '';
  if (code < 200 || code >= 300) {
    let message = '请求失败（' + code.toString() + '）';
    if (text.length > 0) {
      try {
        const err = JSON.parse(text) as ErrorJson;
        if (err.message !== undefined && err.message.length > 0) {
          message = err.message;
        }
      } catch (e) {
        message = text;
      }
    }
    throw new RelayError('http', message);
  }
  return text;
}

function cuesFrom(segments: SegmentJson[]): Cue[] {
  const cues: Cue[] = [];
  for (let i = 0; i < segments.length; i++) {
    const cue = new Cue();
    cue.startMs = segments[i].startMs ?? 0;
    cue.endMs = segments[i].endMs ?? 0;
    cue.text = (segments[i].text ?? '').trim();
    if (cue.text.length > 0) {
      if (cue.endMs <= cue.startMs) {
        cue.endMs = cue.startMs + 1000;
      }
      cues.push(cue);
    }
  }
  return cues;
}

interface TurnJson {
  role: string;
  content: string;
}

function turnsPayload(messages: ChatTurn[]): TurnJson[] {
  const out: TurnJson[] = [];
  const start = messages.length > 12 ? messages.length - 12 : 0;
  for (let i = start; i < messages.length; i++) {
    const role = messages[i].role === 'assistant' ? 'assistant' : 'user';
    const item: TurnJson = { role: role, content: messages[i].content };
    out.push(item);
  }
  return out;
}

function dispatchSse(ev: SseEvent, handlers: ChatHandlers): void {
  try {
    if (ev.event === 'delta') {
      const body = JSON.parse(ev.data) as DeltaJson;
      handlers.onDelta(body.text ?? '');
    } else if (ev.event === 'done') {
      const body = JSON.parse(ev.data) as DoneJson;
      handlers.onDone(body.runId ?? '');
    } else if (ev.event === 'error') {
      const body = JSON.parse(ev.data) as ErrorJson;
      handlers.onError(body.message ?? '对话失败');
    }
  } catch (e) {
    handlers.onError('无法解析回复');
  }
}
