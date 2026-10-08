import { Settings, SettingsData } from '../common/Settings';
import { getContext } from '../common/AppContext';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { LlmClient } from '../services/LlmClient';
import { UsageInfo } from '../services/Types';

@Component
export struct MineTab {
  @State activeProvider: string = 'glm';
  @State glmBaseUrl: string = 'https://open.bigmodel.cn/api/coding/paas/v4';
  @State glmApiKey: string = '';
  @State glmModel: string = 'glm-5.3';
  @State minimaxBaseUrl: string = 'https://api.minimaxi.com/v1';
  @State minimaxApiKey: string = '';
  @State minimaxModel: string = 'MiniMax-M2.7';
  @State speechUrl: string = '';
  @State speechToken: string = '';
  @State statusText: string = '还没测试连接';

  aboutToAppear(): void {
    this.activeProvider = stored('activeProvider', 'glm');
    this.glmBaseUrl = stored('glmBaseUrl', this.glmBaseUrl);
    this.glmApiKey = stored('glmApiKey', '');
    this.glmModel = stored('glmModel', this.glmModel);
    this.minimaxBaseUrl = stored('minimaxBaseUrl', this.minimaxBaseUrl);
    this.minimaxApiKey = stored('minimaxApiKey', '');
    this.minimaxModel = stored('minimaxModel', this.minimaxModel);
    this.speechUrl = stored('speechUrl', '');
    this.speechToken = stored('speechToken', '');
  }

  currentData(): SettingsData {
    const data = new SettingsData();
    data.activeProvider = this.activeProvider;
    data.glmBaseUrl = this.glmBaseUrl;
    data.glmApiKey = this.glmApiKey;
    data.glmModel = this.glmModel;
    data.minimaxBaseUrl = this.minimaxBaseUrl;
    data.minimaxApiKey = this.minimaxApiKey;
    data.minimaxModel = this.minimaxModel;
    data.speechUrl = this.speechUrl;
    data.speechToken = this.speechToken;
    return data;
  }

  save(): Promise<void> {
    return Settings.save(getContext(), this.currentData());
  }

  testConnection(): void {
    this.save().then(() => {
      this.statusText = '正在测试…';
      return LlmClient.shared().ping();
    }).then((text: string) => {
      this.statusText = '连接成功：' + text;
    }).catch((err: Object) => {
      this.statusText = errorText(err);
    });
  }

  loadUsage(): void {
    this.save().then(() => {
      return LlmClient.shared().usage();
    }).then((info: UsageInfo) => {
      const name = this.activeProvider === 'minimax' ? 'MiniMax' : 'GLM';
      this.statusText = name + ' 请求 ' + info.requests.toString() + ' 次，共 ' + info.totalTokens.toString() + ' tokens';
    }).catch((err: Object) => {
      this.statusText = errorText(err);
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
        Text('查词、翻译、分析和对话直接调用 GLM Coding Plan 或 MiniMax。Key 只保存在这台手机上。')
          .fontSize(14)
          .fontColor(Theme.muted)
          .width('100%')
          .margin({ top: 8, bottom: 16 })
        Text('当前使用').fontColor(Theme.muted).width('100%')
        Row() {
          Button('GLM')
            .layoutWeight(1)
            .backgroundColor(this.activeProvider === 'glm' ? Theme.accent : Theme.ink)
            .onClick(() => {
              this.activeProvider = 'glm';
            })
          Button('MiniMax')
            .layoutWeight(1)
            .margin({ left: 8 })
            .backgroundColor(this.activeProvider === 'minimax' ? Theme.accent : Theme.ink)
            .onClick(() => {
              this.activeProvider = 'minimax';
            })
        }
        .width('100%')
        .margin({ top: 6, bottom: 16 })

        Text('GLM Coding Plan').fontColor(Theme.ink).fontWeight(FontWeight.Medium).width('100%')
        TextInput({ text: this.glmBaseUrl, placeholder: 'https://open.bigmodel.cn/api/coding/paas/v4' })
          .margin({ top: 6 })
          .onChange((value: string) => {
            this.glmBaseUrl = value;
          })
        TextInput({ text: this.glmApiKey, placeholder: 'GLM API Key' })
          .type(InputType.Password)
          .margin({ top: 6 })
          .onChange((value: string) => {
            this.glmApiKey = value;
          })
        TextInput({ text: this.glmModel, placeholder: 'glm-5.3' })
          .margin({ top: 6, bottom: 16 })
          .onChange((value: string) => {
            this.glmModel = value;
          })

        Text('MiniMax').fontColor(Theme.ink).fontWeight(FontWeight.Medium).width('100%')
        TextInput({ text: this.minimaxBaseUrl, placeholder: 'https://api.minimaxi.com/v1' })
          .margin({ top: 6 })
          .onChange((value: string) => {
            this.minimaxBaseUrl = value;
          })
        TextInput({ text: this.minimaxApiKey, placeholder: 'MiniMax API Key' })
          .type(InputType.Password)
          .margin({ top: 6 })
          .onChange((value: string) => {
            this.minimaxApiKey = value;
          })
        TextInput({ text: this.minimaxModel, placeholder: 'MiniMax-M2.7' })
          .margin({ top: 6, bottom: 16 })
          .onChange((value: string) => {
            this.minimaxModel = value;
          })

        Button('保存')
          .width('100%')
          .backgroundColor(Theme.accent)
          .onClick(() => {
            this.save().then(() => {
              toast('已保存');
            }).catch((err: Object) => {
              toast(errorText(err));
            });
          })
        Button('测试连接')
          .width('100%')
          .margin({ top: 10 })
          .backgroundColor(Theme.ink)
          .onClick(() => {
            this.testConnection();
          })
        Button('查看用量')
          .width('100%')
          .margin({ top: 10 })
          .backgroundColor(Theme.ink)
          .onClick(() => {
            this.loadUsage();
          })
        Text(this.statusText)
          .width('100%')
          .fontColor(Theme.ink)
          .margin({ top: 12 })

        Text('语音中转（可选）')
          .fontColor(Theme.ink)
          .fontWeight(FontWeight.Medium)
          .width('100%')
          .margin({ top: 28 })
        Text('只有「自动分句」和「评分」需要。查词和对话不走这里。')
          .fontSize(13)
          .fontColor(Theme.muted)
          .width('100%')
          .margin({ top: 4, bottom: 8 })
        TextInput({ text: this.speechUrl, placeholder: 'http://192.168.1.10:8787' })
          .onChange((value: string) => {
            this.speechUrl = value;
          })
        TextInput({ text: this.speechToken, placeholder: 'RELAY_TOKEN' })
          .type(InputType.Password)
          .margin({ top: 6 })
          .onChange((value: string) => {
            this.speechToken = value;
          })

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

function stored(name: string, fallback: string): string {
  const value = AppStorage.get<string>(name);
  if (value === undefined || value.length === 0) {
    return fallback;
  }
  return value;
}
