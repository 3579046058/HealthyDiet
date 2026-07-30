/**
 * 健康概览卡片组件
 */
@Component
export struct HealthCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  @Prop subText: string = '';
  @Prop iconColor: string = '#FF9800';
  @Prop iconSymbol: string = '';
  private onCardClick?: () => void;

  build() {
    Column() {
      Row() {
        // 图标区域
        Row() {
          Text(this.iconSymbol)
            .fontSize(20)
        }
        .width(40)
        .height(40)
        .borderRadius(10)
        .backgroundColor(this.iconColor + '22')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column() {
          Text(this.title)
            .fontSize(13)
            .fontColor('#888888')
          Text(this.value + ' ' + (this.unit || ''))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 2 })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
      }
      .padding(14)
      .width('100%')

      if (this.subText) {
        Text(this.subText)
          .fontSize(12)
          .fontColor('#666666')
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 10 })
      }
    }
    .width('100%')
    .backgroundColor('#1A1A2E')
    .borderRadius(14)
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick();
      }
    })
  }
}
