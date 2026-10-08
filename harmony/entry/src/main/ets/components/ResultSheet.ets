import { Theme } from '../common/Theme';

@Component
export struct ResultSheet {
  @Prop title: string = '';
  @Prop body: string = '';
  @Prop loading: boolean = false;
  onClose: () => void = (): void => {};

  build() {
    Column() {
      Column()
        .layoutWeight(1)
        .width('100%')
        .onClick(() => {
          this.onClose();
        })
      Column() {
        Row() {
          Text(this.title)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
            .layoutWeight(1)
          Text('关闭')
            .fontColor(Theme.accent)
            .onClick(() => {
              this.onClose();
            })
        }
        .width('100%')
        Scroll() {
          if (this.loading) {
            Text('正在想…').fontColor(Theme.muted).width('100%').margin({ top: 12 })
          } else {
            Text(this.body)
              .fontSize(16)
              .fontColor(Theme.ink)
              .width('100%')
              .margin({ top: 12 })
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('78%')
      .padding(20)
      .backgroundColor(Theme.card)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }
}
