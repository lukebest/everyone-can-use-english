import { Theme } from '../common/Theme';
import { CourseTab } from './CourseTab';
import { ShadowTab } from './ShadowTab';
import { ChatTab } from './ChatTab';
import { VocabTab } from './VocabTab';
import { MineTab } from './MineTab';

@Entry
@Component
struct Index {
  @State current: number = 0;

  @Builder
  tabLabel(title: string, index: number) {
    Text(title)
      .fontSize(12)
      .fontColor(this.current === index ? Theme.accent : Theme.muted)
      .padding({ top: 8, bottom: 8 })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.current }) {
      TabContent() {
        CourseTab()
      }
      .tabBar(this.tabLabel('课程', 0))

      TabContent() {
        ShadowTab()
      }
      .tabBar(this.tabLabel('跟读', 1))

      TabContent() {
        ChatTab()
      }
      .tabBar(this.tabLabel('对话', 2))

      TabContent() {
        VocabTab()
      }
      .tabBar(this.tabLabel('生词', 3))

      TabContent() {
        MineTab()
      }
      .tabBar(this.tabLabel('我的', 4))
    }
    .onChange((index: number) => {
      this.current = index;
    })
    .barHeight(56)
    .backgroundColor(Theme.bg)
    .width('100%')
    .height('100%')
  }
}
