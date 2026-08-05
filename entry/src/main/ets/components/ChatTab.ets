import { display } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { ChatMessage, ChatRole, ChatSession } from '../model/ChatModels';
import { ChatController, ChatViewModel } from '../controller/ChatController';

@ComponentV2
export struct ChatTab {
  @Param activeTheme: string = 'dark';
  @Local statusBarHeight: number = 47;
  @Local vm: ChatViewModel = new ChatViewModel();
  @Local scroller: Scroller = new Scroller();
  private controller: ChatController = new ChatController(this.vm);

  aboutToAppear(): void {
    const h: number | undefined = AppStorage.get<number>('statusBarHeight');
    if (h !== undefined) {
      this.statusBarHeight = h;
    }
    this.applyAdaptiveLayout();
    this.controller.init(this.getUIContext().getHostContext());
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 400);
  }

  private applyAdaptiveLayout(): void {
    try {
      const d: display.Display = display.getDefaultDisplaySync();
      const widthVp: number = d.width / d.densityPixels;
      this.vm.isWide = widthVp >= 600;
      this.vm.isExpanded = this.vm.isWide;
      this.vm.drawerOpen = false;
    } catch (err) {
      console.error('ChatTab applyAdaptiveLayout error:', JSON.stringify(err));
    }
  }

  bg(): string { return ThemeColors.pageBg(this.activeTheme); }
  card(): string { return ThemeColors.cardBg(this.activeTheme); }
  txt(): string { return ThemeColors.textPrimary(this.activeTheme); }
  sub(): string { return ThemeColors.textSecondary(this.activeTheme); }

  private send(): void {
    this.controller.send();
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  private stop(): void {
    this.controller.stop();
  }

  private openSession(id: string): void {
    this.controller.openSession(id);
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  private deleteSession(id: string): void {
    this.controller.deleteSession(id);
    setTimeout(() => {
      this.scroller.scrollEdge(Edge.Bottom);
    }, 100);
  }

  private formatTime(ts: number): string {
    if (ts <= 0) {
      return '';
    }
    const d: Date = new Date(ts);
    const m: string = String(d.getMonth() + 1).padStart(2, '0');
    const day: string = String(d.getDate()).padStart(2, '0');
    const h: string = String(d.getHours()).padStart(2, '0');
    const min: string = String(d.getMinutes()).padStart(2, '0');
    return m + '-' + day + ' ' + h + ':' + min;
  }

  @Builder
  bubble(msg: ChatMessage) {
    if (msg.role === ChatRole.USER) {
      Row() {
        Blank()
        Text(msg.content)
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor('#9C27B0')
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .constraintSize({ maxWidth: '78%' })
      }
      .width('100%')
    } else {
      Row() {
        Text(msg.isSearching ? '检索知识库中…' : (msg.isThinking && msg.content.length === 0 ? '正在思考…' : msg.content))
          .fontSize(15)
          .fontColor(msg.isSearching ? '#9C27B099' : this.txt())
          .backgroundColor(msg.isError ? '#FF572222' : this.card())
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .constraintSize({ maxWidth: '82%' })
        Blank()
      }
      .width('100%')
    }
  }

  @Builder
  sessionListContent() {
    if (this.vm.sessions.length === 0) {
      Column() {
        Text('暂无历史会话').fontSize(13).fontColor(this.sub())
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    } else {
      List({ space: 8 }) {
        ForEach(this.vm.sessionList, (s: ChatSession) => {
          ListItem() {
            Row() {
              Column() {
                Text(s.title.length > 0 ? s.title : '未命名会话')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(s.id === this.vm.currentSessionId ? Color.White : this.txt())
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.formatTime(s.updatedAt))
                  .fontSize(10)
                  .fontColor(s.id === this.vm.currentSessionId ? '#FFFFFFAA' : this.sub())
                  .margin({ top: 4 })
              }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            .padding({ left: 10, top: 8, bottom: 8 })
            .onClick(() => {
              this.openSession(s.id);
              this.vm.drawerOpen = false;
            })

            Text('×')
              .fontSize(16)
              .fontColor(s.id === this.vm.currentSessionId ? '#FFFFFFAA' : this.sub())
              .padding({ left: 6, right: 6 })
              .onClick(() => { this.deleteSession(s.id); })
            }
            .width('100%')
            .backgroundColor(s.id === this.vm.currentSessionId ? '#9C27B0' : this.card())
            .borderRadius(10)
          }
        }, (s: ChatSession): string => s.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .margin({ top: 10 })
    }
  }

  @Builder
  sessionDrawer() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => { this.vm.drawerOpen = false; })
        .transition(TransitionEffect.opacity(0).animation({ duration: 250, curve: Curve.EaseOut, delay: 100 }))

      Column() {
        Row() {
          Text('会话').fontSize(17).fontWeight(FontWeight.Bold).fontColor(this.txt())
          Blank()
          Text('✕')
            .fontSize(16)
            .fontColor(this.sub())
            .padding({ left: 8, right: 4 })
            .onClick(() => { this.vm.drawerOpen = false; })
        }
        .width('100%')

        Button('+ 新对话')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor('#9C27B0')
          .width('100%')
          .height(38)
          .borderRadius(10)
          .margin({ top: 10 })
          .onClick(() => {
            this.controller.newSession();
            this.vm.drawerOpen = false;
          })

        this.sessionListContent()
      }
      .width('100%')
      .height('55%')
      .backgroundColor(this.bg())
      .borderRadius({ topLeft: 20, topRight: 20 })
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .transition(TransitionEffect.translate({ y: 320 }).animation({ duration: 250, curve: Curve.EaseOut, delay: 100 }))
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Row() {
        if (this.vm.isExpanded) {
          Column() {
        Row() {
          Text('🤖').fontSize(18)
          Text('会话').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 6 })
          Blank()
        }
        .width('100%')
        .padding({ left: 12, top: 14 + this.statusBarHeight, bottom: 10 })

            Button('+ 新对话')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#9C27B0')
              .width('100%')
              .height(38)
              .borderRadius(10)
              .onClick(() => { this.controller.newSession(); })

            this.sessionListContent()

            Text('点击侧栏会话可切换')
              .fontSize(9)
              .fontColor(this.sub())
              .width('100%')
              .textAlign(TextAlign.Center)
              .padding({ bottom: 10 })
          }
          .width(170)
          .height('100%')
          .backgroundColor(this.card())
          .padding({ left: 10, right: 10 })
        }

        Column() {
        Row() {
          if (!this.vm.isWide) {
            Text('☰')
              .fontSize(18)
              .fontColor(this.txt())
              .padding(4)
              .onClick(() => { this.vm.drawerOpen = true; })
          }
          Text('AI问答').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: this.vm.isWide ? 0 : 6 })
            if (this.vm.currentSessionTitle.length > 0) {
              Text(this.vm.currentSessionTitle)
                .fontSize(11)
                .fontColor(this.sub())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .constraintSize({ maxWidth: 120 })
                .margin({ left: 10 })
            }
            Blank()
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14 + this.statusBarHeight, bottom: 10 })

          if (this.vm.messages.length === 0) {
            Column() {
              Text('🤖').fontSize(56)
              Text('健康助手已就绪').fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.txt()).margin({ top: 12 })
              Text('可以问我饮食、运动、睡眠、喝水等健康问题\n回答会结合你今天的真实健康记录').fontSize(13).fontColor(this.sub())
                .textAlign(TextAlign.Center).margin({ top: 8 })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          } else {
            List({ scroller: this.scroller, space: 12 }) {
              ForEach(this.vm.messages, (msg: ChatMessage) => {
                ListItem() {
                  this.bubble(msg)
                }
              }, (msg: ChatMessage): string => String(msg.id))
            }
            .width('100%')
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .padding({ left: 16, right: 16, top: 4 })
          }

          Row() {
            TextInput({ placeholder: '输入你的健康问题…', text: this.vm.inputContent })
              .layoutWeight(1)
              .height(44)
              .fontSize(15)
              .fontColor(this.txt())
              .placeholderColor(this.sub())
              .backgroundColor(this.card())
              .borderRadius(22)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => { this.vm.inputContent = value; })
              .onSubmit(() => { this.send(); })

          Button('发送')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .backgroundColor('#9C27B0')
            .width(64)
            .height(44)
            .borderRadius(22)
            .margin({ left: 10 })
            .enabled(!this.vm.isLoading)
            .opacity(this.vm.isLoading ? 0.4 : 1)
            .onClick(() => {
              if (!this.vm.isLoading) {
                this.send();
              }
            })

          if (this.vm.isLoading) {
            Button('停止')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#666666')
              .width(64)
              .height(44)
              .borderRadius(22)
              .margin({ left: 8 })
              .onClick(() => { this.stop(); })
          }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 12 })
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .height('100%')
        .backgroundColor(this.bg())
      }
      .width('100%')
      .height('100%')

      if (this.vm.drawerOpen) {
        this.sessionDrawer()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange(() => {
      this.applyAdaptiveLayout();
    })
  }
}
