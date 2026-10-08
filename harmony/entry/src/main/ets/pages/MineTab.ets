import { Settings, SettingsData } from '../common/Settings';
import { getContext } from '../common/AppContext';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { RelayClient, UsageInfo } from '../services/RelayClient';

@Component
export struct MineTab {
  @State relayUrl: string = '';
  @State relayToken: string = '';
  @State usageText: string = '还没查询用量';

  aboutToAppear(): void {
    const url = AppStorage.get<string>('relayUrl');
    const token = AppStorage.get<string>('relayToken');
    this.relayUrl = url === undefined ? '' : url;
    this.relayToken = token === undefined ? '' : token;
  }

  save(): void {
    const data = new SettingsData();
    data.relayUrl = this.relayUrl;
    data.relayToken = this.relayToken;
    Settings.save(getContext(), data).then(() => {
      toast('已保存');
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  loadUsage(): void {
    RelayClient.shared().usage().then((info: UsageInfo) => {
      this.usageText = '请求 ' + info.requests.toString() + ' 次，共 ' + info.totalTokens.toString() + ' tokens';
    }).catch((err: Object) => {
      this.usageText = errorText(err);
    });
  }

  build() {
    Scroll() {
      Column() {
        Text('我的')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink)
          .width('100%')
        Text('AI 文本走你自己的中转服务，用量记在 Cursor 的 Auto 池。Key 只放在服务端。')
          .fontSize(14)
          .fontColor(Theme.muted)
          .width('100%')
          .margin({ top: 8, bottom: 16 })
        Text('中转地址').fontColor(Theme.muted).width('100%')
        TextInput({ text: this.relayUrl, placeholder: 'http://192.168.1.10:8787' })
          .margin({ top: 6, bottom: 12 })
          .onChange((value: string) => {
            this.relayUrl = value;
          })
        Text('访问 Token').fontColor(Theme.muted).width('100%')
        TextInput({ text: this.relayToken, placeholder: 'RELAY_TOKEN' })
          .type(InputType.Password)
          .margin({ top: 6, bottom: 16 })
          .onChange((value: string) => {
            this.relayToken = value;
          })
        Button('保存')
          .width('100%')
          .backgroundColor(Theme.accent)
          .onClick(() => {
            this.save();
          })
        Button('查看 Auto 用量')
          .width('100%')
          .margin({ top: 10 })
          .backgroundColor(Theme.ink)
          .onClick(() => {
            this.loadUsage();
          })
        Text(this.usageText)
          .width('100%')
          .fontColor(Theme.ink)
          .margin({ top: 12 })
        Text('本应用是 GPL-3.0 项目的派生作品。课程内容来自「一千小时」美式发音教程。')
          .fontSize(13)
          .fontColor(Theme.muted)
          .width('100%')
          .margin({ top: 28 })
      }
      .width('100%')
      .padding(20)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
    .align(Alignment.TopStart)
  }
}
