import { textToSpeech } from '@kit.CoreSpeechKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { toast } from '../common/Ui';

export class Tts {
  private engine: textToSpeech.TextToSpeechEngine | null = null;
  private creating: boolean = false;
  private pending: string = '';

  speak(text: string): void {
    const spoken = text.trim();
    if (spoken.length === 0) {
      return;
    }
    if (this.engine !== null) {
      this.say(spoken);
      return;
    }
    this.pending = spoken;
    if (this.creating) {
      return;
    }
    this.creating = true;
    const params: textToSpeech.CreateEngineParams = {
      language: 'en-US',
      online: 1,
      person: 8
    };
    const self = this;
    textToSpeech.createEngine(params, (err: BusinessError, engine: textToSpeech.TextToSpeechEngine) => {
      self.creating = false;
      if (err) {
        toast('英语朗读不可用，请在系统里下载英语语音（劳拉）');
        return;
      }
      self.engine = engine;
      if (self.pending.length > 0) {
        self.say(self.pending);
      }
    });
  }

  private say(text: string): void {
    if (this.engine === null) {
      return;
    }
    const speakParams: textToSpeech.SpeakParams = {
      requestId: Date.now().toString()
    };
    this.engine.speak(text, speakParams);
  }
}

let shared: Tts | null = null;

export function tts(): Tts {
  if (shared === null) {
    shared = new Tts();
  }
  return shared;
}
