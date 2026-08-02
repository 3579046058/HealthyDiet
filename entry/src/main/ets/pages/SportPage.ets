import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, SportTypeDef, ThemeColors } from '../common/Constants';

@Entry
@Component
struct SportPage {
  @State currentSport: string = 'walk';
  @State durationSec: number = 0;
  @State distanceKm: number = 0;
  @State isTracking: boolean = false;
  @State timerId: number = -1;
  @State calorieBurn: number = 0;
  @State heartRateAvg: number = 0;
  @State records: DbRow[] = [];
  @State bodyWeight: number = 70;
  @StorageLink('currentTheme') theme: string = 'dark';

  aboutToAppear(): void {
    this.loadWeight();
    this.loadHistory();
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
    this.durationSec = 0;
    this.distanceKm = 0;
    this.calorieBurn = 0;
    const met: number = Constants.MET_VALUES.get(this.currentSport) ?? 4.0;
    const maxHr: number = Constants.MAX_HR;
    const restHr: number = Constants.REST_HR;
    // Karvonen 简化：运动心率 ≈ 静息心率 + MET × 8，上限为最大心率
    this.heartRateAvg = Math.min(maxHr, restHr + Math.round(met * 8));
    this.timerId = setInterval(() => {
      this.durationSec++;
      const spd = Constants.SPEED_KMH.get(this.currentSport) ?? 5;
      this.distanceKm = parseFloat(((this.durationSec / 3600) * spd).toFixed(2));
      const hours: number = this.durationSec / 3600;
      const weightKg: number = this.bodyWeight;
      this.calorieBurn = Math.round(met * weightKg * hours);
    }, 1000);
  }

  stopTracking(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.isTracking = false;
  }

  async saveSportRecord(): Promise<void> {
    if (this.durationSec < 60) {
      promptAction.showToast({ message: '运动时间太短，至少需要60秒' });
      return;
    }
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      sport_type: this.currentSport,
      duration_min: Math.max(1, Math.round(this.durationSec / 60)),
      distance_km: this.distanceKm,
      calories: this.calorieBurn,
      avg_heart_rate: this.heartRateAvg,
    };
    await GlobalData.db.addSportRecord(record);
    await this.saveDailySummarySport(today, Math.max(1, Math.round(this.durationSec / 60)), this.calorieBurn);
    this.stopTracking();
    await this.loadHistory();
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
    const m = Math.floor(sec / 60);
    const s = sec % 60;
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
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('运动记录').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          Text('选择运动类型')
            .fontSize(16).fontWeight(FontWeight.Bold)
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

          if (!this.isTracking) {
            Button() {
              Text('▶ 开始运动').fontSize(20).fontColor(this.txt())
            }
            .width(200).height(56).backgroundColor('#FF6B35').borderRadius(28)
            .margin({ top: 24 })
            .onClick(() => { this.startTracking(); })
          } else {
            Column() {
              Text(this.formatDuration(this.durationSec))
                .fontSize(56).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              Text('运动时长').fontSize(14).fontColor(this.sub())

              Row() {
                Column() {
                  Text(this.distanceKm.toFixed(2)).fontSize(24).fontWeight(FontWeight.Bold)
                  Text('公里').fontSize(12).fontColor(this.sub())
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  Text(String(this.calorieBurn)).fontSize(24).fontWeight(FontWeight.Bold)
                  Text('千卡').fontSize(12).fontColor(this.sub())
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  Text(String(this.heartRateAvg)).fontSize(24).fontWeight(FontWeight.Bold)
                  Text('bpm').fontSize(12).fontColor(this.sub())
                }
              }
              .width('100%').justifyContent(FlexAlign.Center).margin({ top: 20 })

              Text('卡路里按体重 ' + this.bodyWeight.toFixed(0) + 'kg 估算')
                .fontSize(11).fontColor(this.sub()).margin({ top: 8 })

              Row() {
                Button('⏹ 结束').width(140).height(48)
                  .backgroundColor('#F44336').borderRadius(24)
                  .onClick(() => { this.saveSportRecord(); })
                Button('✖ 取消').width(120).height(48)
                  .backgroundColor('#555555').borderRadius(24).margin({ left: 12 })
                  .onClick(() => { this.stopTracking(); })
              }
              .margin({ top: 24 })
            }
            .width('100%').padding(24)
            .backgroundColor(this.card()).borderRadius(16)
            .margin({ left: 16, right: 16, top: 20 })
          }

          Text('运动历史').fontSize(16).fontWeight(FontWeight.Bold)
            .width('100%').padding({ left: 16, top: 24, bottom: 8 })

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(String(record.date)).fontSize(12).fontColor(this.sub())
                    Text(this.getSportLabel(String(record.sport_type)))
                      .fontSize(16).fontWeight(FontWeight.Bold)
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                  Column() {
                    Text(String(record.duration_min) + 'min').fontSize(14)
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
