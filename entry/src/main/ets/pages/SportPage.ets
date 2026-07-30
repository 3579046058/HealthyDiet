import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow, SportTypeDef } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

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
  @State weeklyMinutes: number[] = [0, 0, 0, 0, 0, 0, 0];
  @State weekDays: string[] = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  aboutToAppear(): void {
    this.loadHistory();
  }

  aboutToDisappear(): void {
    this.stopTracking();
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
    this.heartRateAvg = 75 + Math.floor(Math.random() * 20);
    this.timerId = setInterval(() => {
      this.durationSec++;
      this.distanceKm = parseFloat(((this.durationSec / 3600) * (4 + Math.random() * 2)).toFixed(2));
      this.calorieBurn = Math.round(this.durationSec / 60 * 5);
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
    if (this.durationSec < 60) return;
    const today = await GlobalData.getTodayDate();
    const record: DbRow = {
      date: today,
      sport_type: this.currentSport,
      duration_min: Math.round(this.durationSec / 60),
      distance_km: this.distanceKm,
      calories: this.calorieBurn,
      avg_heart_rate: this.heartRateAvg,
    };
    await GlobalData.db.addSportRecord(record);
    this.stopTracking();
    await this.loadHistory();
  }

  formatDuration(sec: number): string {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return String(m).padStart(2, '0') + ':' + String(s).padStart(2, '0');
  }

  @Builder sportTypeButton(type: string, icon: string, label: string) {
    Column() {
      Text(icon).fontSize(28)
      Text(label).fontSize(12).fontColor('#AAAAAA').margin({ top: 4 })
    }
    .width(64).height(64)
    .backgroundColor(this.currentSport === type ? '#FF6B3544' : '#1A1A2E')
    .borderRadius(32)
    .border(this.currentSport === type ? { style: BorderStyle.Solid, width: 2, color: '#FF6B35' } : { style: BorderStyle.Dashed, width: 0, color: 'transparent' })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.currentSport = type; })
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('运动记录').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          // 运动类型选择
          Text('选择运动类型')
            .fontSize(16).fontWeight(FontWeight.Bold)
            .width('100%').padding({ left: 16, bottom: 8 })

          Row() {
            this.sportTypeButton('walk', '🚶', '步行')
            this.sportTypeButton('run', '🏃', '跑步')
            this.sportTypeButton('cycle', '🚴', '骑行')
          }
          .width('100%').justifyContent(FlexAlign.SpaceEvenly).padding({ left: 16, right: 16 })

          // 运动控制
          if (!this.isTracking) {
            Button() {
              Text('▶ 开始运动').fontSize(20).fontColor('#FFFFFF')
            }
            .width(200).height(56).backgroundColor('#FF6B35').borderRadius(28)
            .margin({ top: 24 })
            .onClick(() => { this.startTracking(); })
          } else {
            // 实时运动数据
            Column() {
              Text(this.formatDuration(this.durationSec))
                .fontSize(56).fontWeight(FontWeight.Bold).fontColor('#FF6B35')
              Text('运动时长').fontSize(14).fontColor('#888888')

              Row() {
                Column() {
                  Text(this.distanceKm.toFixed(2)).fontSize(24).fontWeight(FontWeight.Bold)
                  Text('公里').fontSize(12).fontColor('#888888')
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  Text(String(this.calorieBurn)).fontSize(24).fontWeight(FontWeight.Bold)
                  Text('千卡').fontSize(12).fontColor('#888888')
                }
                Divider().vertical(true).height(50).margin({ left: 24, right: 24 })
                Column() {
                  Text(String(this.heartRateAvg)).fontSize(24).fontWeight(FontWeight.Bold)
                  Text('bpm').fontSize(12).fontColor('#888888')
                }
              }
              .width('100%').justifyContent(FlexAlign.Center)
              .margin({ top: 20 })

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
            .backgroundColor('#1A1A2E').borderRadius(16)
            .margin({ left: 16, right: 16, top: 20 })
          }

          // 历史记录
          Text('运动历史').fontSize(16).fontWeight(FontWeight.Bold)
            .width('100%').padding({ left: 16, top: 24, bottom: 8 })

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(String(record.date)).fontSize(12).fontColor('#888888')
                    Text(Constants.SPORT_TYPES.find((s: SportTypeDef) => s.value === String(record.sport_type))?.label || String(record.sport_type))
                      .fontSize(16).fontWeight(FontWeight.Bold)
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                  Column() {
                    Text(String(record.duration_min) + 'min').fontSize(14)
                    Text(String(record.calories) + '千卡').fontSize(12).fontColor('#888888')
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%').padding(14)
                .backgroundColor('#1A1A2E').borderRadius(10)
              }
            })
          }
          .width('100%').padding({ left: 16, right: 16 }).height(250)

          Divider().opacity(0).height(24)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor('#0D0D1A')
  }
}
