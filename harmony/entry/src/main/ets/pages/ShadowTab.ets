import { router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { promptAction } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { MediaDao, MediaItem, SegmentDao, SegmentItem } from '../data/Db';
import { baseName, copyInto, mediaKind, pickFile, readText } from '../services/Files';
import { parseSubtitles } from '../services/Subtitles';

class MediaRoute {
  mediaId: number = 0;
}

@Component
export struct ShadowTab {
  @State items: MediaItem[] = [];

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    this.reload();
  }

  reload(): void {
    MediaDao.list().then((items: MediaItem[]) => {
      this.items = items;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  importMedia(): void {
    pickFile().then((uri: string) => {
      if (uri.length === 0) {
        return;
      }
      const name = baseName(uri);
      const path = copyInto(uri, 'media');
      const kind = mediaKind(name);
      MediaDao.insert(kind, name, path).then((id: number) => {
        this.askSubtitle(id);
      }).catch((err: Object) => {
        toast(errorText(err));
      });
    }).catch(() => {
      return;
    });
  }

  askSubtitle(mediaId: number): void {
    const skip: promptAction.Button = { text: '跳过', color: Theme.muted };
    const choose: promptAction.Button = { text: '选择字幕', color: Theme.accent };
    const buttons: Array<promptAction.Button> = [skip, choose];
    const dialog: promptAction.ShowDialogOptions = {
      title: '字幕',
      message: '现在选择 SRT 或 VTT？没有的话可以进播放页自动分句。',
      buttons: buttons
    };
    promptAction.showDialog(dialog).then((result: promptAction.ShowDialogSuccessResponse) => {
      if (result.index === 1) {
        this.importSubtitle(mediaId).then(() => {
          this.open(mediaId);
        });
        return;
      }
      this.open(mediaId);
    }).catch(() => {
      this.open(mediaId);
    });
  }

  importSubtitle(mediaId: number): Promise<void> {
    return pickFile().then((uri: string) => {
      if (uri.length === 0) {
        return;
      }
      const copied = copyInto(uri, 'subs');
      const text = readText(copied);
      const cues = parseSubtitles(text);
      const segments: SegmentItem[] = [];
      for (let i = 0; i < cues.length; i++) {
        const item = new SegmentItem();
        item.startMs = cues[i].startMs;
        item.endMs = cues[i].endMs;
        item.text = cues[i].text;
        segments.push(item);
      }
      return SegmentDao.replace(mediaId, segments).then(() => {
        try {
          fileIo.unlinkSync(copied);
        } catch (e) {
          return;
        }
      });
    });
  }

  open(mediaId: number): void {
    const params = new MediaRoute();
    params.mediaId = mediaId;
    const options: router.RouterOptions = {
      url: 'pages/ShadowPlayerPage',
      params: params
    };
    router.pushUrl(options).then(() => {
      this.reload();
    });
  }

  remove(item: MediaItem): void {
    MediaDao.remove(item.id).then(() => {
      try {
        fileIo.unlinkSync(item.path);
      } catch (e) {
        return;
      }
      this.reload();
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  build() {
    Column() {
      Row() {
        Text('跟读')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink)
          .layoutWeight(1)
        Button('导入')
          .height(36)
          .fontSize(14)
          .backgroundColor(Theme.accent)
          .onClick(() => {
            this.importMedia();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 16, bottom: 8 })

      if (this.items.length === 0) {
        Text('导入一段音频或视频，配上字幕，就能逐句播放、录音对比。')
          .fontColor(Theme.muted)
          .padding({ left: 20, right: 20, top: 12 })
      }

      List() {
        ForEach(this.items, (item: MediaItem) => {
          ListItem() {
            Row() {
              Column() {
                Text(item.name)
                  .fontSize(16)
                  .fontColor(Theme.ink)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(item.kind === 'video' ? '视频' : '音频')
                  .fontSize(12)
                  .fontColor(Theme.muted)
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .onClick(() => {
                this.open(item.id);
              })
              Text('删除')
                .fontColor(Theme.bad)
                .onClick(() => {
                  this.remove(item);
                })
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
          }
        }, (item: MediaItem) => item.id.toString())
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
