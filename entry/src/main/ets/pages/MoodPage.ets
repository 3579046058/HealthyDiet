import { router, promptAction } from '@kit.ArkUI';
import { GlobalData } from '../common/GlobalData';
import { DbRow, ThemeColors } from '../common/Constants';
import { CardDataHelper } from '../services/CardDataHelper';

@Entry
@Component
struct MoodPage {
  @State selectedMood: number = 3;
  @State note: string = '';
  @State records: DbRow[] = [];
  @State weekAvg: number = 0;
  @State expandedId: number = -1;
  @State recordDate: string = '';
  @State tempDate: Date = new Date();
  @State showInput: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.loadData();
    GlobalData.getTodayDate().then((today: string) => {
      this.recordDate = today;
    });
  }

  async loadData(): Promise<void> {
    try {
      const now: Date = new Date();
      const past: Date = new Date();
      past.setDate(now.getDate() - 30);
      const startDate: string = this.formatDate(past);
      const endDate: string = this.formatDate(now);
      const rows: DbRow[] = await GlobalData.db.getMoodRecords(startDate, endDate);
      this.records = rows;
      console.info('MoodPage loadData rows=' + String(rows.length));
      this.weekAvg = this.getWeekAverage();
    } catch (err) {
      console.error('MoodPage loadData error:', JSON.stringify(err));
    }
  }

  async saveRecord(): Promise<void> {
    try {
      let date: string;
      if (this.showInput) {
        date = this.formatDate(this.tempDate);
      } else {
        date = this.recordDate.length > 0 ? this.recordDate : await GlobalData.getTodayDate();
      }
      const record: DbRow = {
        date: date,
        mood: this.selectedMood,
        note: this.note,
      };
      await GlobalData.db.addMoodRecord(record);
      await CardDataHelper.refreshWidget(getContext(this));
      await this.loadData();
      this.note = '';
      this.selectedMood = 3;
      this.showInput = false;
      promptAction.showToast({ message: '已保存' });
    } catch (err) {
      console.error('MoodPage saveRecord error:', JSON.stringify(err));
    }
  }

  onDateChange(offsetDays: number): void {
    if (this.recordDate.length === 0) {
      return;
    }
    const d = new Date(this.recordDate + 'T00:00:00');
    if (isNaN(d.getTime())) {
      return;
    }
    d.setDate(d.getDate() + offsetDays);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const today = new Date();
    const todayStr = today.getFullYear() + '-' + String(today.getMonth() + 1).padStart(2, '0') +
      '-' + String(today.getDate()).padStart(2, '0');
    const candidate = y + '-' + m + '-' + day;
    if (candidate > todayStr) {
      return;
    }
    this.recordDate = candidate;
  }

  async deleteRecord(id: number): Promise<void> {
    console.info('MoodPage deleteRecord id=' + String(id));
    if (isNaN(id) || id <= 0) {
      console.error('MoodPage deleteRecord invalid id');
      return;
    }
    await GlobalData.db.deleteMoodRecord(id);
    await CardDataHelper.refreshWidget(getContext(this));
    promptAction.showToast({ message: '已删除' });
    await this.loadData();
  }

  toggleExpanded(id: number): void {
    if (this.expandedId === id) {
      this.expandedId = -1;
    } else {
      this.expandedId = id;
    }
  }

  isExpanded(id: number): boolean {
    return this.expandedId === id;
  }

  getMoodEmoji(mood: number): string {
    if (mood >= 4.5) { return '😄'; }
    if (mood >= 3.5) { return '🙂'; }
    if (mood >= 2.5) { return '😐'; }
    if (mood >= 1.5) { return '😔'; }
    return '😢';
  }

  getMoodLabel(mood: number): string {
    if (mood === 5) { return '很好'; }
    if (mood === 4) { return '不错'; }
    if (mood === 3) { return '一般'; }
    if (mood === 2) { return '不好'; }
    return '很差';
  }

  formatDate(date: Date): string {
    const y: string = date.getFullYear().toString();
    let m: string = (date.getMonth() + 1).toString();
    let d: string = date.getDate().toString();
    if (m.length < 2) { m = '0' + m; }
    if (d.length < 2) { d = '0' + d; }
    return y + '-' + m + '-' + d;
  }

  getWeekAverage(): number {
    const now: Date = new Date();
    let dow: number = now.getDay();
    if (dow === 0) { dow = 7; }
    const weekStart: Date = new Date(now.getTime() - (dow - 1) * 86400000);
    const startStr: string = this.formatDate(weekStart);
    const endStr: string = this.formatDate(now);
    let total: number = 0;
    let count: number = 0;
    for (let i: number = 0; i < this.records.length; i++) {
      const r: DbRow = this.records[i];
      const rd: string = String(r.date);
      if (rd >= startStr && rd <= endStr) {
        total += Number(r.mood);
        count++;
      }
    }
    if (count === 0) { return 0; }
    return Math.round((total / count) * 10) / 10;
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .onClick(() => { router.back(); })
        Text('情绪记录')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt())
          .margin({ left: 12 })
        Blank()
        Text(this.showInput ? '✕' : '＋ 添加').fontSize(14).fontColor('#FFC107')
          .onClick(() => {
            this.showInput = !this.showInput;
            if (this.showInput) {
              this.tempDate = new Date();
            }
          })
      }
      .width('100%').padding({ left: 16, right: 16, top: 16 + this.statusBarHeight, bottom: 8 })

      Scroll() {
        Column() {
          // 日期选择
          if (this.showInput) {
            // 完整添加面板：DatePicker 选日期 + 表情 + 备注
            Column() {
              Text('选择日期').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 4 })
              DatePicker({ selected: this.tempDate })
                .onDateChange((d: Date) => {
                  const today = new Date();
                  const t = new Date(d.getFullYear(), d.getMonth(), d.getDate());
                  const max = new Date(today.getFullYear(), today.getMonth(), today.getDate());
                  if (t.getTime() > max.getTime()) {
                    this.tempDate = max;
                    return;
                  }
                  this.tempDate = d;
                })
                .margin({ bottom: 16 })

              Text('心情').fontSize(13).fontColor(this.sub()).width('100%').margin({ bottom: 8 })
              Row() {
                ForEach([1, 2, 3, 4, 5], (mood: number) => {
                  Column() {
                    Text(this.getMoodEmoji(mood)).fontSize(30).lineHeight(38)
                    Text(this.getMoodLabel(mood)).fontSize(10).fontColor(this.sub()).margin({ top: 2 })
                  }
                  .width(52).height(72)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .borderRadius(10)
                  .backgroundColor(this.selectedMood === mood ? '#FFC107' : this.card())
                  .border({ width: 2, color: this.selectedMood === mood ? '#FFC107' : ThemeColors.divider(this.theme), style: BorderStyle.Solid })
                  .onClick(() => { this.selectedMood = mood; })
                }, (mood: number): string => mood.toString())
              }
              .width('100%').justifyContent(FlexAlign.SpaceEvenly)
              .padding({ bottom: 16 })

              TextArea({ placeholder: '今天过得怎么样？(选填)', text: this.note })
                .width('100%').height(80)
                .backgroundColor(ThemeColors.inputBg(this.theme))
                .placeholderColor(ThemeColors.textSecondary(this.theme))
                .fontColor(this.txt()).borderRadius(12).padding(12)
                .onChange((value: string) => { this.note = value; })

              Row() {
                Button('取消').layoutWeight(1).height(44)
                  .backgroundColor('#555555').borderRadius(22)
                  .fontColor(this.txt()).fontSize(15)
                  .margin({ right: 8 })
                  .onClick(() => {
                    this.showInput = false;
                    this.note = '';
                    this.selectedMood = 3;
                  })
                Button('保存记录').layoutWeight(1).height(44)
                  .backgroundColor('#FFC107').fontColor('#0D0D1A')
                  .fontWeight(FontWeight.Bold).borderRadius(22)
                  .fontSize(15)
                  .onClick(() => { this.saveRecord(); })
              }
              .width('100%').margin({ top: 16, bottom: 24 })
            }
            .width('100%').padding(16)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ bottom: 16 })
          } else {
            // 快速记录：◀ ▶ 切换日期 + 表情
            Row() {
              Text('◀').fontSize(18).fontColor('#FFC107')
                .onClick(() => { this.onDateChange(-1); })
              Text(this.recordDate.length > 0 ? this.recordDate : '--')
                .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
                .margin({ left: 14, right: 14 })
              Text('▶').fontSize(18).fontColor('#FFC107')
                .onClick(() => { this.onDateChange(1); })
            }
            .width('100%').justifyContent(FlexAlign.Center)

            Text('今天心情怎么样？')
              .fontSize(16).fontColor(this.txt())
              .width('100%').margin({ top: 12, bottom: 16 })

            Row() {
              ForEach([1, 2, 3, 4, 5], (mood: number) => {
                Column() {
                  Text(this.getMoodEmoji(mood)).fontSize(36).lineHeight(44)
                  Text(this.getMoodLabel(mood)).fontSize(11).fontColor(this.sub()).margin({ top: 4 })
                }
                .width(60).height(86)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .borderRadius(12)
                .backgroundColor(this.selectedMood === mood ? '#FFC107' : this.card())
                .border({ width: 2, color: this.selectedMood === mood ? '#FFC107' : ThemeColors.divider(this.theme), style: BorderStyle.Solid })
                .onClick(() => { this.selectedMood = mood; })
              }, (mood: number): string => mood.toString())
            }
            .width('100%').justifyContent(FlexAlign.SpaceEvenly)
            .padding({ bottom: 24 })

            TextArea({ placeholder: '今天过得怎么样？(选填)', text: this.note })
              .width('100%').height(80)
              .backgroundColor(ThemeColors.inputBg(this.theme))
              .placeholderColor(ThemeColors.textSecondary(this.theme))
              .fontColor(this.txt()).borderRadius(12).padding(12)
              .onChange((value: string) => { this.note = value; })

            Button('保存')
              .width('100%').height(48)
              .backgroundColor('#FFC107').fontColor('#0D0D1A')
              .fontWeight(FontWeight.Bold).borderRadius(24)
              .margin({ top: 16, bottom: 24 })
              .onClick(() => { this.saveRecord(); })
          }

          if (this.weekAvg > 0) {
            Row() {
              Text('本周平均心情: ').fontSize(14).fontColor(this.sub())
              Text(this.getMoodEmoji(this.weekAvg)).fontSize(20)
              Text(this.weekAvg.toString()).fontSize(14).fontColor('#FFC107').fontWeight(FontWeight.Bold)
            }
            .width('100%').padding(12)
            .backgroundColor(this.card()).borderRadius(12)
            .margin({ bottom: 16 })
          }

          Row() {
            Text('近期情绪记录').fontSize(16).fontColor(this.txt()).fontWeight(FontWeight.Bold)
            Blank()
            Text(this.records.length > 0 ? '共 ' + String(this.records.length) + ' 条' : '')
              .fontSize(12).fontColor(this.sub())
          }
          .width('100%').margin({ bottom: 12 })

          if (this.records.length === 0) {
            Column() {
              Text('😶').fontSize(40).margin({ top: 12 })
              Text('暂无情绪记录').fontSize(14).fontColor(this.sub()).margin({ top: 8 })
              Text('点击上方表情，记录今天的心情吧').fontSize(12).fontColor(this.sub()).margin({ top: 4 })
            }
            .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 24 })
          }

          ForEach(this.records, (item: DbRow) => {
            Column() {
              Row() {
                Column() {
                  Text(String(item.date)).fontSize(13).fontColor(this.sub())
                  Text(String(Number(item.mood)) + ' · ' + this.getMoodLabel(Number(item.mood)))
                    .fontSize(11).fontColor('#FFC107').margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .width(90)

                Text(this.getMoodEmoji(Number(item.mood))).fontSize(24).margin({ left: 4, right: 8 })

                if (String(item.note).length > 0) {
                  Text(String(item.note))
                    .fontSize(13).fontColor(this.txt())
                    .layoutWeight(1)
                    .maxLines(this.isExpanded(Number(item.id)) ? 1000 : 2)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                } else {
                  Text('—').fontSize(13).fontColor(this.sub()).layoutWeight(1)
                }

                if (String(item.note).length > 0) {
                  Text(this.isExpanded(Number(item.id)) ? '▲' : '▼')
                    .fontSize(12).fontColor(this.sub()).margin({ left: 6 })
                } else {
                  Text('🗑').fontSize(16).margin({ left: 8 })
                    .onClick(() => { this.deleteRecord(Number(item.id)); })
                }
              }
              .width('100%')

              if (this.isExpanded(Number(item.id)) && String(item.note).length > 0) {
                Row() {
                  Text('收起').fontSize(11).fontColor(this.sub())
                    .onClick(() => { this.toggleExpanded(Number(item.id)); })
                  Blank()
                  Text('🗑 删除').fontSize(12).fontColor('#F44336')
                    .onClick(() => { this.deleteRecord(Number(item.id)); })
                }
                .width('100%').margin({ top: 8 })
              }
            }
            .width('100%').padding(12)
            .backgroundColor(this.card()).borderRadius(8)
            .margin({ bottom: 8 })
            .onClick(() => {
              if (String(item.note).length > 0) {
                this.toggleExpanded(Number(item.id));
              }
            })
          }, (item: DbRow): string => String(item.id))
        }
        .width('100%').padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%').height('100%')    .backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
