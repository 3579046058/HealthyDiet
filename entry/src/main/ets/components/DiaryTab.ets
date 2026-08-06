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
  @State showDatePicker: boolean = false;
  @State tempYear: number = 2026;
  @State tempMonth: number = 1;
  @State tempDay: number = 1;
  onDateChange: (offset: number) => void = () => {};
  onDateSelect: (date: string) => void = () => {};
  onShare: () => void = () => {};
  onRefreshData: () => Promise<void> = async () => {};
  @State isRefreshing: boolean = false;

  aboutToAppear(): void {
    // 解析当前日期
    if (this.diaryDate && this.diaryDate.includes('-')) {
      const parts: string[] = this.diaryDate.split('-');
      this.tempYear = Number(parts[0]) || 2026;
      this.tempMonth = Number(parts[1]) || 1;
      this.tempDay = Number(parts[2]) || 1;
    } else {
      const now: Date = new Date();
      this.tempYear = now.getFullYear();
      this.tempMonth = now.getMonth() + 1;
      this.tempDay = now.getDate();
    }
  }

  getMoodEmoji(moodVal: number): string {
    if (moodVal >= 4.5) { return '😄'; }
    if (moodVal >= 3.5) { return '🙂'; }
    if (moodVal >= 2.5) { return '😐'; }
    if (moodVal >= 1.5) { return '😔'; }
    return '😢';
  }

  formatTime(timestamp: number | undefined): string {
    if (!timestamp) return '';
    const date: Date = new Date(timestamp);
    const h: number = date.getHours();
    const m: number = date.getMinutes();
    return `${h < 10 ? '0' + h : h}:${m < 10 ? '0' + m : m}`;
  }

  getMealTypeName(mealType: string): string {
    const names: Record<string, string> = {
      'breakfast': '早餐',
      'lunch': '午餐',
      'dinner': '晚餐',
      'snack': '加餐'
    };
    return names[mealType] || mealType;
  }

  getSportTypeName(sportType: string): string {
    const names: Record<string, string> = {
      'walk': '步行',
      'run': '跑步',
      'bike': '骑行',
      'swim': '游泳',
      'gym': '健身'
    };
    return names[sportType] || sportType;
  }

  formatDuration(minutes: number): string {
    if (minutes < 60) {
      return `${minutes}分钟`;
    }
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    return m > 0 ? `${h}时${m}分` : `${h}小时`;
  }

  confirmDatePicker(): void {
    const dateStr: string = `${this.tempYear}-${this.tempMonth < 10 ? '0' + this.tempMonth : this.tempMonth}-${this.tempDay < 10 ? '0' + this.tempDay : this.tempDay}`;
    this.onDateSelect(dateStr);
    this.showDatePicker = false;
  }

  build() {
    Stack() {
      Refresh({ refreshing: $$this.isRefreshing }) {
      Scroll() {
        Column() {
          // 标题栏：日期选择 + 分享按钮
          Row() {
            Text('每日日记').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            Blank()
            // 分享按钮
            Text('📤').fontSize(20)
              .onClick(() => { this.onShare(); })
            // 日期导航
            Text('◀').fontSize(18).fontColor(this.accentColor).margin({ left: 16 })
              .accessibilityText('查看前一天日记')
              .accessibilityLevel('important')
              .onClick(() => { this.onDateChange(-1); })
            Text(this.diaryDate.length > 0 ? this.diaryDate : '--')
              .fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
              .margin({ left: 8, right: 8 })
              .onClick(() => { this.showDatePicker = true; }) // 点击日期弹出选择器
            Text('▶').fontSize(18).fontColor(this.accentColor)
              .accessibilityText('查看后一天日记')
              .accessibilityLevel('important')
              .onClick(() => { this.onDateChange(1); })
          }
          .width('100%').padding({ left: 20, right: 20, top: 16 + this.statusBarHeight, bottom: 12 })

          if (this.diaryDietRecords.length === 0 && this.diarySportRecords.length === 0 &&
            this.diarySleepRecords.length === 0 && this.diaryMoodRecords.length === 0) {
            Column() {
              Text('📝').fontSize(48).margin({ top: 40 })
              Text('暂无记录').fontSize(16).fontColor(this.subTextColor).margin({ top: 12 })
              Text('开始记录你的健康生活吧').fontSize(13).fontColor(this.subTextColor)
            }
            .width('100%').alignItems(HorizontalAlign.Center).margin({ top: 60 })
          } else {
            // 饮食记录
            if (this.diaryDietRecords.length > 0) {
              Text('🍎 饮食').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .width('100%').padding({ left: 20, top: 12, bottom: 6 })
              ForEach(this.diaryDietRecords, (item: DbRow) => {
                Column() {
                  Row() {
                    // 时间和餐别
                    Text(this.formatTime(Number(item.timestamp)) || '--:--')
                      .fontSize(12).fontColor(this.accentColor)
                    Text(' · ').fontSize(12).fontColor(this.subTextColor)
                    Text(this.getMealTypeName(String(item.meal_type)))
                      .fontSize(12).fontColor(this.subTextColor)
                    Blank()
                    Text(Number(item.calories) + ' kcal')
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
                  }.width('100%')
                  Row() {
                    Text(String(item.food_name)).fontSize(15).fontColor(this.textColor)
                    Blank()
                    if (item.amount_g) {
                      Text(Number(item.amount_g) + 'g').fontSize(12).fontColor(this.subTextColor)
                    }
                  }.width('100%').margin({ top: 4 })
                }
                .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8)
                .margin({ bottom: 4, left: 16, right: 16 })
              }, (item: DbRow): string => String(item.id))
            }

            // 运动记录
            if (this.diarySportRecords.length > 0) {
              Text('🏃 运动').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .width('100%').padding({ left: 20, top: 12, bottom: 6 })
              ForEach(this.diarySportRecords, (item: DbRow) => {
                Column() {
                  Row() {
                    Text(this.formatTime(Number(item.timestamp)) || '--:--')
                      .fontSize(12).fontColor(this.accentColor)
                    Text(' · ').fontSize(12).fontColor(this.subTextColor)
                    Text(this.getSportTypeName(String(item.sport_type)))
                      .fontSize(12).fontColor(this.subTextColor)
                    Blank()
                    Text(Number(item.calories) + ' kcal')
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
                  }.width('100%')
                  Row() {
                    Text(this.formatDuration(Number(item.duration_min)))
                      .fontSize(15).fontColor(this.textColor)
                    if (item.distance_km && Number(item.distance_km) > 0) {
                      Text(' · ' + Number(item.distance_km).toFixed(1) + 'km')
                        .fontSize(13).fontColor(this.subTextColor)
                    }
                    if (item.avg_heart_rate && Number(item.avg_heart_rate) > 0) {
                      Text(' · ❤️' + Number(item.avg_heart_rate))
                        .fontSize(13).fontColor(this.subTextColor)
                    }
                  }.width('100%').margin({ top: 4 })
                }
                .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8)
                .margin({ bottom: 4, left: 16, right: 16 })
              }, (item: DbRow): string => String(item.id))
            }

            // 睡眠记录
            if (this.diarySleepRecords.length > 0) {
              Text('😴 睡眠').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .width('100%').padding({ left: 20, top: 12, bottom: 6 })
              ForEach(this.diarySleepRecords, (item: DbRow) => {
                Column() {
                  Row() {
                    Text('入睡 ' + String(item.start_time || '--:--'))
                      .fontSize(13).fontColor(this.textColor)
                    Text(' → ').fontSize(13).fontColor(this.subTextColor)
                    Text('醒来 ' + String(item.end_time || '--:--'))
                      .fontSize(13).fontColor(this.textColor)
                    Blank()
                    Text('评分 ' + Number(item.score))
                      .fontSize(14).fontWeight(FontWeight.Bold).fontColor(Constants.COLOR_SLEEP)
                  }.width('100%')
                  Row() {
                    Text('总时长 ' + this.formatDuration(Number(item.total_minutes)))
                      .fontSize(13).fontColor(this.subTextColor)
                    if (item.deep_sleep_min && Number(item.deep_sleep_min) > 0) {
                      Text(' · 深睡 ' + Number(item.deep_sleep_min) + 'min')
                        .fontSize(12).fontColor(this.subTextColor)
                    }
                  }.width('100%').margin({ top: 4 })
                }
                .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8)
                .margin({ bottom: 4, left: 16, right: 16 })
              }, (item: DbRow): string => String(item.id))
            }

            // 情绪记录
            if (this.diaryMoodRecords.length > 0) {
              Text('😊 情绪').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
                .width('100%').padding({ left: 20, top: 12, bottom: 6 })
              ForEach(this.diaryMoodRecords, (item: DbRow) => {
                Column() {
                  Row() {
                    Text(this.formatTime(Number(item.timestamp)) || '--:--')
                      .fontSize(12).fontColor(this.accentColor)
                    Blank()
                    Text(this.getMoodEmoji(Number(item.mood))).fontSize(24)
                  }.width('100%')
                  // 显示情绪笔记文本
                  if (item.note && String(item.note).length > 0) {
                    Text(String(item.note))
                      .fontSize(14).fontColor(this.textColor)
                      .maxLines(3)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                      .margin({ top: 8 })
                  }
                }
                .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(8)
                .alignItems(HorizontalAlign.Start)
                .margin({ bottom: 4, left: 16, right: 16 })
              }, (item: DbRow): string => String(item.id))
            }
          }
          Divider().opacity(0).height(24)
        }
        .width('100%')
        }
        }
        .width('100%')
        .height('100%')
        .onRefreshing(() => {
          // 下拉刷新：重新加载日记数据
          this.onRefreshData().then(() => {
            setTimeout(() => {
              this.isRefreshing = false;
            }, 600);
          }).catch(() => {
            this.isRefreshing = false;
          });
        })

      // 日期选择弹窗
      if (this.showDatePicker) {
        Column() {
          Column() {
            Text('选择日期').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
              .width('100%').textAlign(TextAlign.Center).margin({ bottom: 16 })

            // 年月日选择器
            Row() {
              // 年
              Column() {
                Text('年').fontSize(12).fontColor(this.subTextColor)
                Row() {
                  Text('−').fontSize(24).fontColor(this.accentColor)
                    .onClick(() => { if (this.tempYear > 2020) this.tempYear--; })
                  Text(String(this.tempYear)).fontSize(20).fontColor(this.textColor)
                    .width(60).textAlign(TextAlign.Center)
                  Text('+').fontSize(24).fontColor(this.accentColor)
                    .onClick(() => { if (this.tempYear < 2030) this.tempYear++; })
                }
              }.layoutWeight(1)

              // 月
              Column() {
                Text('月').fontSize(12).fontColor(this.subTextColor)
                Row() {
                  Text('−').fontSize(24).fontColor(this.accentColor)
                    .onClick(() => { if (this.tempMonth > 1) this.tempMonth--; })
                  Text(String(this.tempMonth)).fontSize(20).fontColor(this.textColor)
                    .width(40).textAlign(TextAlign.Center)
                  Text('+').fontSize(24).fontColor(this.accentColor)
                    .onClick(() => { if (this.tempMonth < 12) this.tempMonth++; })
                }
              }.layoutWeight(1)

              // 日
              Column() {
                Text('日').fontSize(12).fontColor(this.subTextColor)
                Row() {
                  Text('−').fontSize(24).fontColor(this.accentColor)
                    .onClick(() => { if (this.tempDay > 1) this.tempDay--; })
                  Text(String(this.tempDay)).fontSize(20).fontColor(this.textColor)
                    .width(40).textAlign(TextAlign.Center)
                  Text('+').fontSize(24).fontColor(this.accentColor)
                    .onClick(() => { if (this.tempDay < 31) this.tempDay++; })
                }
              }.layoutWeight(1)
            }.width('100%')

            // 确认和取消按钮
            Row() {
              Text('取消').fontSize(16).fontColor(this.subTextColor)
                .onClick(() => { this.showDatePicker = false; })
              Blank()
              Text('确定').fontSize(16).fontColor(this.accentColor).fontWeight(FontWeight.Bold)
                .onClick(() => { this.confirmDatePicker(); })
            }
            .width('100%').margin({ top: 20 })
          }
          .width('85%')
          .padding(20)
          .backgroundColor(this.cardColor)
          .borderRadius(16)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => { this.showDatePicker = false; })
      }
    }
    .width('100%')
    .height('100%')
  }
}
