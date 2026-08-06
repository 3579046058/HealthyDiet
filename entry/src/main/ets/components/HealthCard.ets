/**
 * 健康概览卡片组件
 */
import { ThemeColors } from '../common/Constants';
import { AnimatedNumber } from './AnimatedNumber';

@Component
export struct HealthCard {
  @Prop title: string = '';
  @Prop value: string = '';
  @Prop unit: string = '';
  @Prop subText: string = '';
  @Prop iconColor: string = '#FF9800';
  @Prop iconSymbol: string = '';
  @Prop iconName: string = ''; // 新增：SVG图标名称
  @Prop animValue: number = -1; // 动画数值：>=0 时用数字动画显示，-1 用字符串
  @Prop animKey: number = 0; // 刷新触发标记：变化时强制从 0 重新动画
  onCardClick?: () => void;
  @StorageLink('currentTheme') theme: string = 'dark';

  build() {
    Column() {
      Row() {
        // 图标区域
        Row() {
          if (this.iconName) {
            Image($r(`app.media.${this.iconName}`))
              .width(20)
              .height(20)
              .fillColor(this.iconColor)
          } else {
            Text(this.iconSymbol)
              .fontSize(20)
          }
        }
        .width(40)
        .height(40)
        .borderRadius(10)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Column() {
          Text(this.title)
            .fontSize(13)
            .fontColor(ThemeColors.textSecondary(this.theme))
          Row() {
            if (this.animValue >= 0) {
              AnimatedNumber({
                targetValue: this.animValue,
                fontSize: 22,
                color: ThemeColors.textPrimary(this.theme),
                animKey: this.animKey
              })
            } else {
              Text(this.value)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(ThemeColors.textPrimary(this.theme))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            if (this.unit) {
              Text(this.unit)
                .fontSize(11)
                .fontColor(ThemeColors.textSecondary(this.theme))
                .margin({ left: 4 })
                .maxLines(1)
            }
          }
          .margin({ top: 2 })
          .constraintSize({ maxWidth: '100%' })
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .padding(14)
      .width('100%')

      if (this.subText) {
        Text(this.subText)
          .fontSize(12)
          .fontColor(ThemeColors.textSecondary(this.theme))
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 10 })
      }
    }
    .width('100%')
    .backgroundColor(ThemeColors.cardBg(this.theme))
    .borderRadius(14)
    .onClick(() => {
      if (this.onCardClick) {
        this.onCardClick();
      }
    })
  }
}
