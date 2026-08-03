import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, GoalConfig, StreakData, DbRow, ThemeColors } from '../common/Constants';
import { RingProgress } from '../components/RingProgress';
import { HealthCard } from '../components/HealthCard';
import { FoodRecognitionTab } from '../components/FoodRecognitionTab';
import { ReminderScheduler } from '../services/ReminderScheduler';
import { NotificationService } from '../services/NotificationService';
import { WeightDialog } from '../components/WeightDialog';

@Entry
@Component
struct Index {
  @StorageLink('currentTheme') theme: string = 'dark';
  @State moveProgress: number = 0;
  @State exerciseProgress: number = 0;
  @State moodProgress: number = 0;
  @State moveCal: number = 0;
  @State exerciseMin: number = 0;
  @State moodValue: number = 0;

  @State stepCount: number = 0;
  @State stepGoal: number = 8000;
  @State heartRate: number = 0;
  @StorageLink('liveSteps') liveSteps: number = 0;
  @StorageLink('bandHeartRate') bandHeartRate: number = 0;
  @StorageLink('inAppAlarm') @Watch('onInAppAlarm') inAppAlarm: string = '';
  @State sleepScore: number = 0;
  @State sleepHours: string = '0';
  @State waterMl: number = 0;
  @State waterGoal: number = 2000;
  @State weightKg: string = '--';
  @State userName: string = '';
  @State greeting: string = '';
  @State streakCurrent: number = 0;
  @State streakBest: number = 0;
  @State currentTabIndex: number = 0;
  @State isLoggedIn: boolean = false;
  @State diaryDietRecords: DbRow[] = [];
  @State diarySportRecords: DbRow[] = [];
  @State diarySleepRecords: DbRow[] = [];
  @State diaryMoodRecords: DbRow[] = [];
  @State waterReminderEnabled: boolean = false;
  @State sedentaryReminderEnabled: boolean = false;
  @State waterReminderTime: string = '10:00';
  @State sedentaryReminderTime: string = '14:00';
  @State showWaterTimePicker: boolean = false;
  @State showSedentaryTimePicker: boolean = false;

  @State bgColor: string = '#121212';
  @State cardColor: string = '#1E1E2E';
  @State textColor: string = '#FFFFFF';
  @State subTextColor: string = '#AAAAAA';
  readonly accentColor: string = '#FF6B35';
  private weightDialogController: CustomDialogController | null = null;

  updateThemeColors(): void {
    this.bgColor = ThemeColors.bg(this.theme);
    this.cardColor = ThemeColors.card(this.theme);
    this.textColor = ThemeColors.text(this.theme);
    this.subTextColor = ThemeColors.subText(this.theme);
  }

  aboutToAppear(): void {
    this.loadAllData();
    this.startAutoRefresh();
    this.checkWeightPrompt();
  }

  aboutToDisappear(): void {
    this.stopAutoRefresh();
  }

  async checkWeightPrompt(): Promise<void> {
    try {
      const skip = await GlobalData.prefs.getWeightSkipPrompt();
      const configured = await GlobalData.prefs.isWeightConfigured();
      if (skip || configured) {
        return;
      }
      setTimeout(() => {
        this.weightDialogController = new CustomDialogController({
          builder: WeightDialog(),
          autoCancel: true,
          customStyle: true
        });
        this.weightDialogController.open();
      }, 600);
    } catch (err) {
      console.error('checkWeightPrompt error:', JSON.stringify(err));
    }
  }

  private refreshTimer: number = -1;

  startAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
    }
    this.refreshTimer = setInterval(() => {
      this.loadAllData();
    }, 10000);
  }

  stopAutoRefresh(): void {
    if (this.refreshTimer !== -1) {
      clearInterval(this.refreshTimer);
      this.refreshTimer = -1;
    }
  }

  async loadAllData(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const goalConfig: GoalConfig = await GlobalData.prefs.getGoalConfig();
      this.stepGoal = goalConfig.dailySteps;
      this.waterGoal = goalConfig.dailyWaterMl;

      const summary = await GlobalData.db.getDailySummary(today);
      if (summary) {
        this.stepCount = Number(summary.steps) || 0;
        this.heartRate = Number(summary.heart_rate_avg) || 0;
        this.sleepScore = Number(summary.sleep_score) || 0;
        this.sleepHours = summary.sleep_hours ? Number(summary.sleep_hours).toFixed(1) : '0';
        this.waterMl = Number(summary.water_ml) || 0;
        this.moveCal = Number(summary.calories_burned) || 0;
        this.exerciseMin = Number(summary.exercise_minutes) || 0;
      } else {
        this.stepCount = 0;
        this.heartRate = 0;
        this.sleepScore = 0;
        this.sleepHours = '0';
        this.waterMl = 0;
        this.moveCal = 0;
        this.exerciseMin = 0;
      }

      // 兜底：若 daily_summary 运动数据缺失，则从运动记录表实时汇总
      if (this.exerciseMin === 0) {
        const sportRows = await GlobalData.db.getSportRecords(today, today);
        let totalMin: number = 0;
        let totalCal: number = 0;
        for (const r of sportRows) {
          totalMin += Number(r.duration_min) || 0;
          totalCal += Number(r.calories) || 0;
        }
        if (totalMin > 0) {
          this.exerciseMin = totalMin;
          this.moveCal = Math.max(this.moveCal, totalCal);
        } else if (sportRows.length > 0) {
          this.exerciseMin = 1;
          this.moveCal = Math.max(this.moveCal, totalCal);
        }
      }

      this.moveProgress = Math.min(100, (this.moveCal / 800) * 100);
      this.exerciseProgress = Math.min(100, (this.exerciseMin / 60) * 100);

      // 加载今日心情（取当天最近一条心情记录，1-5）
      this.moodValue = await this.loadTodayMood();
      this.moodProgress = Math.min(100, (this.moodValue / 5) * 100);

      const weightRow = await GlobalData.db.getLatestWeight();
      if (weightRow) {
        this.weightKg = Number(weightRow.weight_kg).toFixed(1);
      }
      const hour = new Date().getHours();
      if (hour < 6) { this.greeting = '夜深了'; }
      else if (hour < 9) { this.greeting = '早上好'; }
      else if (hour < 12) { this.greeting = '上午好'; }
      else if (hour < 14) { this.greeting = '中午好'; }
      else if (hour < 18) { this.greeting = '下午好'; }
      else { this.greeting = '晚上好'; }

      const savedTheme: string = await GlobalData.prefs.getTheme();
      this.theme = savedTheme;
      AppStorage.setOrCreate('currentTheme', savedTheme);
      this.updateThemeColors();

      const streak: StreakData = await GlobalData.prefs.getStreakData();
      this.streakCurrent = streak.current;
      this.streakBest = streak.best;

      const loginRaw: string | number | boolean = await GlobalData.prefs.get('login_status', 'false');
      const loginStatus: string = String(loginRaw);
      this.isLoggedIn = loginStatus === 'true';
      const nameRaw: string | number | boolean = await GlobalData.prefs.get('user_name', '');
      this.userName = String(nameRaw);

      const waterRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_enabled', 'false');
      this.waterReminderEnabled = String(waterRaw) === 'true';
      const sedentaryRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_enabled', 'false');
      this.sedentaryReminderEnabled = String(sedentaryRaw) === 'true';
      const waterTimeRaw: string | number | boolean = await GlobalData.prefs.get('water_reminder_time', '10:00');
      this.waterReminderTime = String(waterTimeRaw);
      const sedentaryTimeRaw: string | number | boolean = await GlobalData.prefs.get('sedentary_reminder_time', '14:00');
      this.sedentaryReminderTime = String(sedentaryTimeRaw);

      const end = new Date();
      const start = new Date(end.getTime() - 7 * 24 * 60 * 60 * 1000);
      this.diaryDietRecords = await GlobalData.db.getDietRecordsRange(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.diarySportRecords = await GlobalData.db.getSportRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.diarySleepRecords = await GlobalData.db.getSleepRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.diaryMoodRecords = await GlobalData.db.getMoodRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
    } catch (err) {
      console.error('loadData error:', JSON.stringify(err));
    }
  }

  toggleTheme(): void {
    this.theme = this.theme === 'dark' ? 'light' : 'dark';
    AppStorage.setOrCreate('currentTheme', this.theme);
    this.updateThemeColors();
    GlobalData.prefs.setTheme(this.theme);
  }

  navigateTo(page: string): void {
    try {
      router.pushUrl({ url: page }).then(() => {
        console.info('Navigate to ' + page + ' succeeded');
      }).catch((err: Error) => {
        console.error('Navigate to ' + page + ' failed: ' + JSON.stringify(err));
      });
    } catch (e) {
      console.error('Navigate exception: ' + JSON.stringify(e));
    }
  }

  getMoodEmoji(moodVal: number): string {
    if (moodVal >= 4.5) { return '😄'; }
    if (moodVal >= 3.5) { return '🙂'; }
    if (moodVal >= 2.5) { return '😐'; }
    if (moodVal >= 1.5) { return '😔'; }
    return '😢';
  }

  getDisplaySteps(): number {
    if (this.liveSteps > 0) {
      return this.liveSteps;
    }
    return this.stepCount;
  }

  getHealthScore(): number {
    let score: number = 0;
    if (this.stepCount > 0) {
      score += Math.min(30, Math.round(this.stepCount / (this.stepGoal || 8000) * 30));
    }
    if (this.sleepScore > 0) {
      score += Math.min(25, Math.round(this.sleepScore * 0.3));
    }
    if (this.waterMl > 0) {
      score += Math.min(25, Math.round(this.waterMl / (this.waterGoal || 2000) * 25));
    }
    if (this.exerciseMin > 0) {
      score += Math.min(20, Math.round(this.exerciseMin / 60 * 20));
    }
    return Math.round(score);
  }

  getScoreColor(score: number): string {
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

  async loadTodayMood(): Promise<number> {
    try {
      const today = await GlobalData.getTodayDate();
      const rows = await GlobalData.db.getMoodRecords(today, today);
      if (rows.length === 0) {
        return 0;
      }
      const last = rows[rows.length - 1];
      const val: number = Number(last.mood) || 0;
      return val > 0 && val <= 5 ? val : 0;
    } catch (err) {
      console.error('Index loadTodayMood error:', JSON.stringify(err));
      return 0;
    }
  }

  parseReminderTime(timeStr: string): Date {
    const parts: string[] = timeStr.split(':');
    const h: number = parseInt(parts[0]) || 10;
    const m: number = parseInt(parts[1]) || 0;
    const d: Date = new Date();
    d.setHours(h, m, 0, 0);
    return d;
  }

  formatReminderTime(value: TimePickerResult): string {
    const h: number = value.hour;
    const m: number = value.minute;
    const hStr: string = h < 10 ? '0' + h : '' + h;
    const mStr: string = m < 10 ? '0' + m : '' + m;
    return hStr + ':' + mStr;
  }

  onPageShow(): void {
    this.loadAllData();
  }

  onInAppAlarm(propName: string): void {
    if (this.inAppAlarm.length > 0) {
      AlertDialog.show({
        title: '⏰ 健康闹铃',
        message: this.inAppAlarm,
        primaryButton: {
          value: '知道了',
          action: () => {
            AppStorage.setOrCreate('inAppAlarm', '');
          }
        },
        autoCancel: true,
        cancel: () => {
          AppStorage.setOrCreate('inAppAlarm', '');
        }
      });
    }
  }

  build() {
    Column() {
      Tabs({ barPosition: BarPosition.End, index: this.currentTabIndex }) {
        TabContent() { this.healthTab() }
        .tabBar(this.tabBuilder('🏥', '健康', 0))

        TabContent() { this.diaryTab() }
        .tabBar(this.tabBuilder('📓', '日记', 1))

        TabContent() { this.recognitionTab() }
        .tabBar(this.tabBuilder('📷', '识图', 2))

        TabContent() { this.notificationTab() }
        .tabBar(this.tabBuilder('🔔', '通知', 3))

        TabContent() { this.accountTab() }
        .tabBar(this.tabBuilder('👤', '账号', 4))
      }
      .animationDuration(200)
      .barHeight(56)
      .barWidth('100%')
      .backgroundColor(this.bgColor)
      .onChange((index: number) => {
        this.currentTabIndex = index;
        if (index === 0) { this.loadAllData(); }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bgColor)
  }

  @Builder tabBuilder(icon: string, label: string, index: number) {
    Column() {
      Text(icon).fontSize(20)
      Text(label).fontSize(10).fontColor(this.currentTabIndex === index ? this.accentColor : this.subTextColor)
    }
    .width(56).height(48).justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder healthTab() {
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
              Text('🔥').fontSize(20)
              Text(String(this.streakCurrent) + '天').fontSize(11).fontColor('#FFD700')
            }
            .margin({ right: 12 })
          }
          Text(this.theme === 'dark' ? '☀️' : '🌙').fontSize(22).margin({ right: 12 })
            .onClick(() => { this.toggleTheme(); })
        }
        .width('100%').padding({ left: 20, right: 20, top: 12 })

        Row() {
          RingProgress({ progress: this.moveProgress, strokeColor: Constants.COLOR_MOVE, ringSize: 90, strokeWidth: 10, label: '活动', valueText: this.moveCal > 0 ? String(this.moveCal) : '--', unit: '千卡' })
          RingProgress({ progress: this.exerciseProgress, strokeColor: Constants.COLOR_EXERCISE, ringSize: 90, strokeWidth: 10, label: '锻炼', valueText: this.exerciseMin > 0 ? String(this.exerciseMin) : '--', unit: '分钟' })
          RingProgress({ progress: this.moodProgress, strokeColor: Constants.COLOR_MOOD, ringSize: 90, strokeWidth: 10, label: '心情', valueText: this.moodValue > 0 ? this.getMoodEmoji(this.moodValue) : '--', unit: this.moodValue > 0 ? '心情 ' + String(this.moodValue) : '暂无记录' })
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding(16)
        .backgroundColor(this.cardColor).borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })

        Text('今日概览').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').padding({ left: 20, top: 20, bottom: 8 })

        Grid() {
          GridItem() {
            HealthCard({ title: '步数', value: this.getDisplaySteps() > 0 ? String(this.getDisplaySteps()) : '--', unit: '/ ' + String(this.stepGoal), iconColor: Constants.COLOR_STEP, iconSymbol: '👟', subText: this.getDisplaySteps() > 0 ? '完成 ' + String(Math.round(this.getDisplaySteps() / this.stepGoal * 100)) + '%' : '暂无数据', onCardClick: () => { this.navigateTo(Constants.PAGE_SPORT); } })
          }
          GridItem() {
            HealthCard({ title: '心率', value: this.bandHeartRate > 0 ? String(this.bandHeartRate) : (this.heartRate > 0 ? String(this.heartRate) : '--'), unit: 'bpm', iconColor: Constants.COLOR_HEART, iconSymbol: '❤️', subText: this.bandHeartRate > 0 ? '手环实时心率' : '静息心率', onCardClick: () => { this.navigateTo(Constants.PAGE_DEVICE); } })
          }
          GridItem() {
            HealthCard({ title: '睡眠', value: this.sleepHours !== '0.0' && this.sleepHours !== '0' ? this.sleepHours : '--', unit: '小时', iconColor: Constants.COLOR_SLEEP, iconSymbol: '😴', subText: this.sleepScore > 0 ? '评分 ' + String(this.sleepScore) : '暂无数据', onCardClick: () => { this.navigateTo(Constants.PAGE_SLEEP); } })
          }
          GridItem() {
            HealthCard({ title: '喝水', value: this.waterMl > 0 ? String(this.waterMl) : '--', unit: 'ml', iconColor: Constants.COLOR_WATER, iconSymbol: '💧', subText: '目标 ' + String(this.waterGoal) + 'ml', onCardClick: () => { this.navigateTo(Constants.PAGE_WATER); } })
          }
        }
        .columnsTemplate('1fr 1fr').columnsGap(12).rowsGap(12).padding({ left: 16, right: 16 })

        Row() {
          Column() {
            Text('今日健康评分')
              .fontSize(14)
              .fontColor(this.subTextColor)
            Text(String(this.getHealthScore()))
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getScoreColor(this.getHealthScore()))
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column() {
            Row() {
              Text('步数').fontSize(12).fontColor(this.subTextColor)
              Blank()
              Text(this.stepCount > 0 ? String(this.stepCount) : '--').fontSize(13).fontColor(this.textColor)
            }
            Row() {
              Text('运动').fontSize(12).fontColor(this.subTextColor)
              Blank()
              Text(this.exerciseMin > 0 ? String(this.exerciseMin) + '分' : '--').fontSize(13).fontColor(this.textColor)
            }
            Row() {
              Text('睡眠').fontSize(12).fontColor(this.subTextColor)
              Blank()
              Text(this.sleepHours !== '0' && this.sleepHours !== '0.0' ? this.sleepHours + '时' : '--').fontSize(13).fontColor(this.textColor)
            }
          }
          .layoutWeight(1)
        }
        .width('100%')
        .padding(16)
        .backgroundColor(this.cardColor)
        .borderRadius(16)
        .margin({ left: 16, right: 16, top: 16 })

        Text('快捷功能').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').padding({ left: 20, top: 20, bottom: 8 })

        Row() {
          this.quickButton('🏃', '运动', Constants.PAGE_SPORT)
          this.quickButton('⚖️', '体重', Constants.PAGE_WEIGHT)
          this.quickButton('📊', '周报', Constants.PAGE_REPORT)
          this.quickButton('🎯', '目标', Constants.PAGE_GOAL)
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16 })

        Text('更多功能').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').padding({ left: 20, top: 20, bottom: 8 })

        Row() {
          this.quickButton('🍎', '饮食', Constants.PAGE_DIET)
          this.quickButton('🌸', '健康', Constants.PAGE_WOMEN)
          this.quickButton('💊', '用药', Constants.PAGE_MEDICATION)
          this.quickButton('😊', '情绪', Constants.PAGE_MOOD)
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16 })

        Row() {
          this.quickButton('🏋️', '成分', Constants.PAGE_BODY)
          this.quickButton('📋', '计划', Constants.PAGE_PLAN)
          this.quickButton('⌚', '设备', Constants.PAGE_DEVICE)
          this.quickButton('💤', '睡眠', Constants.PAGE_SLEEP)
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16, top: 12 })

        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
  }

  @Builder diaryTab() {
    Scroll() {
      Column() {
        Row() {
          Text('每日日记').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 12 })

        if (this.diaryDietRecords.length === 0 && this.diarySportRecords.length === 0 &&
          this.diarySleepRecords.length === 0 && this.diaryMoodRecords.length === 0) {
          Column() {
            Text('📝').fontSize(48).margin({ top: 40 })
            Text('暂无记录').fontSize(16).fontColor(this.subTextColor).margin({ top: 12 })
            Text('开始记录你的健康生活吧').fontSize(13).fontColor(this.subTextColor)
          }
          .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 60 })
        } else {
          if (this.diaryDietRecords.length > 0) {
            Text('🍎 饮食').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              .width('100%').padding({ left: 20, top: 12, bottom: 6 })
            ForEach(this.diaryDietRecords.slice(0, 5), (item: DbRow) => {
              Row() {
                Text(String(item.food_name)).fontSize(14).fontColor(this.textColor)
                Blank()
                Text(Number(item.calories) + ' kcal').fontSize(12).fontColor(this.subTextColor)
              }
              .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8).margin({ bottom: 4, left: 16, right: 16 })
            }, (item: DbRow): string => String(item.id))
          }

          if (this.diarySportRecords.length > 0) {
            Text('🏃 运动').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              .width('100%').padding({ left: 20, top: 12, bottom: 6 })
            ForEach(this.diarySportRecords.slice(0, 5), (item: DbRow) => {
              Row() {
                Text(String(item.sport_type)).fontSize(14).fontColor(this.textColor)
                Blank()
                Text(Number(item.duration_min) + 'min ' + Number(item.calories) + 'kcal').fontSize(12).fontColor(this.subTextColor)
              }
              .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8).margin({ bottom: 4, left: 16, right: 16 })
            }, (item: DbRow): string => String(item.id))
          }

          if (this.diarySleepRecords.length > 0) {
            Text('😴 睡眠').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              .width('100%').padding({ left: 20, top: 12, bottom: 6 })
            ForEach(this.diarySleepRecords.slice(0, 5), (item: DbRow) => {
              Row() {
                Column() {
                  Text(String(item.date)).fontSize(14).fontColor(this.textColor)
                  Text(Number(item.total_minutes)/60 + '时').fontSize(12).fontColor(this.subTextColor)
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text('评分 ' + Number(item.score)).fontSize(14).fontWeight(FontWeight.Bold).fontColor(Constants.COLOR_SLEEP)
              }
              .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8).margin({ bottom: 4, left: 16, right: 16 })
            }, (item: DbRow): string => String(item.id))
          }

          if (this.diaryMoodRecords.length > 0) {
            Text('😊 情绪').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              .width('100%').padding({ left: 20, top: 12, bottom: 6 })
            ForEach(this.diaryMoodRecords.slice(0, 5), (item: DbRow) => {
              Row() {
                Text(String(item.date)).fontSize(14).fontColor(this.textColor)
                Blank()
                Text(this.getMoodEmoji(Number(item.mood))).fontSize(20)
              }
              .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8).margin({ bottom: 4, left: 16, right: 16 })
            }, (item: DbRow): string => String(item.id))
          }
        }
        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
  }

  @Builder recognitionTab() {
    FoodRecognitionTab()
  }

  @Builder notificationTab() {
    Scroll() {
      Column() {
        Row() {
          Text('通知设置').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })

        this.notifCard('💧 喝水提醒', '每天 ' + this.waterReminderTime + ' 提醒喝水', this.waterReminderEnabled, (on: boolean) => {
          this.waterReminderEnabled = on;
          ReminderScheduler.getInstance().toggleWaterReminder(on);
        })
        Row() {
          Text('⏰ 设置时间').fontSize(14).fontColor(this.subTextColor).layoutWeight(1)
          Text(this.waterReminderTime)
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
          Text('✏️').fontSize(16).margin({ left: 8 })
            .onClick(() => { this.showWaterTimePicker = !this.showWaterTimePicker; })
        }
        .width('100%').padding({ left: 16, right: 16, bottom: 4 })

        if (this.showWaterTimePicker) {
          TimePicker({ selected: this.parseReminderTime(this.waterReminderTime) })
            .useMilitaryTime(true)
            .width(200).height(120)
            .onChange((value: TimePickerResult) => {
              this.waterReminderTime = this.formatReminderTime(value);
              ReminderScheduler.getInstance().setWaterTime(this.waterReminderTime);
            })
            .margin({ left: 16, bottom: 8 })
        }

        this.notifCard('🪑 久坐提醒', '每天 ' + this.sedentaryReminderTime + ' 提醒起身活动', this.sedentaryReminderEnabled, (on: boolean) => {
          this.sedentaryReminderEnabled = on;
          ReminderScheduler.getInstance().toggleSedentaryReminder(on);
        })
        Row() {
          Text('⏰ 设置时间').fontSize(14).fontColor(this.subTextColor).layoutWeight(1)
          Text(this.sedentaryReminderTime)
            .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            .onClick(() => { this.showSedentaryTimePicker = !this.showSedentaryTimePicker; })
          Text('✏️').fontSize(16).margin({ left: 8 })
            .onClick(() => { this.showSedentaryTimePicker = !this.showSedentaryTimePicker; })
        }
        .width('100%').padding({ left: 16, right: 16, bottom: 4 })

        if (this.showSedentaryTimePicker) {
          TimePicker({ selected: this.parseReminderTime(this.sedentaryReminderTime) })
            .useMilitaryTime(true)
            .width(200).height(120)
            .onChange((value: TimePickerResult) => {
              this.sedentaryReminderTime = this.formatReminderTime(value);
              ReminderScheduler.getInstance().setSedentaryTime(this.sedentaryReminderTime);
            })
            .margin({ left: 16, bottom: 8 })
        }

        this.notifCard('💊 用药提醒', '根据设定的时间提醒你服药', false, (on: boolean) => {
          console.info('Medication reminder toggle: ' + String(on));
        })

        Text('⏰ 闹钟功能需在用药页面添加用药计划后生效')
          .fontSize(12).fontColor(this.subTextColor)
          .padding({ left: 16, right: 16, top: 8 })

        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
  }

  @Builder notifCard(title: string, desc: string, enabled: boolean, onChange: (on: boolean) => void) {
    Row() {
      Column() {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.textColor)
        Text(desc).fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: enabled })
        .selectedColor(this.accentColor)
        .onChange((isOn: boolean) => { onChange(isOn); })
    }
    .width('100%').padding(16).backgroundColor(this.cardColor).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 10 })
  }

  @Builder accountTab() {
    Scroll() {
      Column() {
        Row() {
          Text('账号').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 16, bottom: 16 })

        Row() {
          Stack() {
            Circle().width(56).height(56).fill(this.isLoggedIn ? '#CF0A2C' : '#555555')
            if (this.isLoggedIn && this.userName.length > 0) {
              Text(this.userName.charAt(0)).fontSize(26).fontColor(Color.White)
            } else {
              Text('👤').fontSize(24)
            }
          }
          Column() {
            Text(this.isLoggedIn && this.userName.length > 0 ? this.userName : '未登录')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            Text(this.isLoggedIn ? 'HUAWEI 账号已绑定' : '登录后同步数据到云端')
              .fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 12 })
          Blank()
        }
        .width('100%').padding(16).backgroundColor(this.cardColor).borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 10 })
        .onClick(() => { this.navigateTo(Constants.PAGE_LOGIN); })

        this.accountMenuItem('⚖️', '体重设置', '设置体重，用于计算运动热量', () => {
          this.weightDialogController = new CustomDialogController({
            builder: WeightDialog(),
            autoCancel: true,
            customStyle: true
          });
          this.weightDialogController.open();
        })
        this.accountMenuItem('🎯', '目标设置', '步数、喝水、运动、睡眠目标', () => { this.navigateTo(Constants.PAGE_GOAL); })
        this.accountMenuItem('🎨', '主题切换', '深色模式 / 浅色模式', () => { this.toggleTheme(); })
        this.accountMenuItem('📊', '健康报告', '查看周报月报', () => { this.navigateTo(Constants.PAGE_REPORT); })
        this.accountMenuItem('ℹ️', '关于', 'Harmony健康 v1.0', () => {})
        this.accountMenuItem('💾', '数据说明', '数据存储在本地数据库，无需联网。关机会保留。', () => {})
        this.accountMenuItem('📡', '手环说明', '需连接真实BLE手环设备读取心率/血氧数据。', () => {})

        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
  }

  @Builder accountMenuItem(icon: string, title: string, desc: string, action: () => void) {
    Row() {
      Text(icon).fontSize(22)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
        Text(desc).fontSize(11).fontColor(this.subTextColor).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.subTextColor)
    }
    .width('100%').padding(14).backgroundColor(this.cardColor).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(() => { action(); })
  }

  @Builder quickButton(icon: string, label: string, page: string) {
    Column() {
      Text(icon).fontSize(28)
      Text(label).fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
    }
    .width(70).height(70)
    .backgroundColor(this.cardColor).borderRadius(35)
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .onClick(() => { this.navigateTo(page); })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
