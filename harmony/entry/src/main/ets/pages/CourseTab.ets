import { router } from '@kit.ArkUI';
import { util } from '@kit.ArkTS';
import { getContext } from '../common/AppContext';
import { Theme } from '../common/Theme';

@Observed
class CourseRow {
  key: string = '';
  title: string = '';
  file: string = '';
  header: boolean = false;
}

class LessonJson {
  title: string = '';
  file: string = '';
}

class GroupJson {
  title: string = '';
  lessons: LessonJson[] = [];
}

class IndexJson {
  groups: GroupJson[] = [];
}

class LessonRoute {
  file: string = '';
  title: string = '';
}

@Component
export struct CourseTab {
  @State rows: CourseRow[] = [];
  @State hint: string = '';

  aboutToAppear(): void {
    this.load();
  }

  load(): void {
    getContext().resourceManager.getRawFileContent('course/index.json').then((buf: Uint8Array) => {
      const decoder = util.TextDecoder.create('utf-8');
      const text = decoder.decodeWithStream(buf);
      const parsed = JSON.parse(text) as IndexJson;
      const rows: CourseRow[] = [];
      const groups = parsed.groups ?? [];
      for (let i = 0; i < groups.length; i++) {
        const header = new CourseRow();
        header.key = 'h-' + i.toString();
        header.title = groups[i].title;
        header.header = true;
        rows.push(header);
        const lessons = groups[i].lessons ?? [];
        for (let j = 0; j < lessons.length; j++) {
          const row = new CourseRow();
          row.key = lessons[j].file;
          row.title = lessons[j].title;
          row.file = lessons[j].file;
          rows.push(row);
        }
      }
      this.rows = rows;
      this.hint = '';
    }).catch(() => {
      this.hint = '课程还没打包。在 harmony 目录运行 npm run build:course。';
    });
  }

  open(row: CourseRow): void {
    const params = new LessonRoute();
    params.file = row.file;
    params.title = row.title;
    const options: router.RouterOptions = {
      url: 'pages/CourseReaderPage',
      params: params
    };
    router.pushUrl(options);
  }

  build() {
    Column() {
      Text('语音塑造')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink)
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 8 })
      if (this.hint.length > 0) {
        Text(this.hint)
          .fontColor(Theme.muted)
          .padding({ left: 20, right: 20 })
      }
      List() {
        ForEach(this.rows, (row: CourseRow) => {
          ListItem() {
            if (row.header) {
              Text(row.title)
                .fontSize(13)
                .fontColor(Theme.muted)
                .width('100%')
                .padding({ left: 20, right: 20, top: 16, bottom: 4 })
            } else {
              Text(row.title)
                .fontSize(16)
                .fontColor(Theme.ink)
                .width('100%')
                .padding({ left: 20, right: 20, top: 12, bottom: 12 })
                .backgroundColor(Theme.card)
                .onClick(() => {
                  this.open(row);
                })
            }
          }
        }, (row: CourseRow) => row.key)
      }
      .layoutWeight(1)
      .width('100%')
      .divider({ strokeWidth: 0.5, color: Theme.line })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
