import { Constants, DbRow } from '../common/Constants';

@Component
export struct DiaryTab {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop accentColor: string = '#FF6B35';
  @Prop diaryDate: string = '';
  @Prop diaryDietRecords: DbRow[] = [];
  @Prop diarySportRecords: DbRow[] = [];
  @Prop diarySleepRecords: DbRow[] = [];
  @Prop diaryMoodRecords: DbRow[] = [];
  onDateChange: (offset: number) => void = () => {};
  onShare: () => void = () => {};

  getMoodEmoji(moodVal: number): string {
    if (moodVal >= 4.5) { return '😄'; }
    if (moodVal >= 3.5) { return '🙂'; }
    if (moodVal >= 2.5) { return '😐'; }
    if (moodVal >= 1.5) { return '😔'; }
    return '😢';
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('每日日记').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
          Text('◀').fontSize(18).fontColor(this.accentColor)
            .accessibilityText('查看前一天日记')
            .accessibilityLevel('important')
            .onClick(() => { this.onDateChange(-1); })
          Text(this.diaryDate.length > 0 ? this.diaryDate : '--')
            .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
            .margin({ left: 8, right: 8 })
          Text('▶').fontSize(18).fontColor(this.accentColor)
            .accessibilityText('查看后一天日记')
            .accessibilityLevel('important')
            .onClick(() => { this.onDateChange(1); })
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 + this.statusBarHeight, bottom: 12 })

        Row() {
          Text('📤 分享当天日记').fontSize(13).fontColor(this.accentColor)
            .onClick(() => { this.onShare(); })
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, bottom: 4 })

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
                  Text(Number(item.total_minutes) / 60 + '时').fontSize(12).fontColor(this.subTextColor)
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
}
