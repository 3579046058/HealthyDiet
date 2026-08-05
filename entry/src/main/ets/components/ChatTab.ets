import { ThemeColors } from '../common/Constants';
import { ChatMessage, ChatRole } from '../model/ChatModels';
import { ChatController, ChatViewModel } from '../controller/ChatController';

@ComponentV2
export struct ChatTab {
  @Param activeTheme: string = 'dark';
  @Local vm: ChatViewModel = new ChatViewModel();
  private controller: ChatController = new ChatController(this.vm);
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.controller.init(this.getUIContext().getHostContext());
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

  private newSession(): void {
    this.controller.newSession();
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
        Text(msg.isThinking && msg.content.length === 0 ? '正在思考…' : msg.content)
          .fontSize(15)
          .fontColor(this.txt())
          .backgroundColor(msg.isError ? '#FF572222' : this.card())
          .borderRadius(14)
          .padding({ left: 14, right: 14, top: 10, bottom: 10 })
          .constraintSize({ maxWidth: '82%' })
        Blank()
      }
      .width('100%')
    }
  }

  build() {
    Column() {
      Row() {
        Text('🤖').fontSize(22)
        Text('AI问答').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 8 })
        Blank()
        Button('+ 新会话')
          .fontSize(12)
          .fontColor(this.txt())
          .backgroundColor(this.card())
          .height(32)
          .padding({ left: 12, right: 12 })
          .onClick(() => { this.newSession(); })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 10 })

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

        Button(this.vm.isLoading ? '停止' : '发送')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor(this.vm.isLoading ? '#666666' : '#9C27B0')
          .width(72)
          .height(44)
          .borderRadius(22)
          .margin({ left: 10 })
          .onClick(() => {
            if (this.vm.isLoading) {
              this.stop();
            } else {
              this.send();
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }
}
