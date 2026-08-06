/**
 * 嵌套圆环组件 - 类似 Apple Watch 三环嵌套样式
 */
import { ThemeColors } from '../common/Constants';

@Component
export struct NestedRings {
  @Prop stepProgress: number = 0; // 0-100（初始化/刷新用）
  @Prop sleepProgress: number = 0; // 0-100
  @Prop moodProgress: number = 0; // 0-100
  @Prop stepColor: string = '#FF9800';
  @Prop sleepColor: string = '#9C27B0';
  @Prop moodColor: string = '#FF6B35';
  @Prop stepValue: string = '--';
  @Prop sleepValue: string = '--';
  @Prop moodValue: string = '--';
  @Prop stepGoal: number = 8000;
  @StorageLink('liveSteps') @Watch('onLiveStepsChange') liveSteps: number = 0;
  @State animStep: number = 0;
  @State animSleep: number = 0;
  @State animMood: number = 0;
  private stepAnimTimer: number = -1;
  private lastStepProgress: number = -1; // 记录上次动画的步数进度，避免重复触发
  @Prop @Watch('onAnimKeyChange') animKey: number = 0; // 刷新触发标记：变化时强制从 0 重新动画
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.animStep = 0;
    this.animSleep = 0;
    this.animMood = 0;
    this.lastStepProgress = this.stepProgress;
    this.animateTo(this.stepProgress, this.sleepProgress, this.moodProgress);
  }

  // 步数实时更新（liveSteps 变化）→ 直接计算进度并平滑更新环
  private onLiveStepsChange(): void {
    const target: number = this.stepGoal > 0 ? Math.min(100, this.liveSteps / this.stepGoal * 100) : 0;
    if (this.lastStepProgress < 0) {
      this.lastStepProgress = target;
      return;
    }
    const diff: number = Math.abs(target - this.lastStepProgress);
    if (diff < 0.1) {
      return;
    }
    this.lastStepProgress = target;
    console.info('[NestedRings] liveSteps=' + String(this.liveSteps) + ' -> ' + String(target));
    this.animateStepOnly(target);
  }

  // animKey 变化（下拉刷新完成）→ 无条件从 0 重播动画
  onAnimKeyChange(): void {
    this.animStep = 0;
    this.animSleep = 0;
    this.animMood = 0;
    this.lastStepProgress = this.stepProgress;
    this.animateTo(this.stepProgress, this.sleepProgress, this.moodProgress);
  }

  // 仅动画步数环（实时步数更新用）
  animateStepOnly(targetStep: number): void {
    if (this.stepAnimTimer >= 0) {
      clearInterval(this.stepAnimTimer);
      this.stepAnimTimer = -1;
    }
    const fromStep: number = this.animStep;
    const duration: number = 500;
    const start: number = Date.now();
    this.stepAnimTimer = setInterval(() => {
      const elapsed: number = Date.now() - start;
      const progress: number = Math.min(1, elapsed / duration);
      const eased: number = 1 - Math.pow(1 - progress, 3);
      this.animStep = fromStep + (targetStep - fromStep) * eased;
      if (progress >= 1) {
        this.animStep = targetStep;
        clearInterval(this.stepAnimTimer);
        this.stepAnimTimer = -1;
      }
    }, 16);
  }

  animateTo(targetStep: number, targetSleep: number, targetMood: number): void {
    const fromStep: number = this.animStep;
    const fromSleep: number = this.animSleep;
    const fromMood: number = this.animMood;
    const duration: number = 1000;
    const start: number = Date.now();
    const timer = setInterval(() => {
      const elapsed: number = Date.now() - start;
      const progress: number = Math.min(1, elapsed / duration);
      const eased: number = 1 - Math.pow(1 - progress, 3);
      this.animStep = fromStep + (targetStep - fromStep) * eased;
      this.animSleep = fromSleep + (targetSleep - fromSleep) * eased;
      this.animMood = fromMood + (targetMood - fromMood) * eased;
      if (progress >= 1) {
        this.animStep = targetStep;
        this.animSleep = targetSleep;
        this.animMood = targetMood;
        clearInterval(timer);
      }
    }, 16);
  }

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
          Progress({ value: this.animStep, total: 100, type: ProgressType.Ring })
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
          Progress({ value: this.animSleep, total: 100, type: ProgressType.Ring })
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
          Progress({ value: this.animMood, total: 100, type: ProgressType.Ring })
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
