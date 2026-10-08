import { router } from '@kit.ArkUI';
import { webview } from '@kit.ArkWeb';
import { Theme } from '../common/Theme';
import { LookupSheet } from '../components/LookupSheet';

class LessonRoute {
  file: string = '';
  title: string = '';
}

let selectionHandler: (text: string) => void = (text: string): void => {
  if (text.length < 0) {
    return;
  }
};

class CourseBridge {
  onSelection(text: string): void {
    const fn = selectionHandler;
    setTimeout((): void => {
      fn(text);
    }, 0);
  }
}

function rawUrl(file: string): string {
  const parts = file.split('/');
  let encoded = '';
  for (let i = 0; i < parts.length; i++) {
    if (i > 0) {
      encoded = encoded + '/';
    }
    encoded = encoded + encodeURIComponent(parts[i]);
  }
  return 'resource://rawfile/course/' + encoded;
}

function clipSelection(text: string): string {
  let value = text.trim();
  if (value.length > 80) {
    value = value.substring(0, 80);
  }
  return value;
}

@Entry
@Component
struct CourseReaderPage {
  private controller: webview.WebviewController = new webview.WebviewController();
  private bridge: CourseBridge = new CourseBridge();
  @State title: string = '';
  @State pageUrl: string = '';
  @State selection: string = '';
  @State showLookup: boolean = false;

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw !== undefined) {
      const params = raw as LessonRoute;
      this.title = params.title ?? '';
      this.pageUrl = rawUrl(params.file ?? '');
    }
    const self = this;
    selectionHandler = (text: string): void => {
      self.selection = clipSelection(text);
    };
  }

  aboutToDisappear(): void {
    selectionHandler = (text: string): void => {
      if (text.length < 0) {
        return;
      }
    };
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
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor(Theme.ink)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 8 })

        Web({ src: this.pageUrl, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(true)
          .imageAccess(true)
          .onlineImageAccess(true)
          .javaScriptProxy({
            object: this.bridge,
            name: 'EnjoyBridge',
            methodList: ['onSelection'],
            controller: this.controller
          })
          .layoutWeight(1)
          .width('100%')

        if (this.selection.length > 0) {
          Row() {
            Text(this.selection)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .fontColor(Theme.ink)
            Button('查词')
              .height(32)
              .fontSize(14)
              .backgroundColor(Theme.accent)
              .onClick(() => {
                this.showLookup = true;
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(Theme.card)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      if (this.showLookup) {
        LookupSheet({
          initialWord: this.selection,
          context: this.selection,
          onClose: (): void => {
            this.showLookup = false;
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
