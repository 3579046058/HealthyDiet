import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, SportTypeDef, ThemeColors } from '../common/Constants';
import { FoodRecognitionService } from '../services/FoodRecognitionService';
import { LocationTrackerService } from '../services/LocationTrackerService';

@Entry
@Component
struct SportPage {
  @State currentSport: string = 'walk';
  @State durationSec: number = 0;
  @State distanceKm: number = 0;
  @State isTracking: boolean = false;
  @State isPaused: boolean = false;
  @State timerId: number = -1;
  @State calorieBurn: number = 0;
  @State heartRateAvg: number = 0;
  @State records: DbRow[] = [];
  @State bodyWeight: number = 70;
  @State intensity: string = '中强度';
  @State showManualAdd: boolean = false;
  @State manualMin: string = '30';
  @State manualKm: string = '';
  @State manualSport: string = 'walk';
  @State isCalcCalories: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State useGps: boolean = false;
  @State gpsStatus: string = '';

  aboutToAppear(): void {
    this.loadWeight();
    this.loadHistory();
  }

  // 判断是否为 GPS 运动（有位移的运动）
  isGpsSport(): boolean {
    return Constants.GPS_SPORTS.has(this.currentSport);
  }

  // 判断是否为原地运动
  isStationarySport(): boolean {
    return Constants.STATIONARY_SPORTS.has(this.currentSport);
  }

  async loadWeight(): Promise<void> {
    try {
      const config = await GlobalData.prefs.getGoalConfig();
      if (config.weightKg > 0) {
        this.bodyWeight = config.weightKg;
      }
    } catch (err) {
      console.error('SportPage loadWeight error:', JSON.stringify(err));
    }
  }

  aboutToDisappear(): void {
    this.stopTracking();
  }

  async deleteRecord(id: number): Promise<void> {
    await GlobalData.db.deleteSportRecord(id);
    await this.recalcDailySportSummary();
    await this.loadHistory();
  }

  async recalcDailySportSummary(): Promise<void> {
    try {
      const today = await GlobalData.getTodayDate();
      const end = new Date();
      const start = new Date(end.getTime() - 1 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getSportRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      let totalMin: number = 0;
      let totalCal: number = 0;
      for (const r of rows) {
        if (String(r.date) === today) {
          totalMin += Number(r.duration_min) || 0;
          totalCal += Number(r.calories) || 0;
        }
      }
      await GlobalData.db.updateDailySummaryField(today, 'exercise_minutes', totalMin);
      await GlobalData.db.updateDailySummaryField(today, 'calories_burned', totalCal);
    } catch (err) {
      console.error('SportPage recalcDailySportSummary error:', JSON.stringify(err));
    }
  }

  async loadHistory(): Promise<void> {
    try {
      const end = new Date();
      const start = new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getSportRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.records = rows;
    } catch (err) {
      console.error('SportPage loadData error:', JSON.stringify(err));
    }
  }

  startTracking(): void {
    this.isTracking = true;
    this.isPaused = false;
    this.durationSec = 0;
    this.distanceKm = 0;
    this.calorieBurn = 0;
    const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
    const maxHr: number = Constants.MAX_HR;
    const restHr: number = Constants.REST_HR;
    this.heartRateAvg = Math.min(maxHr, restHr + Math.round(met * 8));
    if (this.isGpsSport()) {
      const tracker = LocationTrackerService.getInstance();
      tracker.reset();
      tracker.onDistanceChanged((distanceM: number) => {
        this.distanceKm = parseFloat((distanceM / 1000).toFixed(2));
      });
      tracker.start();
      this.useGps = true;
      this.gpsStatus = '正在定位...';
      setTimeout(() => {
        if (this.isTracking && this.useGps) {
          this.gpsStatus = tracker.getPointCount() > 0 ? 'GPS 定位中' : '未获取到定位，正在重试';
        }
      }, 5000);
    } else {
      this.useGps = false;
      this.gpsStatus = '';
    }
    this.startTimer();
  }

  pauseTracking(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.useGps) {
      LocationTrackerService.getInstance().pause();
    }
    this.isPaused = true;
  }

  resumeTracking(): void {
    if (this.isTracking && this.isPaused) {
      if (this.useGps) {
        LocationTrackerService.getInstance().resume();
      }
      this.isPaused = false;
      this.startTimer();
    }
  }

  private startTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
    }
    this.timerId = setInterval(() => {
      this.durationSec++;
      this.updateMetrics();
    }, 1000);
  }

  private updateMetrics(): void {
    if (this.isGpsSport()) {
      // GPS 运动（步行、跑步、骑行）：根据距离计算热量
      if (this.distanceKm === 0) {
        // GPS 失败或未启动，根据时间估算距离
        const spd = Constants.SPEED_KMH.get(this.currentSport) ?? 5;
        this.distanceKm = parseFloat(((this.durationSec / 3600) * spd).toFixed(2));
      }
      // 热量 = 体重 × 距离 × 每公斤每公里消耗系数
      const perKgKm: number = this.getPerKgKm();
      this.calorieBurn = Math.round(this.bodyWeight * this.distanceKm * perKgKm);
    } else if (this.isStationarySport()) {
      // 原地运动（游泳、瑜伽、力量训练）：根据体重、强度和时间计算热量
      const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
      const intensityMultiplier: number = Constants.INTENSITY_MULTIPLIERS.get(this.intensity) ?? 1.0;
      const hours: number = this.durationSec / 3600;
      // 热量 = MET × 强度系数 × 体重 × 时间
      this.calorieBurn = Math.round(met * intensityMultiplier * this.bodyWeight * hours);
    } else {
      // 其他运动：使用默认 MET 公式
      const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
      const hours: number = this.durationSec / 3600;
      this.calorieBurn = Math.round(met * this.bodyWeight * hours);
    }
  }

  // 每公斤体重每公里消耗千卡（依运动类型）
  private getPerKgKm(): number {
    if (this.currentSport === 'run') { return 1.04; }
    if (this.currentSport === 'cycle') { return 0.32; }
    if (this.currentSport === 'walk') { return 0.5; }
    return 0.5;
  }

  stopTracking(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.isTracking = false;
    this.isPaused = false;
    if (this.useGps) {
      LocationTrackerService.getInstance().stop();
      this.useGps = false;
      this.gpsStatus = '';
    }
  }

  adjustTime(deltaSec: number): void {
    let newVal: number = this.durationSec + deltaSec;
    if (newVal < 0) {
      newVal = 0;
    }
    this.durationSec = newVal;
    this.updateMetrics();
  }

  async saveSportRecord(): Promise<void> {
    if (this.durationSec < 60) {
      promptAction.showToast({ message: '运动时间太短，至少需要60秒' });
      return;
    }
    const minutes: number = Math.max(1, Math.round(this.durationSec / 60));
    let calories: number = this.calorieBurn;
    this.isCalcCalories = true;
    const cloud = await FoodRecognitionService.getInstance().calculateSportCalories(
      this.getSportLabel(this.currentSport), minutes, this.intensity, this.bodyWeight, this.distanceKm
    );
    this.isCalcCalories = false;
    if (cloud >= 0) {
      calories = cloud;
    }
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      sport_type: this.currentSport,
      duration_min: minutes,
      distance_km: this.distanceKm,
      calories: calories,
      avg_heart_rate: this.heartRateAvg,
    };
    await GlobalData.db.addSportRecord(record);
    await this.saveDailySummarySport(today, minutes, calories);
    this.stopTracking();
    await this.loadHistory();
    promptAction.showToast({ message: '运动记录已保存' });
  }

  async saveManualRecord(): Promise<void> {
    const minVal = parseFloat(this.manualMin);
    if (isNaN(minVal) || minVal <= 0) {
      promptAction.showToast({ message: '请输入有效的运动时长' });
      return;
    }
    const minutes: number = Math.round(minVal);
    let distKm: number = 0;
    const kmVal = parseFloat(this.manualKm);
    if (!isNaN(kmVal) && kmVal > 0) {
      distKm = kmVal;
    }
    // 本地兜底估算：根据运动类型选择不同的计算方法
    let calories: number = 0;
    const hours: number = minutes / 60;
    
    if (Constants.GPS_SPORTS.has(this.manualSport)) {
      // GPS 运动：根据距离计算热量
      if (distKm === 0) {
        // 没有输入距离，根据时间估算
        const spd = Constants.SPEED_KMH.get(this.manualSport) ?? 5;
        distKm = parseFloat((hours * spd).toFixed(2));
      }
      const perKgKm: number = this.getPerKgKmFor(this.manualSport);
      calories = Math.round(this.bodyWeight * distKm * perKgKm);
    } else if (Constants.STATIONARY_SPORTS.has(this.manualSport)) {
      // 原地运动：根据体重、强度和时间计算热量
      const met: number = Constants.MET_VALUES.get(this.manualSport) ?? 4.0;
      const intensityMultiplier: number = Constants.INTENSITY_MULTIPLIERS.get(this.intensity) ?? 1.0;
      calories = Math.round(met * intensityMultiplier * this.bodyWeight * hours);
    } else {
      // 其他运动：使用默认 MET 公式
      const met: number = Constants.MET_VALUES.get(this.manualSport) ?? 4.0;
      calories = Math.round(met * this.bodyWeight * hours);
    }
    this.isCalcCalories = true;
    const cloud = await FoodRecognitionService.getInstance().calculateSportCalories(
      this.getSportLabel(this.manualSport), minutes, this.intensity, this.bodyWeight, distKm
    );
    this.isCalcCalories = false;
    if (cloud >= 0) {
      calories = cloud;
    }
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      sport_type: this.manualSport,
      duration_min: minutes,
      distance_km: distKm,
      calories: calories,
      avg_heart_rate: this.heartRateAvg,
    };
    await GlobalData.db.addSportRecord(record);
    await this.saveDailySummarySport(today, minutes, calories);
    await this.loadHistory();
    this.showManualAdd = false;
    promptAction.showToast({ message: '手动记录已保存' });
  }

  private getPerKgKmFor(sport: string): number {
    if (sport === 'run') { return 1.04; }
    if (sport === 'cycle') { return 0.32; }
    return 0.5;
  }

  async saveDailySummarySport(date: string, minutes: number, calories: number): Promise<void> {
    try {
      const summary = await GlobalData.db.getDailySummary(date);
      const prevMin: number = summary ? Number(summary.exercise_minutes) || 0 : 0;
      const prevCal: number = summary ? Number(summary.calories_burned) || 0 : 0;
      await GlobalData.db.updateDailySummaryField(date, 'exercise_minutes', prevMin + minutes);
      await GlobalData.db.updateDailySummaryField(date, 'calories_burned', prevCal + calories);
    } catch (err) {
      console.error('SportPage saveDailySummary error:', JSON.stringify(err));
    }
  }

  formatDuration(sec: number): string {
    const h = Math.floor(sec / 3600);
    const m = Math.floor((sec % 3600) / 60);
    const s = sec % 60;
    if (h > 0) {
      return String(h).padStart(2, '0') + ':' + String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
    }
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  }

  getSportLabel(value: string): string {
    const found = Constants.SPORT_TYPES.find((s: SportTypeDef) => s.value === value);
    return found ? found.label : value;
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .accessibilityText('返回上一页')
          .accessibilityLevel('important')
          .onClick(() => { router.back(); })
        Text('运动记录').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
        Text('＋ 手动添加').fontSize(14).fontColor('#FF6B35')
          .onClick(() => {
            this.showManualAdd = !this.showManualAdd;
            if (this.showManualAdd) {
              this.manualSport = this.currentSport;
              this.manualKm = '';
            }
          })
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 16 })

      Scroll() {
        Column() {
          // 手动添加记录面板
          if (this.showManualAdd) {
            Column() {
              Text('手动添加记录').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ bottom: 12 })

              Text('运动类型').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(Constants.SPORT_TYPES, (item: SportTypeDef) => {
                  Text(item.icon + ' ' + item.label)
                    .fontSize(13)
                    .fontColor(this.manualSport === item.value ? '#FFFFFF' : this.txt())
                    .backgroundColor(this.manualSport === item.value ? '#FF6B35' : ThemeColors.inputBg(this.theme))
                    .borderRadius(16).padding({ left: 12, right: 12, top: 8, bottom: 8 })
                    .margin({ right: 8, bottom: 8 })
                    .onClick(() => { this.manualSport = item.value; })
                })
              }
              .width('100%')
              .margin({ bottom: 10 })

              Text('运动时长 (分钟)').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              TextInput({ placeholder: '30', text: this.manualMin })
                .type(InputType.Number).width('100%').height(44)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .fontColor(this.txt()).placeholderColor(this.sub())
                .onChange((v: string) => { this.manualMin = v; })
                .margin({ bottom: 10 })

              if (Constants.GPS_SPORTS.has(this.manualSport)) {
                Text('运动距离 (公里，可选)').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
                TextInput({ placeholder: '如 3.5', text: this.manualKm })
                  .type(InputType.Number).width('100%').height(44)
                  .backgroundColor(ThemeColors.inputBg(this.theme))
                  .fontColor(this.txt()).placeholderColor(this.sub())
                  .onChange((v: string) => { this.manualKm = v; })
                  .margin({ bottom: 10 })
              }

              Text('运动强度').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              Row() {
                ForEach(Constants.INTENSITIES, (item: string) => {
                  Text(item)
                    .fontSize(13)
                    .fontColor(this.intensity === item ? '#FFFFFF' : this.sub())
                    .backgroundColor(this.intensity === item ? '#FF6B35' : this.card())
                    .borderRadius(16).padding({ left: 14, right: 14, top: 8, bottom: 8 })
                    .margin({ right: 8 })
                    .onClick(() => { this.intensity = item; })
                })
              }
              .width('100%')

              if (this.isCalcCalories) {
                Text('正在云端计算热量...').fontSize(12).fontColor('#FF6B35').width('100%').margin({ top: 10 })
              }

              Button('保存记录').width('100%').height(46)
                .backgroundColor('#FF6B35').borderRadius(23)
                .margin({ top: 12 })
                .onClick(() => { this.saveManualRecord(); })
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 16 })
          }

          if (!this.isTracking) {
            Text('选择运动类型')
              .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
              .width('100%').padding({ left: 16, bottom: 8 })

            Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
              ForEach(Constants.SPORT_TYPES, (item: SportTypeDef) => {
                Column() {
                  Text(item.icon).fontSize(28)
                  Text(item.label).fontSize(12).fontColor(this.sub()).margin({ top: 4 })
                }
                .width(64).height(64)
                .backgroundColor(this.currentSport === item.value ? '#FF6B3544' : this.card())
                .borderRadius(32)
                .border(this.currentSport === item.value ? { style: BorderStyle.Solid, width: 2, color: '#FF6B35' } : { style: BorderStyle.Dashed, width: 0, color: 'transparent' })
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .margin(6)
                .onClick(() => { this.currentSport = item.value; })
              })
            }
            .width('100%').padding({ left: 16, right: 16 })

            // 烈度选择
            Text('运动强度').fontSize(13).fontColor(this.sub())
              .width('100%').padding({ left: 16, top: 8, bottom: 4 })
            Row() {
              ForEach(Constants.INTENSITIES, (item: string) => {
                Text(item)
                  .fontSize(13)
                  .fontColor(this.intensity === item ? '#FFFFFF' : this.sub())
                  .backgroundColor(this.intensity === item ? '#FF6B35' : this.card())
                  .borderRadius(16).padding({ left: 14, right: 14, top: 8, bottom: 8 })
                  .margin({ right: 8 })
                  .onClick(() => { this.intensity = item; })
              })
            }
            .width('100%').padding({ left: 16, right: 16 })

            Button() {
              Text('▶ 开始运动').fontSize(20).fontColor(this.txt())
            }
            .width(200).height(56).backgroundColor('#FF6B35').borderRadius(28)
            .margin({ top: 20 })
            .onClick(() => { this.startTracking(); })
            if (this.isGpsSport()) {
              Text('🚶 走路/跑步/骑行将使用 GPS 记录真实路程').fontSize(11)
                .fontColor(this.sub()).margin({ top: 8 })
            }
          } else {
            Column() {
              Text(this.formatDuration(this.durationSec))
                .fontSize(56).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              Text(this.isPaused ? '已暂停' : '运动中').fontSize(14).fontColor(this.isPaused ? '#FF9800' : this.sub())

              // 加减时间
              Row() {
                Button('-1分').fontSize(13).backgroundColor('#555555').borderRadius(16).height(36)
                  .onClick(() => { this.adjustTime(-60); })
                Button('-30秒').fontSize(13).backgroundColor('#555555').borderRadius(16).height(36).margin({ left: 8 })
                  .onClick(() => { this.adjustTime(-30); })
                Button('+30秒').fontSize(13).backgroundColor('#FF6B35').borderRadius(16).height(36).margin({ left: 8 })
                  .onClick(() => { this.adjustTime(30); })
                Button('+1分').fontSize(13).backgroundColor('#FF6B35').borderRadius(16).height(36).margin({ left: 8 })
                  .onClick(() => { this.adjustTime(60); })
              }
              .margin({ top: 8 })

              Row() {
                if (this.isGpsSport()) {
                  // GPS 运动：显示距离
                  Column() {
                    Text(this.distanceKm.toFixed(2)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                    Text(this.useGps ? '公里(GPS)' : '公里').fontSize(12).fontColor(this.sub())
                  }
                } else if (this.isStationarySport()) {
                  // 原地运动：显示强度
                  Column() {
                    Text(this.intensity.replace('强度', '')).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                    Text('运动强度').fontSize(12).fontColor(this.sub())
                  }
                } else {
                  // 其他运动：显示距离（如果有的话）
                  Column() {
                    Text(this.distanceKm.toFixed(2)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                    Text('公里').fontSize(12).fontColor(this.sub())
                  }
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  if (this.isCalcCalories) {
                    Text('...').fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  } else {
                    Text(String(this.calorieBurn)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  }
                  Text('千卡').fontSize(12).fontColor(this.sub())
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  Text(String(this.heartRateAvg)).fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  Text('bpm').fontSize(12).fontColor(this.sub())
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).margin({ top: 16 })

              // 根据运动类型显示不同的热量计算提示
              if (this.isGpsSport()) {
                Text('按体重 ' + this.bodyWeight.toFixed(0) + 'kg × 路程 ' + this.distanceKm.toFixed(2) + 'km 估算')
                  .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
              } else if (this.isStationarySport()) {
                Text('按体重 ' + this.bodyWeight.toFixed(0) + 'kg × ' + this.intensity + '估算')
                  .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
              } else {
                Text('卡路里按体重 ' + this.bodyWeight.toFixed(0) + 'kg 估算')
                  .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
              }

              if (this.useGps) {
                Text('📡 ' + this.gpsStatus).fontSize(11)
                  .fontColor(this.gpsStatus.includes('定位') ? '#FF9800' : '#4CAF50')
                  .margin({ top: 6 })
              }

              Row() {
                if (this.isPaused) {
                  Button('▶ 继续').width(100).height(48)
                    .backgroundColor('#4CAF50').borderRadius(24)
                    .onClick(() => { this.resumeTracking(); })
                } else {
                  Button('⏸ 暂停').width(100).height(48)
                    .backgroundColor('#FF9800').borderRadius(24)
                    .onClick(() => { this.pauseTracking(); })
                }
                Button('⏹ 结束').width(120).height(48)
                  .backgroundColor('#F44336').borderRadius(24).margin({ left: 10 })
                  .onClick(() => { this.saveSportRecord(); })
                Button('✖ 取消').width(90).height(48)
                  .backgroundColor('#555555').borderRadius(24).margin({ left: 10 })
                  .onClick(() => { this.stopTracking(); })
              }
              .margin({ top: 20 })
            }
            .width('100%').padding(24)
            .backgroundColor(this.card()).borderRadius(16)
            .margin({ left: 16, right: 16, top: 16 })
          }

          Text('运动历史').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
            .width('100%').padding({ left: 16, top: 24, bottom: 8 })

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(String(record.date)).fontSize(12).fontColor(this.sub())
                    Text(this.getSportLabel(String(record.sport_type)))
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.txt())
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                  Column() {
                    Text(String(record.duration_min) + 'min').fontSize(14).fontColor(this.txt())
                    Text(String(record.calories) + '千卡').fontSize(12).fontColor(this.sub())
                  }
                  .alignItems(HorizontalAlign.End)
                  Text('🗑').fontSize(16).margin({ left: 10 })
                    .onClick(() => { this.deleteRecord(Number(record.id)); })
                }
                .width('100%').padding(14)
                .backgroundColor(this.card()).borderRadius(10)
              }
            })
          }
          .width('100%').padding({ left: 16, right: 16 }).height(250)

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction })
      .slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn })
      .slide(SlideEffect.Left)
  }
}
