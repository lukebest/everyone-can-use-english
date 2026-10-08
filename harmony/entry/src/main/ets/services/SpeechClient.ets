import { http } from '@kit.NetworkKit';
import { Cue } from './Subtitles';
import { AssessResult, LlmError, WordMark } from './Types';

class FileHeaders {
  Authorization: string = '';
  Accept: string = 'application/json';
}

interface ErrorJson {
  message: string;
}

interface SegmentJson {
  startMs: number;
  endMs: number;
  text: string;
}

interface TranscribeJson {
  segments: SegmentJson[];
}

interface WordJson {
  expected: string;
  actual: string;
  status: string;
}

interface AssessJson {
  score: number;
  hypothesis: string;
  words: WordJson[];
}

function speechBase(): string {
  const stored = AppStorage.get<string>('speechUrl');
  let url = stored === undefined ? '' : stored.trim();
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (url.length === 0) {
    throw new LlmError('config', '自动分句和评分需要在「我的」里填写语音中转地址');
  }
  return url;
}

function speechToken(): string {
  const stored = AppStorage.get<string>('speechToken');
  const token = stored === undefined ? '' : stored.trim();
  if (token.length === 0) {
    throw new LlmError('config', '请先在「我的」里填写语音中转 Token');
  }
  return token;
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
    throw new LlmError('http', message);
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

export class SpeechClient {
  private static instance: SpeechClient | null = null;

  static shared(): SpeechClient {
    if (SpeechClient.instance === null) {
      SpeechClient.instance = new SpeechClient();
    }
    return SpeechClient.instance;
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
    headers.Authorization = 'Bearer ' + speechToken();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.POST,
      header: headers,
      multiFormDataList: parts,
      connectTimeout: 60000,
      readTimeout: 300000,
      expectDataType: http.HttpDataType.STRING
    };
    try {
      const response = await client.request(speechBase() + path, options);
      return readBody(response.responseCode, response.result);
    } finally {
      client.destroy();
    }
  }
}
