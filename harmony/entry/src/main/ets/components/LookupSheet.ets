import { LlmClient } from '../services/LlmClient';
import { LookupResult } from '../services/Types';
import { VocabDao } from '../data/Db';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';

@Component
export struct LookupSheet {
  @Prop initialWord: string = '';
  @Prop context: string = '';
  onClose: () => void = (): void => {};
  @State word: string = '';
  @State loading: boolean = false;
  @State searched: boolean = false;
  @State error: string = '';
  @State result: LookupResult = new LookupResult();

  aboutToAppear(): void {
    this.word = this.initialWord;
    if (this.word.length > 0) {
      this.search();
    }
  }

  search(): void {
    const query = this.word.trim();
    if (query.length === 0) {
      return;
    }
    this.loading = true;
    this.error = '';
    this.searched = true;
    LlmClient.shared().lookup(query, this.context).then((result: LookupResult) => {
      this.result = result;
      this.loading = false;
    }).catch((err: Object) => {
      this.error = errorText(err);
      this.loading = false;
    });
  }

  save(): void {
    if (this.result.word.length === 0) {
      return;
    }
    VocabDao.insert(this.result, this.context).then(() => {
      toast('已加入生词本');
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

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
          Text('查词')
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
        .margin({ bottom: 12 })

        TextInput({ text: this.word, placeholder: '单词或短语' })
          .onChange((value: string) => {
            this.word = value;
          })
        Button('查询')
          .width('100%')
          .margin({ top: 8, bottom: 12 })
          .backgroundColor(Theme.accent)
          .onClick(() => {
            this.search();
          })

        if (this.loading) {
          Text('正在查…').fontColor(Theme.muted)
        } else if (this.error.length > 0) {
          Text(this.error).fontColor(Theme.bad)
        } else if (this.searched) {
          Scroll() {
            Column() {
              Text(this.result.word + (this.result.pos.length > 0 ? '  ' + this.result.pos : ''))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
                .width('100%')
              if (this.result.pronunciation.length > 0) {
                Text(this.result.pronunciation).fontSize(16).fontColor(Theme.accent).width('100%').margin({ top: 4 })
              }
              if (this.result.lemma.length > 0) {
                Text('原形  ' + this.result.lemma).fontColor(Theme.muted).width('100%').margin({ top: 4 })
              }
              Text(this.result.definition).fontSize(16).fontColor(Theme.ink).width('100%').margin({ top: 12 })
              Text(this.result.translation).fontSize(16).fontColor(Theme.ink).width('100%').margin({ top: 8 })
              if (this.result.contextTranslation.length > 0) {
                Text(this.result.contextTranslation).fontSize(14).fontColor(Theme.muted).width('100%').margin({ top: 8 })
              }
              Button('加入生词本')
                .width('100%')
                .margin({ top: 16 })
                .backgroundColor(Theme.ok)
                .onClick(() => {
                  this.save();
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('78%')
      .padding(20)
      .backgroundColor(Theme.card)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }
}
