/**
 * 活动圆环组件 - 类似 Apple 三环
 */
import { ThemeColors } from '../common/Constants';

@Component
export struct RingProgress {
  @Prop @Watch('onProgressChange') progress: number = 0; // 0-100
  @Prop strokeColor: string = '#FF6B35';
  @Prop ringSize: number = 120;
  @Prop strokeWidth: number = 12;
  @Prop label: string = '';
  @Prop valueText: string = '';
  @Prop unit: string = '';
  @Prop @Watch('onAnimKeyChange') animKey: number = 0; // 刷新触发标记：变化时强制从 0 重新动画
  @State animProgress: number = 0;
  private animTimer: number = -1;
  private lastProgress: number = -1;
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.animProgress = 0;
    this.lastProgress = this.progress;
    this.animateTo(this.progress);
  }

  // progress 变化（如步数实时更新）→ 从当前值平滑过渡到新值
  onProgressChange(): void {
    const target: number = this.progress;
    if (this.lastProgress < 0) {
      this.lastProgress = target;
      return;
    }
    const diff: number = Math.abs(target - this.lastProgress);
    if (diff < 0.1) {
      return;
    }
    this.lastProgress = target;
    this.animateTo(target);
  }

  // animKey 变化（下拉刷新完成）→ 无条件从 0 重播动画
  onAnimKeyChange(): void {
    this.animProgress = 0;
    this.lastProgress = this.progress;
    this.animateTo(this.progress);
  }

  animateTo(target: number): void {
    if (this.animTimer >= 0) {
      clearInterval(this.animTimer);
      this.animTimer = -1;
    }
    const from: number = this.animProgress;
    const diff: number = target - from;
    if (Math.abs(diff) < 0.1) {
      this.animProgress = target;
      return;
    }
    const duration: number = 500;
    const start: number = Date.now();
    this.animTimer = setInterval(() => {
      const elapsed: number = Date.now() - start;
      const progress: number = Math.min(1, elapsed / duration);
      const eased: number = 1 - Math.pow(1 - progress, 3);
      this.animProgress = from + diff * eased;
      if (progress >= 1) {
        this.animProgress = target;
        clearInterval(this.animTimer);
        this.animTimer = -1;
      }
    }, 16);
  }

  build() {
    Column() {
      Stack() {
        // 背景圆环
        Circle()
          .width(this.ringSize)
          .height(this.ringSize)
          .fill('transparent')
          .stroke(ThemeColors.divider(this.theme))
          .strokeWidth(this.strokeWidth)

        // 进度圆环 - 使用 Progress 组件
        Progress({ value: this.animProgress, total: 100, type: ProgressType.Ring })
          .width(this.ringSize)
          .height(this.ringSize)
          .color(this.strokeColor)
          .style({ strokeWidth: this.strokeWidth })

        // 中心文本
        Column() {
          Text(this.valueText)
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeColors.textPrimary(this.theme))
            .lineHeight(28)
          if (this.unit) {
            Text(this.unit)
              .fontSize(12)
              .fontColor(ThemeColors.textSecondary(this.theme))
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
          .fontColor(ThemeColors.textSecondary(this.theme))
          .margin({ top: 6 })
      }
    }
  }
}
