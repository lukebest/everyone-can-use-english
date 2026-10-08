import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { errorText, toast } from '../common/Ui';
import { ChatDao, ConversationItem } from '../data/Db';
import { AGENTS, AgentPreset, findAgent } from '../models/Agents';

class ChatRoute {
  conversationId: number = 0;
  agentKey: string = '';
}

@Component
export struct ChatTab {
  @State items: ConversationItem[] = [];
  @State picking: boolean = false;

  aboutToAppear(): void {
    this.reload();
  }

  onPageShow(): void {
    this.reload();
  }

  reload(): void {
    ChatDao.list().then((items: ConversationItem[]) => {
      this.items = items;
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  startChat(agent: AgentPreset): void {
    ChatDao.create(agent.key, agent.name).then((id: number) => {
      this.picking = false;
      this.open(id, agent.key);
    }).catch((err: Object) => {
      toast(errorText(err));
    });
  }

  open(id: number, agentKey: string): void {
    const params = new ChatRoute();
    params.conversationId = id;
    params.agentKey = agentKey;
    const options: router.RouterOptions = {
      url: 'pages/ChatPage',
      params: params
    };
    router.pushUrl(options);
  }

  remove(item: ConversationItem): void {
    ChatDao.remove(item.id).then(() => {
      this.reload();
    });
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('对话')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
            .layoutWeight(1)
          Button('新对话')
            .height(36)
            .fontSize(14)
            .backgroundColor(Theme.accent)
            .onClick(() => {
              this.picking = true;
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 16, bottom: 8 })

        if (this.items.length === 0) {
          Text('选一个角色，用英语把想说的话练出来。')
            .fontColor(Theme.muted)
            .padding({ left: 20, right: 20, top: 8 })
        }

        List() {
          ForEach(this.items, (item: ConversationItem) => {
            ListItem() {
              Row() {
                Column() {
                  Text(item.title)
                    .fontSize(16)
                    .fontColor(Theme.ink)
                  Text(findAgent(item.agentKey).name)
                    .fontSize(12)
                    .fontColor(Theme.muted)
                    .margin({ top: 4 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .onClick(() => {
                  this.open(item.id, item.agentKey);
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
          }, (item: ConversationItem) => item.id.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Theme.bg)

      if (this.picking) {
        Column() {
          Column()
            .layoutWeight(1)
            .width('100%')
            .onClick(() => {
              this.picking = false;
            })
          Column() {
            Text('选一个角色')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
              .width('100%')
              .margin({ bottom: 8 })
            List() {
              ForEach(AGENTS, (agent: AgentPreset) => {
                ListItem() {
                  Column() {
                    Text(agent.name).fontSize(16).fontColor(Theme.ink).width('100%')
                    Text(agent.description).fontSize(13).fontColor(Theme.muted).width('100%').margin({ top: 4 })
                  }
                  .width('100%')
                  .alignItems(HorizontalAlign.Start)
                  .padding({ top: 12, bottom: 12 })
                  .onClick(() => {
                    this.startChat(agent);
                  })
                }
              }, (agent: AgentPreset) => agent.key)
            }
            .layoutWeight(1)
            .width('100%')
          }
          .width('100%')
          .height('70%')
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
