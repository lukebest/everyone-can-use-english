import { router } from '@kit.ArkUI';
import { http } from '@kit.NetworkKit';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { ChatDao, MessageItem } from '../data/Db';
import { findAgent } from '../models/Agents';
import { LlmClient } from '../services/LlmClient';
import { ChatHandlers, ChatTurn, Suggestion } from '../services/Types';
import { tts } from '../services/Tts';

class ChatRoute {
  conversationId: number = 0;
  agentKey: string = '';
}

@Entry
@Component
struct ChatPage {
  @State conversationId: number = 0;
  @State agentKey: string = '';
  @State title: string = '';
  @State lines: MessageItem[] = [];
  @State draft: string = '';
  @State sending: boolean = false;
  @State suggestions: Suggestion[] = [];
  @State showSuggestions: boolean = false;
  private request: http.HttpRequest | null = null;
  private renamed: boolean = false;

  aboutToAppear(): void {
    const raw = router.getParams();
    if (raw === undefined) {
      return;
    }
    const params = raw as ChatRoute;
    this.conversationId = params.conversationId;
    this.agentKey = params.agentKey;
    this.title = findAgent(params.agentKey).name;
    ChatDao.messages(this.conversationId).then((items: MessageItem[]) => {
      this.lines = items;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  aboutToDisappear(): void {
    if (this.request !== null) {
      this.request.destroy();
      this.request = null;
    }
  }

  copyLines(): MessageItem[] {
    const next: MessageItem[] = [];
    for (let i = 0; i < this.lines.length; i++) {
      next.push(this.lines[i]);
    }
    return next;
  }

  appendDelta(text: string): void {
    if (this.lines.length === 0) {
      return;
    }
    const last = this.lines[this.lines.length - 1];
    last.content = last.content + text;
    this.lines = this.copyLines();
  }

  send(): void {
    const text = this.draft.trim();
    if (text.length === 0 || this.sending) {
      return;
    }
    this.draft = '';
    this.sending = true;
    const history: ChatTurn[] = [];
    for (let i = 0; i < this.lines.length; i++) {
      const turn = new ChatTurn();
      turn.role = this.lines[i].role;
      turn.content = this.lines[i].content;
      history.push(turn);
    }
    ChatDao.addMessage(this.conversationId, 'user', text).then((userId: number) => {
      const user = new MessageItem();
      user.id = userId;
      user.role = 'user';
      user.content = text;
      const next = this.copyLines();
      next.push(user);
      this.lines = next;
      if (!this.renamed) {
        this.renamed = true;
        const title = text.length > 18 ? text.substring(0, 18) : text;
        ChatDao.rename(this.conversationId, title);
        this.title = title;
      }
      return ChatDao.addMessage(this.conversationId, 'assistant', '');
    }).then((assistantId: number) => {
      const assistant = new MessageItem();
      assistant.id = assistantId;
      assistant.role = 'assistant';
      assistant.content = '';
      const next = this.copyLines();
      next.push(assistant);
      this.lines = next;
      const handlers = new ChatHandlers();
      handlers.onDelta = (delta: string): void => {
        this.appendDelta(delta);
      };
      handlers.onDone = (): void => {
        this.finish(assistantId);
      };
      handlers.onError = (message: string): void => {
        this.appendDelta(message);
        this.finish(assistantId);
      };
      this.request = LlmClient.shared().chat(findAgent(this.agentKey).prompt, history, text, handlers);
    }).catch((err: Object) => {
      this.sending = false;
      toast(errorText(err));
    });
  }

  finish(assistantId: number): void {
    this.sending = false;
    this.request = null;
    if (this.lines.length === 0) {
      return;
    }
    const last = this.lines[this.lines.length - 1];
    ChatDao.updateMessage(assistantId, last.content);
  }

  suggest(): void {
    let context = '';
    for (let i = 0; i < this.lines.length; i++) {
      const who = this.lines[i].role === 'user' ? 'User' : 'Assistant';
      context = context + who + ': ' + this.lines[i].content + '\n';
    }
    if (context.length === 0) {
      context = 'The conversation has just started. Suggest ways to greet the coach in English.';
    }
    LlmClient.shared().suggest(context).then((items: Suggestion[]) => {
      this.suggestions = items;
      this.showSuggestions = true;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
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

        List() {
          ForEach(this.lines, (line: MessageItem) => {
            ListItem() {
              Column() {
                Text(line.role === 'user' ? '我' : '教练')
                  .fontSize(12)
                  .fontColor(Theme.muted)
                  .width('100%')
                Text(line.content.length > 0 ? line.content : '…')
                  .fontSize(16)
                  .fontColor(Theme.ink)
                  .width('100%')
                  .margin({ top: 4 })
                if (line.role === 'assistant' && line.content.length > 0) {
                  Text('朗读')
                    .fontSize(13)
                    .fontColor(Theme.accent)
                    .margin({ top: 6 })
                    .onClick(() => {
                      tts().speak(line.content);
                    })
                }
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
              .backgroundColor(line.role === 'user' ? '#F8E6E1' : Theme.card)
              .borderRadius(12)
              .margin({ left: 16, right: 16, top: 8 })
            }
          }, (line: MessageItem) => line.id.toString())
        }
        .layoutWeight(1)
        .width('100%')

        Row() {
          TextInput({ text: this.draft, placeholder: '用中文或英文说' })
            .layoutWeight(1)
            .onChange((value: string) => {
              this.draft = value;
            })
          Text('建议')
            .fontColor(Theme.accent)
            .margin({ left: 8 })
            .onClick(() => {
              this.suggest();
            })
          Button('发送')
            .height(36)
            .margin({ left: 8 })
            .backgroundColor(Theme.accent)
            .enabled(!this.sending)
            .onClick(() => {
              this.send();
            })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(Theme.card)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      if (this.showSuggestions) {
        Column() {
          Column()
            .layoutWeight(1)
            .width('100%')
            .onClick(() => {
              this.showSuggestions = false;
            })
          Column() {
            Row() {
              Text('可以这么说')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
                .fontColor(Theme.ink)
              Text('关闭')
                .fontColor(Theme.accent)
                .onClick(() => {
                  this.showSuggestions = false;
                })
            }
            .width('100%')
            List() {
              ForEach(this.suggestions, (item: Suggestion) => {
                ListItem() {
                  Column() {
                    Text(item.text).fontSize(16).fontColor(Theme.ink).width('100%')
                    Text(item.explanation).fontSize(13).fontColor(Theme.muted).width('100%').margin({ top: 4 })
                    Row() {
                      Text('朗读')
                        .fontSize(13)
                        .fontColor(Theme.accent)
                        .margin({ right: 16 })
                        .onClick(() => {
                          tts().speak(item.text);
                        })
                      Text('填入')
                        .fontSize(13)
                        .fontColor(Theme.accent)
                        .onClick(() => {
                          this.draft = item.text;
                          this.showSuggestions = false;
                        })
                    }
                    .margin({ top: 6 })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding({ top: 12, bottom: 12 })
                }
              }, (item: Suggestion, index: number) => index.toString() + item.text)
            }
            .layoutWeight(1)
            .width('100%')
          }
          .width('100%')
          .height('60%')
          .padding(20)
          .backgroundColor(Theme.card)
          .borderRadius({ topLeft: 20, topRight: 20 })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
      }
    }
    .width('100%')
    .height('100%')
  }
}
