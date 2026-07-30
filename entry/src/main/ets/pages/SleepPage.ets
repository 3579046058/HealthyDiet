import { router } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { Constants, DbRow } from '../common/Constants';
import { TrendChart } from '../components/TrendChart';

@Entry
@Component
struct SleepPage {
  @State showInput: boolean = false;
  @State startTime: string = '23:00';
  @State endTime: string = '07:00';
  @State deepMin: string = '120';
  @State lightMin: string = '180';
  @State remMin: string = '90';
  @State records: DbRow[] = [];
  @State weekScores: number[] = [];
  @State weekLabels: string[] = [];
  @State avgScore: number = 0;
  @State lastRecord: string = '暂无数据';

  aboutToAppear(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const end = new Date();
      const start = new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
      const rows = await GlobalData.db.getSleepRecords(
        GlobalData.formatDate(start), GlobalData.formatDate(end)
      );
      this.records = rows;

      // 近七天数据
      const recent = rows.slice(0, 7);
      this.weekLabels = recent.map((item: DbRow) => String(item.date).slice(5)).reverse();
      this.weekScores = recent.map((item: DbRow) => Number(item.score)).reverse();
      if (this.weekScores.length > 0) {
        this.avgScore = Math.round(this.weekScores.reduce((a: number, b: number) => a + b, 0) / this.weekScores.length);
      }

      if (rows.length > 0) {
        const last = rows[0];
        this.lastRecord = last.date + ' ' + last.start_time + ' - ' + last.end_time;
      }
    } catch (err) {
      console.error('SleepPage loadData error:', JSON.stringify(err));
    }
  }

  calcScore(): number {
    const d = parseInt(this.deepMin) || 0;
    const l = parseInt(this.lightMin) || 0;
    const r = parseInt(this.remMin) || 0;
    const total = d + l + r;
    if (total <= 0) return 0;
    const deepRatio = d / total;
    const remRatio = r / total;
    let score = 60;
    if (deepRatio >= 0.2 && deepRatio <= 0.3) score += 15;
    else if (deepRatio >= 0.15) score += 10;
    if (remRatio >= 0.2 && remRatio <= 0.3) score += 15;
    else if (remRatio >= 0.15) score += 10;
    if (total >= 360 && total <= 540) score += 10;
    return Math.min(100, score);
  }

  async saveSleep(): Promise<void> {
    const d = parseInt(this.deepMin) || 0;
    const l = parseInt(this.lightMin) || 0;
    const r = parseInt(this.remMin) || 0;
    const total = d + l + r;
    if (total <= 0) return;

    const startParts = this.startTime.split(':');
    const endParts = this.endTime.split(':');
    const sh = parseInt(startParts[0]) || 0;
    const sm = parseInt(startParts[1]) || 0;
    const eh = parseInt(endParts[0]) || 0;
    const em = parseInt(endParts[1]) || 0;
    const startMin = sh * 60 + sm;
    const endMin = eh * 60 + em;
    let sleepDuration = endMin - startMin;
    if (sleepDuration < 0) sleepDuration += 24 * 60;

    const today = await GlobalData.getTodayDate();
    const score = this.calcScore();
    const record: DbRow = {
      date: today,
      start_time: this.startTime,
      end_time: this.endTime,
      deep_sleep_min: d,
      light_sleep_min: l,
      rem_min: r,
      total_minutes: sleepDuration,
      score: score,
    };
    await GlobalData.db.addSleepRecord(record);
    this.showInput = false;
    await this.loadData();
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).onClick(() => { router.back(); })
        Text('睡眠分析').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
        Blank()
        Text('+ 记录').fontSize(14).fontColor('#9C27B0')
          .onClick(() => { this.showInput = !this.showInput; })
      }
      .width('100%').padding(16)

      Scroll() {
        Column() {
          // 睡眠概览
          Row() {
            Column() {
              Text(String(this.avgScore)).fontSize(48).fontWeight(FontWeight.Bold).fontColor('#9C27B0')
              Text('平均睡眠评分').fontSize(13).fontColor('#888888').margin({ top: 4 })
            }
            Divider().vertical(true).height(70).margin({ left: 30, right: 30 })
            Column() {
              Text(this.lastRecord).fontSize(14).fontColor('#AAAAAA')
            }
          }
          .width('100%').justifyContent(FlexAlign.Center).padding(20)

          // 记录输入
          if (this.showInput) {
            Column() {
              Text('添加睡眠记录').fontSize(16).fontWeight(FontWeight.Bold).margin({ bottom: 12 })

              Row() {
                Text('入睡时间: ').fontSize(14)
                TextInput({ placeholder: '23:00', text: this.startTime })
                  .width(100).onChange((v: string) => { this.startTime = v; })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('醒来时间: ').fontSize(14)
                TextInput({ placeholder: '07:00', text: this.endTime })
                  .width(100).onChange((v: string) => { this.endTime = v; })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('深睡(min): ').fontSize(14)
                TextInput({ placeholder: '120', text: this.deepMin })
                  .width(80).type(InputType.Number).onChange((v: string) => { this.deepMin = v; })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('浅睡(min): ').fontSize(14)
                TextInput({ placeholder: '180', text: this.lightMin })
                  .width(80).type(InputType.Number).onChange((v: string) => { this.lightMin = v; })
              }.width('100%').padding({ bottom: 8 })

              Row() {
                Text('REM(min): ').fontSize(14)
                TextInput({ placeholder: '90', text: this.remMin })
                  .width(80).type(InputType.Number).onChange((v: string) => { this.remMin = v; })
              }.width('100%').padding({ bottom: 8 })

              Button('保存').width('100%').backgroundColor('#9C27B0').borderRadius(12)
                .margin({ top: 8 }).onClick(() => { this.saveSleep(); })
            }
            .width('100%').padding(16)
            .backgroundColor('#1A1A2E').borderRadius(16)
            .margin({ left: 16, right: 16, bottom: 16 })
          }

          // 近七天趋势图
          if (this.weekScores.length > 1) {
            Text('近七天趋势图').fontSize(16).fontWeight(FontWeight.Bold)
              .width('100%').padding({ left: 16, bottom: 8 })
            TrendChart({
              dataPoints: this.weekScores,
              lineColor: Constants.COLOR_SLEEP,
              fillColor: '#9C27B022',
              labels: this.weekLabels
            }).height(180).padding({ left: 16, right: 16 })
          }

          // 历史记录
          Text('历史记录').fontSize(16).fontWeight(FontWeight.Bold)
            .width('100%').padding({ left: 16, top: 20, bottom: 8 })

          List() {
            ForEach(this.records, (record: DbRow) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(String(record.date)).fontSize(12).fontColor('#888888')
                    Text(String(record.start_time) + ' - ' + String(record.end_time)).fontSize(14)
                  }
                  .alignItems(HorizontalAlign.Start)
                  Blank()
                  Column() {
                    Text(String(record.total_minutes) + 'min').fontSize(14).fontWeight(FontWeight.Bold)
                    Text('评分 ' + String(record.score)).fontSize(12).fontColor('#9C27B0')
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
