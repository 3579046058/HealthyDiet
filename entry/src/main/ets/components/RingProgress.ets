/**
 * 活动圆环组件 - 类似 Apple 三环
 */
@Component
export struct RingProgress {
  @Prop progress: number = 0; // 0-100
  @Prop strokeColor: string = '#FF6B35';
  @Prop ringSize: number = 120;
  @Prop strokeWidth: number = 12;
  @Prop label: string = '';
  @Prop valueText: string = '';
  @Prop unit: string = '';

  build() {
    Column() {
      Stack() {
        // 背景圆环
        Circle()
          .width(this.ringSize)
          .height(this.ringSize)
          .fill('transparent')
          .stroke('#333333')
          .strokeWidth(this.strokeWidth)

        // 进度圆环 - 使用 Progress 组件
        Progress({ value: this.progress, total: 100, type: ProgressType.Ring })
          .width(this.ringSize)
          .height(this.ringSize)
          .color(this.strokeColor)
          .style({ strokeWidth: this.strokeWidth })

        // 中心文本
        Column() {
          Text(this.valueText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .lineHeight(28)
          if (this.unit) {
            Text(this.unit)
              .fontSize(12)
              .fontColor('#888888')
          }
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .width(this.ringSize)
        .height(this.ringSize)
      }
      .width(this.ringSize)
      .height(this.ringSize)

      if (this.label) {
        Text(this.label)
          .fontSize(13)
          .fontColor('#888888')
          .margin({ top: 6 })
      }
    }
  }
}
