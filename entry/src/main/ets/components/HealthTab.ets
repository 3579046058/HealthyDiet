import { Constants } from '../common/Constants';
import { HealthScoreUtil } from '../services/HealthScoreUtil';
import { RingProgress } from './RingProgress';
import { HealthCard } from './HealthCard';
import { NestedRings } from './NestedRings';
import { AnimatedNumber } from './AnimatedNumber';
import { promptAction } from '@kit.ArkUI';

@Component
export struct HealthTab {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop accentColor: string = '#FF6B35';
  @Prop themeMode: string = 'follow';
  @Prop theme: string = 'dark';
  @Prop greeting: string = '';
  @Prop streakCurrent: number = 0;
  @Prop ringDisplayMode: boolean = false;
  @Prop stepCount: number = 0;
  @Prop stepGoal: number = 8000;
  @Prop sleepHours: string = '0';
  @Prop moodValue: number = 0;
  @Prop moodProgress: number = 0;
  @Prop sleepScore: number = 0;
  @Prop waterMl: number = 0;
  @Prop waterGoal: number = 2000;
  @Prop @Watch('onCalorieIntakeChange') todayCalorieIntake: number = 0;
  @Prop exerciseMin: number = 0;
  @Prop recommendCalorie: number = 2000;
  @StorageLink('liveSteps') liveSteps: number = 0;
  @Prop healthCardOrder: string[] = [];
  @Prop quickFunctionOrder: string[] = [];
  @State isRefreshing: boolean = false; // 下拉刷新状态
  @Prop @Watch('onRefreshKeyChange') refreshKey: number = 0; // 外部（Index）触发的刷新动画标记
  @State refreshAnimKey: number = 0; // 刷新完成触发标记：变化时所有数字/圆环从 0 重新动画

  // 监听 todayCalorieIntake 变化
  onCalorieIntakeChange(): void {
    console.info('[热量调试] HealthTab todayCalorieIntake 变化, 新值=' + String(this.todayCalorieIntake));
  }

  aboutToAppear(): void {
    console.info('[热量调试] HealthTab aboutToAppear, todayCalorieIntake=' + String(this.todayCalorieIntake));
  }

  // 外部 refreshKey 变化（Tab 切回/数据刷新完成）→ 触发动画重播
  onRefreshKeyChange(): void {
    this.refreshAnimKey++;
  }
  onToggleTheme: () => void = () => {};
  onToggleRingMode: () => void = () => {};
  onCardDrag: (from: number, to: number) => void = () => {};
  onFuncDrag: (from: number, to: number) => void = () => {};
  onNavigate: (page: string) => void = () => {};
  onRefreshData: () => Promise<void> = async () => {}; // 下拉刷新回调（重新加载数据）

  getMoodEmoji(moodVal: number): string {
    if (moodVal >= 4.5) { return '😄'; }
    if (moodVal >= 3.5) { return '🙂'; }
    if (moodVal >= 2.5) { return '😐'; }
    if (moodVal >= 1.5) { return '😔'; }
    return '😢';
  }

  getMoodLabel(mood: number): string {
    if (mood === 5) { return '很好'; }
    if (mood === 4) { return '不错'; }
    if (mood === 3) { return '一般'; }
    if (mood === 2) { return '不好'; }
    return '很差';
  }

  getThemeAccessibilityText(): string {
    if (this.themeMode === 'dark') { return '切换到浅色模式'; }
    if (this.themeMode === 'light') { return '切换到跟随系统模式'; }
    return '切换到深色模式';
  }

  getDisplaySteps(): number {
    if (this.liveSteps > 0) {
      return this.liveSteps;
    }
    return this.stepCount;
  }

  // 加权累加评分 + 短板加权（与应用/卡片统一算法）
  getHealthScore(): number {
    const currentSteps = this.liveSteps > 0 ? this.liveSteps : this.stepCount;
    return HealthScoreUtil.calcByData(
      currentSteps,
      this.stepGoal,
      this.sleepScore,
      this.waterMl,
      this.waterGoal,
      this.exerciseMin,
      this.todayCalorieIntake,
      this.recommendCalorie
    );
  }

  // 是否有有效评分数据（任一正项有记录）
  hasScoreData(): boolean {
    const currentSteps = this.liveSteps > 0 ? this.liveSteps : this.stepCount;
    return currentSteps > 0 || this.sleepScore > 0 || this.waterMl > 0 || this.exerciseMin > 0;
  }

  // 评分显示文本：无数据时 "--"
  getScoreDisplay(): string {
    return this.hasScoreData() ? String(this.getHealthScore()) : '--';
  }

  getScoreColor(score: number): string {
    // 负分：紫色
    if (score < 0) {
      return '#9C27B0';
    }
    if (score >= 80) {
      return '#4CAF50';
    }
    if (score >= 60) {
      return '#FF9800';
    }
    if (score >= 40) {
      return '#FFC107';
    }
    return '#F44336';
  }

  // 显示各项得分明细（各项得分相加 = 总分）
  getScoreDetails(): string {
    const currentSteps = this.liveSteps > 0 ? this.liveSteps : this.stepCount;
    const bd = HealthScoreUtil.calcBreakdown(
      currentSteps, this.stepGoal, this.sleepScore, this.waterMl, this.waterGoal,
      this.exerciseMin, this.todayCalorieIntake, this.recommendCalorie
    );
    const details: string[] = [];
    if (bd.stepScore > 0) {
      details.push(`步数${bd.stepScore}分`);
    }
    if (bd.sleepScoreOut > 0) {
      details.push(`睡眠${bd.sleepScoreOut}分`);
    }
    if (bd.waterScore > 0) {
      details.push(`喝水${bd.waterScore}分`);
    }
    if (bd.exerciseScore > 0) {
      details.push(`运动${bd.exerciseScore}分`);
    }
    if (bd.dietScore > 0) {
      details.push(`饮食${bd.dietScore}分`);
    } else if (bd.dietScore < 0) {
      details.push(`饮食${bd.dietScore}分⚠️`);
    }
    return details.length > 0 ? details.join(' ') : '';
  }

  // 根据评分给出鼓励语
  getScoreEncouragement(): string {
    if (!this.hasScoreData()) {
      return '还没有健康数据，快去记录吧！';
    }
    const score = this.getHealthScore();
    if (score >= 90) return '太棒了！继续保持！';
    if (score >= 80) return '做得很好！再接再厉！';
    if (score >= 70) return '不错哦！继续加油！';
    if (score >= 60) return '还可以，继续努力！';
    if (score >= 40) return '加油，你能做得更好！';
    return '别灰心，明天会更好！';
  }

  // 基于近期数据给出建议
  getRecentAdvice(): string {
    let advice: string[] = [];
    
    // 分析各项完成情况
    let lowestItem: string = '';
    let lowestRate: number = 100;
    
    // 检查步数
    const currentSteps = this.getDisplaySteps();
    if (currentSteps > 0) {
      const stepRate = currentSteps / (this.stepGoal || 8000) * 100;
      if (stepRate < lowestRate) {
        lowestRate = stepRate;
        lowestItem = '步数';
      }
    } else {
      advice.push('记得记录步数');
    }
    
    // 检查睡眠
    if (this.sleepScore > 0) {
      if (this.sleepScore < lowestRate) {
        lowestRate = this.sleepScore;
        lowestItem = '睡眠';
      }
    } else {
      advice.push('记得记录睡眠');
    }
    
    // 检查喝水
    if (this.waterMl > 0) {
      const waterRate = this.waterMl / (this.waterGoal || 2000) * 100;
      if (waterRate < lowestRate) {
        lowestRate = waterRate;
        lowestItem = '喝水';
      }
    } else {
      advice.push('记得记录喝水');
    }
    
    // 检查运动
    if (this.exerciseMin > 0) {
      const exerciseRate = this.exerciseMin / 60 * 100;
      if (exerciseRate < lowestRate) {
        lowestRate = exerciseRate;
        lowestItem = '运动';
      }
    } else {
      advice.push('记得记录运动');
    }
    
    // 如果有未记录的项目，提示记录
    if (advice.length > 0) {
      return advice.join('、') + '，让健康数据更完整';
    }
    
    // 如果所有项目都有数据，分析短板
    if (lowestItem && lowestRate < 70) {
      return `${lowestItem}是当前短板，建议重点关注`;
    }
    
    // 如果都做得不错
    const score = this.getHealthScore();
    if (score >= 80) {
      return '各项指标都很棒，继续保持这个节奏';
    } else if (score >= 60) {
      return '整体不错，再努力一点就能更好';
    } else {
      return '别气馁，每天进步一点点';
    }
  }

  build() {
    Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
      Column() {
        Row() {
          Column() {
            Text(this.greeting).fontSize(26).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            Text('今天也要元气满满哦！').fontSize(14).fontColor(this.subTextColor).margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          if (this.streakCurrent > 0) {
            Column() {
              Image($r('app.media.ic_fire_color'))
                .width(22).height(22)
                .supportSvg2(true)
              Text(String(this.streakCurrent) + '天').fontSize(11).fontColor('#E65100')
            }
            .margin({ right: 12 })
          }
          // 成就入口图标
          Image($r('app.media.ic_trophy_color'))
            .width(24).height(24)
            .supportSvg2(true)
            .margin({ right: 12 })
            .accessibilityText('查看成就')
            .accessibilityLevel('important')
            .onClick(() => { this.onNavigate('achievement'); })
          if (this.themeMode === 'dark') {
            Image($r('app.media.ic_theme_dark')).width(24).height(24).margin({ right: 12 }).supportSvg2(true)
              .accessibilityText(this.getThemeAccessibilityText())
              .accessibilityLevel('important')
              .onClick(() => {
                // 先计算下一个主题模式
                const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
                this.onToggleTheme();
                // 显示切换后的主题状态
                const label = next === 'dark' ? '深色模式' : (next === 'light' ? '浅色模式' : '跟随系统');
                promptAction.showToast({ message: '已切换到：' + label, duration: 1500 });
              })
          } else if (this.themeMode === 'light') {
            Image($r('app.media.ic_theme_light')).width(24).height(24).margin({ right: 12 }).supportSvg2(true)
              .accessibilityText(this.getThemeAccessibilityText())
              .accessibilityLevel('important')
              .onClick(() => {
                // 先计算下一个主题模式
                const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
                this.onToggleTheme();
                // 显示切换后的主题状态
                const label = next === 'dark' ? '深色模式' : (next === 'light' ? '浅色模式' : '跟随系统');
                promptAction.showToast({ message: '已切换到：' + label, duration: 1500 });
              })
          } else {
            Image($r('app.media.ic_theme_auto')).width(24).height(24).margin({ right: 12 }).supportSvg2(true)
              .accessibilityText(this.getThemeAccessibilityText())
              .accessibilityLevel('important')
              .onClick(() => {
                // 先计算下一个主题模式
                const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
                this.onToggleTheme();
                // 显示切换后的主题状态
                const label = next === 'dark' ? '深色模式' : (next === 'light' ? '浅色模式' : '跟随系统');
                promptAction.showToast({ message: '已切换到：' + label, duration: 1500 });
              })
          }
        }
        .width('100%').padding({ left: 20, right: 20, top: 12 + this.statusBarHeight })

        // 圆环切换区域
        Column() {
          // 切换按钮 - 右上角
          Row() {
            Button('切换样式')
              .fontSize(12)
              .fontColor(this.theme === 'dark' ? '#FFFFFF' : '#000000')
              .backgroundColor(this.theme === 'dark' ? '#333333' : '#E0E0E0')
              .borderRadius(8)
              .height(28)
              .padding({ left: 12, right: 12 })
              .onClick(() => {
                this.onToggleRingMode();
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.End)
          .padding({ left: 16, right: 16, top: 12 })

          // 圆环显示区域
          if (this.ringDisplayMode) {
            // 嵌套圆环模式
            Column() {
              NestedRings({
                stepProgress: (this.getDisplaySteps() / this.stepGoal) * 100,
                sleepProgress: (parseFloat(this.sleepHours) / Constants.DEFAULT_SLEEP_GOAL_HOURS) * 100,
                moodProgress: this.moodProgress,
                stepColor: Constants.COLOR_STEP,
                sleepColor: Constants.COLOR_SLEEP,
                moodColor: Constants.COLOR_MOOD,
                stepValue: this.getDisplaySteps() > 0 ? String(this.getDisplaySteps()) : '--',
                sleepValue: this.sleepHours !== '0' ? this.sleepHours : '--',
                moodValue: this.moodValue > 0 ? this.getMoodEmoji(this.moodValue) + ' 心情 ' + String(this.moodValue) : '暂无记录',
                animKey: this.refreshAnimKey
              })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 8, bottom: 16 })
          } else {
            // 三个独立圆环模式
            Row() {
              RingProgress({ progress: (this.getDisplaySteps() / this.stepGoal) * 100, strokeColor: Constants.COLOR_STEP, ringSize: 90, strokeWidth: 10, label: '步数', valueText: this.getDisplaySteps() > 0 ? String(this.getDisplaySteps()) : '--', unit: '步', animKey: this.refreshAnimKey })
              RingProgress({ progress: (parseFloat(this.sleepHours) / Constants.DEFAULT_SLEEP_GOAL_HOURS) * 100, strokeColor: Constants.COLOR_SLEEP, ringSize: 90, strokeWidth: 10, label: '睡眠', valueText: this.sleepHours !== '0' ? this.sleepHours : '--', unit: '小时', animKey: this.refreshAnimKey })
              RingProgress({ progress: this.moodProgress, strokeColor: Constants.COLOR_MOOD, ringSize: 90, strokeWidth: 10, label: '心情', valueText: this.moodValue > 0 ? this.getMoodEmoji(this.moodValue) : '--', unit: this.moodValue > 0 ? '心情 ' + String(this.moodValue) : '暂无记录', animKey: this.refreshAnimKey })
            }
            .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16, top: 8, bottom: 16 })
          }
        }
        .width('100%')
        .backgroundColor(this.cardColor).borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })

        Row() {
          Column() {
            Text('今日健康评分')
              .fontSize(14)
              .fontColor(this.subTextColor)
            Row() {
              Column() {
                if (this.hasScoreData()) {
                  AnimatedNumber({
                    targetValue: this.getHealthScore(),
                    fontSize: 28,
                    color: this.getScoreColor(this.getHealthScore()),
                    animKey: this.refreshAnimKey
                  })
                  .margin({ top: 4 })
                  Text('分')
                    .fontSize(16)
                    .fontColor(this.subTextColor)
                } else {
                  Text('--')
                    .fontSize(28)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.subTextColor)
                    .margin({ top: 4 })
                }

                if (this.getScoreDetails()) {
                  Text(this.getScoreDetails())
                    .fontSize(10)
                    .fontColor(this.subTextColor)
                    .margin({ top: 2 })
                }
              }
              .layoutWeight(2)
              .alignItems(HorizontalAlign.Start)

              Blank().layoutWeight(2)

              if (this.hasScoreData()) {
                Progress({ value: this.getHealthScore(), total: 100, type: ProgressType.Linear })
                  .layoutWeight(6)
                  .height(8)
                  .color(this.getScoreColor(this.getHealthScore()))
                  .backgroundColor(this.theme === 'dark' ? '#404040' : '#E0E0E0')
                  .margin({ top: 12 })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .onClick(() => { this.onNavigate(Constants.PAGE_REPORT); })
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.cardColor)
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })

        // 鼓励语卡片
        Column() {
          Text(this.getScoreEncouragement())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.hasScoreData() ? this.getScoreColor(this.getHealthScore()) : this.subTextColor)
            .margin({ bottom: 12 })

          if (this.getRecentAdvice()) {
            Text(this.getRecentAdvice())
              .fontSize(14)
              .fontColor(this.subTextColor)
              .textAlign(TextAlign.Center)
              .lineHeight(20)
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 20, bottom: 20 })
        .backgroundColor(this.cardColor)
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })
        .alignItems(HorizontalAlign.Center)

        Text('今日概览').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').padding({ left: 20, top: 20, bottom: 8 })

        Grid() {
          ForEach(this.healthCardOrder, (cardId: string, index: number) => {
            GridItem() {
              this.healthCardBuilder(cardId)
            }
          }, (cardId: string) => cardId)
        }
        .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).padding({ left: 16, right: 16 })
        .editMode(true)
        .supportAnimation(true)
        .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
          return this.dragCardBuilder(this.healthCardOrder[itemIndex]);
        })
        .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
          if (!isSuccess || insertIndex >= this.healthCardOrder.length || itemIndex === insertIndex) {
            return;
          }
          this.onCardDrag(itemIndex, insertIndex);
        })

        Text('快捷功能').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').padding({ left: 20, top: 20, bottom: 8 })

        Grid() {
          ForEach(this.quickFunctionOrder, (funcId: string, index: number) => {
            GridItem() {
              this.quickFunctionBuilder(funcId)
            }
          }, (funcId: string) => funcId)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr')
        .rowsGap(12)
        .columnsGap(12)
        .padding({ left: 16, right: 16 })
        .editMode(true)
        .supportAnimation(true)
        .onItemDragStart((event: ItemDragInfo, itemIndex: number) => {
          return this.dragQuickFunctionBuilder(this.quickFunctionOrder[itemIndex]);
        })
        .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => {
          if (!isSuccess || insertIndex >= this.quickFunctionOrder.length || itemIndex === insertIndex) {
            return;
          }
          this.onFuncDrag(itemIndex, insertIndex);
        })

        Divider().opacity(0).height(24)
      }
      .width('100%')
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme === 'dark' ? '#121212' : '#F5F5F5')
      .onRefreshing(() => {
        // 下拉刷新：重新加载数据（动画由 Index 的 refreshKey 触发）
        this.onRefreshData().then(() => {
          setTimeout(() => {
            this.isRefreshing = false;
          }, 600);
        }).catch(() => {
          this.isRefreshing = false;
        });
      })
  }

  @Builder
  healthCardBuilder(cardId: string) {
    if (cardId === 'steps') {
      HealthCard({
        title: '步数',
        value: this.getDisplaySteps() > 0 ? String(this.getDisplaySteps()) : '--',
        animValue: this.getDisplaySteps() > 0 ? this.getDisplaySteps() : -1,
        animKey: this.refreshAnimKey,
        unit: '/ ' + String(this.stepGoal),
        iconColor: Constants.COLOR_STEP,
        iconName: 'ic_steps',
        subText: this.getDisplaySteps() > 0 ? '完成 ' + String(Math.round(this.getDisplaySteps() / this.stepGoal * 100)) + '%' : '暂无数据',
        onCardClick: () => { this.onNavigate(Constants.PAGE_SPORT); }
      })
    } else if (cardId === 'calorie') {
      HealthCard({
        title: '热量',
        value: this.todayCalorieIntake > 0 ? String(this.todayCalorieIntake) : '--',
        animValue: this.todayCalorieIntake > 0 ? this.todayCalorieIntake : -1,
        animKey: this.refreshAnimKey,
        unit: 'kcal',
        iconColor: Constants.COLOR_DIET,
        iconName: 'ic_calorie',
        subText: '今日摄入',
        onCardClick: () => { this.onNavigate(Constants.PAGE_DIET); }
      })
    } else if (cardId === 'sleep') {
      HealthCard({
        title: '睡眠',
        value: this.sleepHours !== '0.0' && this.sleepHours !== '0' ? this.sleepHours : '--',
        animValue: this.sleepHours !== '0.0' && this.sleepHours !== '0' ? parseFloat(this.sleepHours) : -1,
        animKey: this.refreshAnimKey,
        unit: '小时',
        iconColor: Constants.COLOR_SLEEP,
        iconName: 'ic_sleep',
        subText: this.sleepScore > 0 ? '评分 ' + String(this.sleepScore) : '暂无数据',
        onCardClick: () => { this.onNavigate(Constants.PAGE_SLEEP); }
      })
    } else if (cardId === 'water') {
      HealthCard({
        title: '喝水',
        value: this.waterMl > 0 ? String(this.waterMl) : '--',
        animValue: this.waterMl > 0 ? this.waterMl : -1,
        animKey: this.refreshAnimKey,
        unit: 'ml',
        iconColor: Constants.COLOR_WATER,
        iconName: 'ic_water',
        subText: '目标 ' + String(this.waterGoal) + 'ml',
        onCardClick: () => { this.onNavigate(Constants.PAGE_WATER); }
      })
    }
  }

  // 拖拽时显示的卡片
  @Builder
  dragCardBuilder(cardId: string) {
    Column() {
      this.healthCardBuilder(cardId)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.cardColor)
    .borderRadius(16)
    .opacity(0.8)
  }

  @Builder
  quickFunctionBuilder(funcId: string) {
    if (funcId === 'sport') {
      Column() {
        Image($r('app.media.ic_sport'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('运动').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_SPORT); })
    } else if (funcId === 'weight') {
      Column() {
        Image($r('app.media.ic_weight'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('体重').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_WEIGHT); })
    } else if (funcId === 'report') {
      Column() {
        Image($r('app.media.ic_report'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('周报').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_REPORT); })
    } else if (funcId === 'goal') {
      Column() {
        Image($r('app.media.ic_goal'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('目标').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_GOAL); })
    } else if (funcId === 'diet') {
      Column() {
        Image($r('app.media.ic_diet'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('饮食').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_DIET); })
    } else if (funcId === 'women') {
      Column() {
        Image($r('app.media.ic_women'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('健康').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_WOMEN); })
    } else if (funcId === 'medication') {
      Column() {
        Image($r('app.media.ic_medication'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('用药').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_MEDICATION); })
    } else if (funcId === 'mood') {
      Column() {
        Image($r('app.media.ic_mood'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('情绪').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .onClick(() => { this.onNavigate(Constants.PAGE_MOOD); })
    }
  }

  // 拖拽时显示的快捷功能
  @Builder
  dragQuickFunctionBuilder(funcId: string) {
    if (funcId === 'sport') {
      Column() {
        Image($r('app.media.ic_sport'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('运动').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'weight') {
      Column() {
        Image($r('app.media.ic_weight'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('体重').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'report') {
      Column() {
        Image($r('app.media.ic_report'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('周报').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'goal') {
      Column() {
        Image($r('app.media.ic_goal'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('目标').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'diet') {
      Column() {
        Image($r('app.media.ic_diet'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('饮食').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'women') {
      Column() {
        Image($r('app.media.ic_women'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('健康').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'medication') {
      Column() {
        Image($r('app.media.ic_medication'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('用药').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    } else if (funcId === 'mood') {
      Column() {
        Image($r('app.media.ic_mood'))
          .width(28)
          .height(28)
          .fillColor(this.accentColor)
        Text('情绪').fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .width(70).height(70)
      .backgroundColor(this.cardColor).borderRadius(35)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .opacity(0.8)
    }
  }
}
