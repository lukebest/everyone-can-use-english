import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { LookupSheet } from '../components/LookupSheet';
import { VocabCard, VocabDao } from '../data/Db';
import { reviewCard } from '../services/Srs';
import { tts } from '../services/Tts';

@Component
export struct VocabTab {
  @State cards: VocabCard[] = [];
  @State reviewing: boolean = false;
  @State index: number = 0;
  @State revealed: boolean = false;
  @State showLookup: boolean = false;

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    if (!this.reviewing) {
      this.reload();
    }
  }

  reload(): void {
    VocabDao.list().then((cards: VocabCard[]) => {
      this.cards = cards;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  startReview(): void {
    VocabDao.due(Date.now()).then((cards: VocabCard[]) => {
      if (cards.length === 0) {
        toast('今天没有要复习的');
        return;
      }
      this.cards = cards;
      this.index = 0;
      this.revealed = false;
      this.reviewing = true;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  grade(value: number): void {
    if (this.index >= this.cards.length) {
      return;
    }
    const card = this.cards[this.index];
    const next = reviewCard(card, value);
    VocabDao.updateSchedule(card.id, next.ease, next.reps, next.intervalDays, next.dueAt).then(() => {
      this.revealed = false;
      if (this.index + 1 >= this.cards.length) {
        this.reviewing = false;
        toast('这轮复习完了');
        this.reload();
        return;
      }
      this.index = this.index + 1;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  remove(card: VocabCard): void {
    VocabDao.remove(card.id).then(() => {
      this.reload();
    });
  }

  current(): VocabCard {
    if (this.index >= 0 && this.index < this.cards.length) {
      return this.cards[this.index];
    }
    return new VocabCard();
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('生词')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
            .layoutWeight(1)
          Button('查词')
            .height(36)
            .fontSize(14)
            .backgroundColor(Theme.accent)
            .margin({ right: 8 })
            .onClick(() => {
              this.showLookup = true;
            })
          Button(this.reviewing ? '退出' : '复习')
            .height(36)
            .fontSize(14)
            .backgroundColor(Theme.ink)
            .onClick(() => {
              if (this.reviewing) {
                this.reviewing = false;
                this.reload();
              } else {
                this.startReview();
              }
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 8 })

        if (this.reviewing) {
          Column() {
            Text(this.current().word)
              .fontSize(32)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            if (this.current().pronunciation.length > 0) {
              Text(this.current().pronunciation).fontSize(16).fontColor(Theme.accent).margin({ top: 8 })
            }
            Text('朗读')
              .fontColor(Theme.accent)
              .margin({ top: 8 })
              .onClick(() => {
                tts().speak(this.current().word);
              })
            if (this.revealed) {
              Text(this.current().definition).fontSize(16).fontColor(Theme.ink).margin({ top: 16 }).width('100%')
              Text(this.current().translation).fontSize(16).fontColor(Theme.ink).margin({ top: 8 }).width('100%')
              Row() {
                Button('忘了').backgroundColor(Theme.bad).layoutWeight(1).margin(4).onClick(() => { this.grade(0); })
                Button('记得').backgroundColor(Theme.accent).layoutWeight(1).margin(4).onClick(() => { this.grade(1); })
                Button('简单').backgroundColor(Theme.ok).layoutWeight(1).margin(4).onClick(() => { this.grade(2); })
              }
              .width('100%')
              .margin({ top: 20 })
            } else {
              Button('看释义')
                .margin({ top: 24 })
                .backgroundColor(Theme.accent)
                .onClick(() => {
                  this.revealed = true;
                })
            }
          }
          .width('100%')
          .padding(24)
          .alignItems(HorizontalAlign.Start)
        } else if (this.cards.length === 0) {
          Text('查到的词可以放进这里，按「忘了 / 记得 / 简单」间隔复习。')
            .fontColor(Theme.muted)
            .padding({ left: 20, right: 20, top: 12 })
        } else {
          List() {
            ForEach(this.cards, (card: VocabCard) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(card.word).fontSize(16).fontColor(Theme.ink)
                    Text(card.translation).fontSize(13).fontColor(Theme.muted).margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .onClick(() => {
                    tts().speak(card.word);
                  })
                  Text('删除')
                    .fontColor(Theme.bad)
                    .onClick(() => {
                      this.remove(card);
                    })
                }
                .width('100%')
                .padding({ left: 20, right: 20, top: 12, bottom: 12 })
              }
            }, (card: VocabCard) => card.id.toString())
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      if (this.showLookup) {
        LookupSheet({
          initialWord: '',
          context: '',
          onClose: (): void => {
            this.showLookup = false;
            this.reload();
          }
        })
      }
    }
    .width('100%')
    .height('100%')
  }
}
