import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, GoalConfig } from '../common/Constants';
import { RingProgress } from '../components/RingProgress';
import { HealthCard } from '../components/HealthCard';

@Entry
@Component
struct Index {
  // 运动数据
  @State moveProgress: number = 65;
  @State exerciseProgress: number = 42;
  @State standProgress: number = 78;
  @State moveCal: number = 520;
  @State exerciseMin: number = 25;
  @State standHours: number = 9;

  // 健康卡片数据
  @State stepCount: number = 0;
  @State stepGoal: number = 8000;
  @State heartRate: number = 72;
  @State sleepScore: number = 82;
  @State sleepHours: string = '7.5';
  @State waterMl: number = 0;
  @State waterGoal: number = 2000;
  @State weightKg: string = '--';
  @State lastWeightUpdate: string = '';
  @State userName: string = '';
  @State greeting: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      this.stepGoal = goalConfig.dailySteps;
      this.waterGoal = goalConfig.dailyWaterMl;

      const summary = await GlobalData.db.getDailySummary(today);
      if (summary) {
        this.stepCount = Number(summary.steps) || 0;
        this.heartRate = Number(summary.heart_rate_avg) || 72;
        this.sleepScore = Number(summary.sleep_score) || 0;
        this.sleepHours = summary.sleep_hours ? Number(summary.sleep_hours).toFixed(1) : '0.0';
        this.waterMl = Number(summary.water_ml) || 0;
        this.moveCal = Number(summary.calories_burned) || 0;
        this.exerciseMin = Number(summary.exercise_minutes) || 0;
        this.standHours = Number(summary.stand_hours) || 0;
      }

      // 计算三环进度
      this.moveProgress = Math.min(100, (this.moveCal / 800) * 100);
      this.exerciseProgress = Math.min(100, (this.exerciseMin / 60) * 100);
      this.standProgress = Math.min(100, (this.standHours / 12) * 100);

      // 加载体重
      const weightRow = await GlobalData.db.getLatestWeight();
      if (weightRow) {
        this.weightKg = Number(weightRow.weight_kg).toFixed(1);
        this.lastWeightUpdate = String(weightRow.date);
      }

      // 问候语
      const hour = new Date().getHours();
      if (hour < 6) this.greeting = '夜深了';
      else if (hour < 9) this.greeting = '早上好';
      else if (hour < 12) this.greeting = '上午好';
      else if (hour < 14) this.greeting = '中午好';
      else if (hour < 18) this.greeting = '下午好';
      else this.greeting = '晚上好';
    } catch (err) {
      console.error('loadData error:', JSON.stringify(err));
    }
  }

  navigateTo(page: string): void {
    router.pushUrl({ url: page }).catch(() => {
      // TODO: Implement error handling.
    });
  }

  build() {
    Scroll() {
      Column() {
        // ===== 顶部问候 =====
        Row() {
          Column() {
            Text(this.greeting)
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
            Text('今天也要元气满满哦！')
              .fontSize(14)
              .fontColor('#888888')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 目标设置入口
          Image($r('app.media.startIcon'))
            .width(40)
            .height(40)
            .borderRadius(20)
            .onClick(() => { this.navigateTo(Constants.PAGE_GOAL); })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12 })

        // ===== 活动三环 =====
        Row() {
          RingProgress({
            progress: this.moveProgress,
            strokeColor: Constants.COLOR_MOVE,
            ringSize: 90,
            strokeWidth: 10,
            label: '活动',
            valueText: String(this.moveCal),
            unit: '千卡'
          })

          RingProgress({
            progress: this.exerciseProgress,
            strokeColor: Constants.COLOR_EXERCISE,
            ringSize: 90,
            strokeWidth: 10,
            label: '锻炼',
            valueText: String(this.exerciseMin),
            unit: '分钟'
          })

          RingProgress({
            progress: this.standProgress,
            strokeColor: Constants.COLOR_STAND,
            ringSize: 90,
            strokeWidth: 10,
            label: '站立',
            valueText: String(this.standHours),
            unit: '小时'
          })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .padding(16)
        .backgroundColor('#1A1A2E')
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })

        // ===== 今日概览网格 =====
        Text('今日概览')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 20, top: 20, bottom: 8 })

        Grid() {
          // 步数
          GridItem() {
            HealthCard({
              title: '步数',
              value: String(this.stepCount),
              unit: '/ ' + String(this.stepGoal),
              iconColor: Constants.COLOR_STEP,
              iconSymbol: '👟',
              subText: '完成 ' + String(this.stepGoal > 0 ? Math.round(this.stepCount / this.stepGoal * 100) : 0) + '%',
              onCardClick: () => {}
            })
          }

          // 心率
          GridItem() {
            HealthCard({
              title: '心率',
              value: String(this.heartRate),
              unit: 'bpm',
              iconColor: Constants.COLOR_HEART,
              iconSymbol: '❤️',
              subText: '静息心率',
              onCardClick: () => {}
            })
          }

          // 睡眠
          GridItem() {
            HealthCard({
              title: '睡眠',
              value: this.sleepHours,
              unit: '小时',
              iconColor: Constants.COLOR_SLEEP,
              iconSymbol: '😴',
              subText: '评分 ' + String(this.sleepScore),
              onCardClick: () => { this.navigateTo(Constants.PAGE_SLEEP); }
            })
          }

          // 喝水
          GridItem() {
            HealthCard({
              title: '喝水',
              value: String(this.waterMl),
              unit: 'ml',
              iconColor: Constants.COLOR_WATER,
              iconSymbol: '💧',
              subText: '目标 ' + String(this.waterGoal) + 'ml',
              onCardClick: () => { this.navigateTo(Constants.PAGE_WATER); }
            })
          }
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(12)
        .rowsGap(12)
        .padding({ left: 16, right: 16 })

        // ===== 快捷操作 =====
        Text('快捷功能')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .width('100%')
          .padding({ left: 20, top: 20, bottom: 8 })

        Row() {
          this.quickButton('🏃', '运动', Constants.PAGE_SPORT)
          this.quickButton('⚖️', '体重', Constants.PAGE_WEIGHT)
          this.quickButton('📊', '周报', Constants.PAGE_REPORT)
          this.quickButton('🎯', '目标', Constants.PAGE_GOAL)
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .padding({ left: 16, right: 16 })

        // 底部间距
        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
    .backgroundColor('#0D0D1A')
  }

  @Builder quickButton(icon: string, label: string, page: string) {
    Column() {
      Text(icon)
        .fontSize(28)
      Text(label)
        .fontSize(12)
        .fontColor('#AAAAAA')
        .margin({ top: 4 })
    }
    .width(70)
    .height(70)
    .backgroundColor('#1A1A2E')
    .borderRadius(35)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.navigateTo(page); })
  }
}
