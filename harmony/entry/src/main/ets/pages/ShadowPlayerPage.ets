import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { media } from '@kit.MediaKit';
import { router } from '@kit.ArkUI';
import { getContext } from '../common/AppContext';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { LookupSheet } from '../components/LookupSheet';
import { ResultSheet } from '../components/ResultSheet';
import { MediaDao, MediaItem, NoteDao, NoteItem, RecordingDao, RecordingItem, SegmentDao, SegmentItem } from '../data/Db';
import { copyInto, ensureDir, pickFile, readText } from '../services/Files';
import { LlmClient } from '../services/LlmClient';
import { SpeechClient } from '../services/SpeechClient';
import { AssessResult, WordMark } from '../services/Types';
import { Cue, parseSubtitles } from '../services/Subtitles';

class MediaRoute {
  mediaId: number = 0;
}

async function ensureMic(): Promise<boolean> {
  const at = abilityAccessCtrl.createAtManager();
  const perms: Array<Permissions> = ['ohos.permission.MICROPHONE'];
  const result = await at.requestPermissionsFromUser(getContext(), perms);
  if (result.authResults.length === 0) {
    return false;
  }
  return result.authResults[0] === 0;
}

@Entry
@Component
struct ShadowPlayerPage {
  private player: media.AVPlayer | null = null;
  private mediaFd: number = -1;
  private opening: boolean = false;
  private ready: boolean = false;
  private wantState: string = '';
  private stateResolve: (() => void) | null = null;
  private recorder: media.AVRecorder | null = null;
  private recordFd: number = -1;
  private xController: XComponentController = new XComponentController();
  @State mediaId: number = 0;
  @State kind: string = 'audio';
  @State mediaPath: string = '';
  @State title: string = '';
  @State segments: SegmentItem[] = [];
  @State currentId: number = 0;
  @State sentence: string = '';
  @State looping: boolean = false;
  @State segmentStart: number = 0;
  @State segmentEnd: number = 0;
  @State surfaceId: string = '';
  @State recording: boolean = false;
  @State takePath: string = '';
  @State takeId: number = 0;
  @State score: number = -1;
  @State marks: WordMark[] = [];
  @State note: string = '';
  @State showLookup: boolean = false;
  @State showResult: boolean = false;
  @State resultTitle: string = '';
  @State resultBody: string = '';
  @State resultLoading: boolean = false;

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw === undefined) {
      return;
    }
    const params = raw as MediaRoute;
    this.mediaId = params.mediaId;
    this.load();
  }

  aboutToDisappear(): void {
    this.releasePlayer();
    this.stopRecorder();
  }

  load(): void {
    MediaDao.get(this.mediaId).then((item: MediaItem | null) => {
      if (item === null) {
        toast('找不到这段媒体');
        return;
      }
      this.kind = item.kind;
      this.mediaPath = item.path;
      this.title = item.name;
      if (this.kind === 'audio') {
        this.openPlayer();
      }
      return SegmentDao.list(this.mediaId);
    }).then((items: SegmentItem[] | undefined) => {
      if (items !== undefined) {
        this.segments = items;
        if (items.length > 0) {
          this.select(items[0]);
        }
      }
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  waitFor(state: string): Promise<void> {
    return new Promise((resolve: () => void) => {
      this.wantState = state;
      this.stateResolve = resolve;
    });
  }

  onState(state: string): void {
    if (this.stateResolve !== null && state === this.wantState) {
      const resolve = this.stateResolve;
      this.stateResolve = null;
      resolve();
    }
  }

  onTime(timeMs: number): void {
    if (this.segmentEnd > 0 && timeMs >= this.segmentEnd - 80 && this.player !== null) {
      if (this.looping) {
        this.player.seek(this.segmentStart);
      } else {
        this.player.pause();
        this.segmentEnd = 0;
      }
    }
  }

  async openPlayer(): Promise<void> {
    if (this.ready || this.opening) {
      return;
    }
    if (this.kind === 'video' && this.surfaceId.length === 0) {
      return;
    }
    if (this.mediaPath.length === 0) {
      return;
    }
    this.opening = true;
    try {
      const player = await media.createAVPlayer();
      this.player = player;
      player.on('stateChange', (state: string) => {
        this.onState(state);
      });
      player.on('timeUpdate', (timeMs: number) => {
        this.onTime(timeMs);
      });
      player.on('error', () => {
        toast('播放失败');
      });
      if (this.kind === 'video') {
        player.surfaceId = this.surfaceId;
      }
      const file = fileIo.openSync(this.mediaPath, fileIo.OpenMode.READ_ONLY);
      this.mediaFd = file.fd;
      const initialized = this.waitFor('initialized');
      player.url = 'fd://' + file.fd.toString();
      await initialized;
      const prepared = this.waitFor('prepared');
      await player.prepare();
      await prepared;
      this.ready = true;
      if (player.duration > 0) {
        MediaDao.updateDuration(this.mediaId, player.duration);
      }
    } catch (err) {
      toast(errorText(err as Object));
    }
    this.opening = false;
  }

  releasePlayer(): void {
    if (this.player !== null) {
      this.player.release();
      this.player = null;
    }
    if (this.mediaFd >= 0) {
      try {
        fileIo.closeSync(this.mediaFd);
      } catch (e) {
        return;
      }
      this.mediaFd = -1;
    }
    this.ready = false;
  }

  select(seg: SegmentItem): void {
    this.currentId = seg.id;
    this.sentence = seg.text;
    this.segmentStart = seg.startMs;
    this.segmentEnd = 0;
    this.score = -1;
    this.marks = [];
    this.takePath = '';
    this.takeId = 0;
    NoteDao.get(seg.id).then((note: NoteItem | null) => {
      this.note = note === null ? '' : note.content;
    });
    RecordingDao.latest(seg.id).then((item: RecordingItem | null) => {
      if (item !== null) {
        this.takePath = item.path;
        this.takeId = item.id;
        this.score = item.score;
      }
    });
  }

  async playCurrent(): Promise<void> {
    const seg = this.currentSegment();
    if (seg === null) {
      toast('还没有分句');
      return;
    }
    try {
      await this.openPlayer();
      if (this.player === null) {
        return;
      }
      this.segmentStart = seg.startMs;
      this.segmentEnd = seg.endMs;
      this.player.seek(seg.startMs);
      this.player.play();
    } catch (err) {
      toast(errorText(err as Object));
    }
  }

  currentSegment(): SegmentItem | null {
    for (let i = 0; i < this.segments.length; i++) {
      if (this.segments[i].id === this.currentId) {
        return this.segments[i];
      }
    }
    return null;
  }

  async startRecord(): Promise<void> {
    if (this.currentId === 0) {
      toast('先选一句');
      return;
    }
    try {
      const allowed = await ensureMic();
      if (!allowed) {
        toast('没有麦克风权限');
        return;
      }
      if (this.player !== null) {
        this.player.pause();
      }
      const dir = getContext().filesDir + '/recordings';
      ensureDir(dir);
      const path = dir + '/' + Date.now().toString() + '.m4a';
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      this.recordFd = file.fd;
      this.takePath = path;
      const profile: media.AVRecorderProfile = {
        audioBitrate: 48000,
        audioChannels: 1,
        audioCodec: media.CodecMimeType.AUDIO_AAC,
        audioSampleRate: 48000,
        fileFormat: media.ContainerFormatType.CFT_MPEG_4A
      };
      const config: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: profile,
        url: 'fd://' + file.fd.toString()
      };
      this.recorder = await media.createAVRecorder();
      await this.recorder.prepare(config);
      await this.recorder.start();
      this.recording = true;
    } catch (err) {
      this.recording = false;
      toast(errorText(err as Object));
    }
  }

  async stopRecord(): Promise<void> {
    try {
      await this.stopRecorder();
      if (this.takePath.length === 0 || this.currentId === 0) {
        return;
      }
      const id = await RecordingDao.insert(this.currentId, this.takePath);
      this.takeId = id;
      this.score = -1;
      toast('录音已保存');
    } catch (err) {
      toast(errorText(err as Object));
    }
  }

  async stopRecorder(): Promise<void> {
    if (!this.recording && this.recorder === null) {
      return;
    }
    try {
      if (this.recorder !== null) {
        await this.recorder.stop();
        await this.recorder.release();
        this.recorder = null;
      }
    } catch (e) {
      this.recorder = null;
    }
    if (this.recordFd >= 0) {
      try {
        fileIo.closeSync(this.recordFd);
      } catch (e) {
        this.recordFd = -1;
      }
      this.recordFd = -1;
    }
    this.recording = false;
  }

  playTake(): void {
    if (this.takePath.length === 0) {
      return;
    }
    media.createAVPlayer().then((take: media.AVPlayer) => {
      const file = fileIo.openSync(this.takePath, fileIo.OpenMode.READ_ONLY);
      take.url = 'fd://' + file.fd.toString();
      take.on('stateChange', (state: string) => {
        if (state === 'initialized') {
          take.prepare();
        } else if (state === 'prepared') {
          take.play();
        } else if (state === 'completed' || state === 'error') {
          take.release();
          fileIo.closeSync(file.fd);
        }
      });
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  saveNote(): void {
    if (this.currentId === 0) {
      return;
    }
    NoteDao.save(this.currentId, this.note).then(() => {
      toast('笔记已保存');
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  showText(title: string, work: Promise<string>): void {
    this.resultTitle = title;
    this.resultBody = '';
    this.resultLoading = true;
    this.showResult = true;
    work.then((text: string) => {
      this.resultBody = text;
      this.resultLoading = false;
    }).catch((err: Object) => {
      this.resultBody = errorText(err);
      this.resultLoading = false;
    });
  }

  importSubtitle(): void {
    pickFile().then((uri: string) => {
      if (uri.length === 0) {
        throw new Error('cancel');
      }
      const copied = copyInto(uri, 'subs');
      const cues = parseSubtitles(readText(copied));
      const segments: SegmentItem[] = [];
      for (let i = 0; i < cues.length; i++) {
        const item = new SegmentItem();
        item.startMs = cues[i].startMs;
        item.endMs = cues[i].endMs;
        item.text = cues[i].text;
        segments.push(item);
      }
      return SegmentDao.replace(this.mediaId, segments);
    }).then(() => {
      return SegmentDao.list(this.mediaId);
    }).then((items: SegmentItem[]) => {
      this.segments = items;
      if (items.length > 0) {
        this.select(items[0]);
      }
      toast('已导入 ' + items.length.toString() + ' 句');
    }).catch((err: Object) => {
      if (err instanceof Error && err.message === 'cancel') {
        return;
      }
      toast(errorText(err));
    });
  }

  transcribe(): void {
    if (this.mediaPath.length === 0) {
      return;
    }
    toast('正在转写，可能要等一会儿');
    SpeechClient.shared().transcribe(this.mediaPath).then((cues: Cue[]) => {
      const segments: SegmentItem[] = [];
      for (let i = 0; i < cues.length; i++) {
        const item = new SegmentItem();
        item.startMs = cues[i].startMs;
        item.endMs = cues[i].endMs;
        item.text = cues[i].text;
        segments.push(item);
      }
      return SegmentDao.replace(this.mediaId, segments);
    }).then(() => {
      return SegmentDao.list(this.mediaId);
    }).then((items: SegmentItem[]) => {
      this.segments = items;
      if (items.length > 0) {
        this.select(items[0]);
      }
      toast('已分成 ' + items.length.toString() + ' 句');
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  assess(): void {
    if (this.takePath.length === 0 || this.sentence.length === 0) {
      toast('先录一遍这句');
      return;
    }
    SpeechClient.shared().assess(this.takePath, this.sentence).then((result: AssessResult) => {
      this.score = result.score;
      this.marks = result.words;
      if (this.takeId > 0) {
        RecordingDao.updateScore(this.takeId, result.score, result.hypothesis);
      }
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  markColor(status: string): string {
    if (status === 'match') {
      return Theme.ok;
    }
    if (status === 'extra' || status === 'missing') {
      return Theme.bad;
    }
    return Theme.accent;
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('返回')
            .fontColor(Theme.accent)
            .onClick(() => {
              router.back();
            })
          Text(this.title)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .textAlign(TextAlign.Center)
            .fontColor(Theme.ink)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (this.kind === 'video') {
          XComponent({
            id: 'shadowVideo',
            type: XComponentType.SURFACE,
            controller: this.xController
          })
            .width('100%')
            .height(220)
            .backgroundColor('#000000')
            .onLoad(() => {
              this.surfaceId = this.xController.getXComponentSurfaceId();
              this.openPlayer();
            })
        }

        Text(this.sentence.length > 0 ? this.sentence : '选一句开始跟读')
          .fontSize(18)
          .fontColor(Theme.ink)
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        if (this.score >= 0) {
          Text('发音 ' + this.score.toString())
            .fontSize(16)
            .fontColor(Theme.accent)
            .width('100%')
            .padding({ left: 16, right: 16 })
        }
        if (this.marks.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.marks, (word: WordMark) => {
              Text(word.actual.length > 0 ? word.actual : word.expected)
                .fontSize(14)
                .fontColor(this.markColor(word.status))
                .decoration({ type: word.status === 'missing' ? TextDecorationType.LineThrough : TextDecorationType.None })
                .margin(4)
            }, (word: WordMark, index: number) => index.toString() + word.expected + word.actual)
          }
          .width('100%')
          .padding({ left: 12, right: 12 })
        }

        Flex({ wrap: FlexWrap.Wrap }) {
          Button('播放').height(32).fontSize(14).backgroundColor(Theme.accent).margin(4).onClick(() => { this.playCurrent(); })
          Button(this.looping ? '循环开' : '循环关').height(32).fontSize(14).backgroundColor(Theme.ink).margin(4).onClick(() => { this.looping = !this.looping; })
          Button(this.recording ? '停止' : '录音').height(32).fontSize(14).backgroundColor(Theme.bad).margin(4).onClick(() => {
            if (this.recording) {
              this.stopRecord();
            } else {
              this.startRecord();
            }
          })
          Button('回放').height(32).fontSize(14).backgroundColor(Theme.ink).margin(4).onClick(() => { this.playTake(); })
          Button('评分').height(32).fontSize(14).backgroundColor(Theme.ok).margin(4).onClick(() => { this.assess(); })
          Button('翻译').height(32).fontSize(14).backgroundColor(Theme.ink).margin(4).onClick(() => { this.showText('翻译', LlmClient.shared().translate(this.sentence)); })
          Button('分析').height(32).fontSize(14).backgroundColor(Theme.ink).margin(4).onClick(() => { this.showText('分析', LlmClient.shared().analyze(this.sentence)); })
          Button('润色').height(32).fontSize(14).backgroundColor(Theme.ink).margin(4).onClick(() => { this.showText('润色', LlmClient.shared().refine(this.sentence, '')); })
          Button('查词').height(32).fontSize(14).backgroundColor(Theme.accent).margin(4).onClick(() => { this.showLookup = true; })
          Button('字幕').height(32).fontSize(14).backgroundColor(Theme.muted).margin(4).onClick(() => { this.importSubtitle(); })
          Button('自动分句').height(32).fontSize(14).backgroundColor(Theme.muted).margin(4).onClick(() => { this.transcribe(); })
        }
        .width('100%')
        .padding({ left: 12, right: 12 })

        TextArea({ text: this.note, placeholder: '这句的笔记' })
          .height(72)
          .margin({ left: 16, right: 16, top: 8 })
          .onChange((value: string) => {
            this.note = value;
          })
        Button('保存笔记')
          .height(32)
          .fontSize(14)
          .backgroundColor(Theme.ink)
          .margin({ top: 6, bottom: 6 })
          .onClick(() => {
            this.saveNote();
          })

        List() {
          ForEach(this.segments, (seg: SegmentItem) => {
            ListItem() {
              Text(seg.text)
                .fontSize(15)
                .fontColor(seg.id === this.currentId ? Theme.accent : Theme.ink)
                .width('100%')
                .padding({ left: 16, right: 16, top: 10, bottom: 10 })
                .backgroundColor(seg.id === this.currentId ? '#F8E6E1' : Theme.card)
                .onClick(() => {
                  this.select(seg);
                  this.playCurrent();
                })
            }
          }, (seg: SegmentItem) => seg.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      if (this.showLookup) {
        LookupSheet({
          initialWord: '',
          context: this.sentence,
          onClose: (): void => {
            this.showLookup = false;
          }
        })
      }
      if (this.showResult) {
        ResultSheet({
          title: this.resultTitle,
          body: this.resultBody,
          loading: this.resultLoading,
          onClose: (): void => {
            this.showResult = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
