/**
 * 数字滚动动画组件：targetValue 变化时从 0 平滑滚动到目标值
 * 用于健康页卡片数字、评分、三环数值的下拉刷新动画
 */
import { ThemeColors } from '../common/Constants';

@Component
export struct AnimatedNumber {
  @Prop targetValue: number = 0;
  @Prop fontSize: number = 22;
  @Prop color: string = '';
  @Prop fontWeight: FontWeight = FontWeight.Bold;
  @Prop maxLines: number = 1;
  @Prop ellipsis: TextOverflow = TextOverflow.Ellipsis;
  @Prop decimalPlaces: number = 0; // 小数位数（0=整数，1=1位小数）
  @Prop @Watch('onAnimKeyChange') animKey: number = 0; // 刷新触发标记：变化时强制从 0 重新动画
  @State displayValue: number = 0;
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.displayValue = 0;
    this.animateTo(this.targetValue);
  }

  // animKey 变化（下拉刷新完成）→ 无条件从 0 重播动画
  onAnimKeyChange(): void {
    this.displayValue = 0;
    this.animateTo(this.targetValue);
  }

  animateTo(target: number): void {
    const from: number = this.displayValue;
    const diff: number = target - from;
    if (diff === 0) {
      return;
    }
    const duration: number = Math.min(1200, Math.max(500, Math.abs(diff) * 6));
    const start: number = Date.now();
    const timer = setInterval(() => {
      const elapsed: number = Date.now() - start;
      const progress: number = Math.min(1, elapsed / duration);
      // easeOutCubic 缓动
      const eased: number = 1 - Math.pow(1 - progress, 3);
      this.displayValue = from + diff * eased;
      if (progress >= 1) {
        this.displayValue = target;
        clearInterval(timer);
      }
    }, 16);
  }

  build() {
    Text(this.formatValue())
      .fontSize(this.fontSize)
      .fontWeight(this.fontWeight)
      .fontColor(this.color.length > 0 ? this.color : ThemeColors.textPrimary(this.theme))
      .maxLines(this.maxLines)
      .textOverflow({ overflow: this.ellipsis })
  }

  formatValue(): string {
    const v: number = this.displayValue;
    if (this.decimalPlaces === 1) {
      return v.toFixed(1);
    }
    // 整数部分
    if (Math.abs(v - Math.round(v)) < 0.01) {
      return String(Math.round(v));
    }
    return v.toFixed(1);
  }
}
