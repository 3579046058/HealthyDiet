 /**
  * 喝水追踪组件
  */
 @Component
 export struct WaterTracker {
  @Prop currentMl: number = 0;
  @Prop goalMl: number = 2000;
  @Link @Watch('onCupAdded') cupMl: number;
  @State cups: number[] = [];
 
  private onAddCup?: () => void;
 
  aboutToAppear(): void {
    this.updateCups();
  }
 
  onCupAdded(): void {
    this.updateCups();
  }
 
  updateCups(): void {
    const totalCups = Math.floor(this.currentMl / this.cupMl);
    const maxCups = Math.ceil(this.goalMl / this.cupMl);
    this.cups = [];
    for (let i = 0; i < maxCups; i++) {
      this.cups.push(i < totalCups ? 1 : 0);
    }
  }
 
  build() {
    Column() {
      // 进度显示
      Row() {
        Text(String(Math.floor(this.currentMl)))
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
        Text(' / ' + String(this.goalMl) + ' ml')
          .fontSize(16)
          .fontColor('#888888')
          .margin({ top: 6 })
      }
 
      // 水杯图标列表
      Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
        ForEach(this.cups, (filled: number, index: number) => {
          Column() {
            Text(filled === 1 ? '🥤' : '🥛')
              .fontSize(28)
              .opacity(filled === 1 ? 1.0 : 0.3)
          }
          .width(44)
          .height(44)
          .margin(4)
        })
      }
      .width('100%')
      .margin({ top: 16, bottom: 16 })
 
      // 添加按钮
      Button() {
        Text('+ ' + String(this.cupMl) + 'ml')
          .fontSize(16)
          .fontColor('#FFFFFF')
      }
      .width(200)
      .height(48)
      .backgroundColor('#03A9F4')
      .borderRadius(24)
      .onClick(() => {
        if (this.onAddCup) {
          this.onAddCup();
        }
      })
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#1A1A2E')
    .borderRadius(16)
  }
 }
