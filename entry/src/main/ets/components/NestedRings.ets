/**
 * 嵌套圆环组件 - 类似 Apple Watch 三环嵌套样式
 */
import { ThemeColors } from '../common/Constants';

@Component
export struct NestedRings {
  @Prop stepProgress: number = 0; // 0-100
  @Prop sleepProgress: number = 0; // 0-100
  @Prop moodProgress: number = 0; // 0-100
  @Prop stepColor: string = '#FF9800';
  @Prop sleepColor: string = '#9C27B0';
  @Prop moodColor: string = '#FF6B35';
  @Prop stepValue: string = '--';
  @Prop sleepValue: string = '--';
  @Prop moodValue: string = '--';
  @StorageLink('currentTheme') theme: string = 'dark';

  build() {
    Column() {
      Stack() {
        // 最外层圆环 - 步数
        Stack() {
          // 背景圆环
          Circle()
            .width(160)
            .height(160)
            .fill('transparent')
            .stroke(ThemeColors.divider(this.theme))
            .strokeWidth(12)

          // 进度圆环
          Progress({ value: this.stepProgress, total: 100, type: ProgressType.Ring })
            .width(160)
            .height(160)
            .color(this.stepColor)
            .style({ strokeWidth: 12 })
        }

        // 中间层圆环 - 睡眠
        Stack() {
          // 背景圆环
          Circle()
            .width(130)
            .height(130)
            .fill('transparent')
            .stroke(ThemeColors.divider(this.theme))
            .strokeWidth(12)

          // 进度圆环
          Progress({ value: this.sleepProgress, total: 100, type: ProgressType.Ring })
            .width(130)
            .height(130)
            .color(this.sleepColor)
            .style({ strokeWidth: 12 })
        }

        // 最内层圆环 - 心情
        Stack() {
          // 背景圆环
          Circle()
            .width(100)
            .height(100)
            .fill('transparent')
            .stroke(ThemeColors.divider(this.theme))
            .strokeWidth(12)

          // 进度圆环
          Progress({ value: this.moodProgress, total: 100, type: ProgressType.Ring })
            .width(100)
            .height(100)
            .color(this.moodColor)
            .style({ strokeWidth: 12 })
        }
      }
      .width(160)
      .height(160)

      // 图例说明
      Row() {
        Column() {
          Row() {
            Circle()
              .width(12)
              .height(12)
              .fill(this.stepColor)
            Text('步数')
              .fontSize(12)
              .fontColor(this.theme === 'dark' ? '#FFFFFF' : '#000000')
              .margin({ left: 4 })
          }
          Text(this.stepValue + ' 步')
            .fontSize(10)
            .fontColor(this.theme === 'dark' ? '#AAAAAA' : '#666666')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Row() {
            Circle()
              .width(12)
              .height(12)
              .fill(this.sleepColor)
            Text('睡眠')
              .fontSize(12)
              .fontColor(this.theme === 'dark' ? '#FFFFFF' : '#000000')
              .margin({ left: 4 })
          }
          Text(this.sleepValue + ' 小时')
            .fontSize(10)
            .fontColor(this.theme === 'dark' ? '#AAAAAA' : '#666666')
            .margin({ top: 2 })
        }
        .layoutWeight(1)

        Column() {
          Row() {
            Circle()
              .width(12)
              .height(12)
              .fill(this.moodColor)
            Text('心情')
              .fontSize(12)
              .fontColor(this.theme === 'dark' ? '#FFFFFF' : '#000000')
              .margin({ left: 4 })
          }
          Text(this.moodValue)
            .fontSize(10)
            .fontColor(this.theme === 'dark' ? '#AAAAAA' : '#666666')
            .margin({ top: 2 })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 16 })
    }
    .width('100%')
  }
}
