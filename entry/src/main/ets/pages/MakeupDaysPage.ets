import router from '@ohos.router';
import { Constants, ThemeColors } from '../common/Constants';
import { PreferenceHelper } from '../model/PreferenceHelper';
import { AchievementHelper } from '../model/AchievementHelper';
import { GlobalData } from '../common/GlobalData';

@Entry
@Component
struct MakeupDaysPage {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') systemDark: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('dataUpdateTrigger') dataUpdateTrigger: string = '';
  @State makeupDays: string[] = [];
  @State currentYear: number = new Date().getFullYear();
  @State currentMonth: number = new Date().getMonth();
  @State selectedDates: Set<string> = new Set();
  @State isLoading: boolean = true;

  private achievementHelper: AchievementHelper = new AchievementHelper(GlobalData.prefs);

  // 主题颜色辅助方法
  private bg(): string { return ThemeColors.pageBg(this.theme); }
  private card(): string { return ThemeColors.cardBg(this.theme); }
  private txt(): string { return ThemeColors.textPrimary(this.theme); }
  private sub(): string { return ThemeColors.textSecondary(this.theme); }
  private inputBg(): string { return ThemeColors.inputBg(this.theme); }

  async aboutToAppear() {
    await this.loadMakeupDays();
  }

  async loadMakeupDays() {
    this.isLoading = true;
    this.makeupDays = await GlobalData.prefs.getMakeupDays();
    this.selectedDates = new Set(this.makeupDays);
    this.isLoading = false;
  }

  getMonthDays(year: number, month: number): number {
    return new Date(year, month + 1, 0).getDate();
  }

  getFirstDayOfMonth(year: number, month: number): number {
    return new Date(year, month, 1).getDay();
  }

  formatDate(year: number, month: number, day: number): string {
    const m = (month + 1).toString().padStart(2, '0');
    const d = day.toString().padStart(2, '0');
    return `${year}-${m}-${d}`;
  }

  isToday(year: number, month: number, day: number): boolean {
    const today = new Date();
    return year === today.getFullYear() && month === today.getMonth() && day === today.getDate();
  }

  isFutureDate(year: number, month: number, day: number): boolean {
    const date = new Date(year, month, day);
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    return date > today;
  }

  async toggleDate(dateStr: string) {
    if (this.selectedDates.has(dateStr)) {
      this.selectedDates.delete(dateStr);
      await GlobalData.prefs.removeMakeupDay(dateStr);
    } else {
      this.selectedDates.add(dateStr);
      await GlobalData.prefs.addMakeupDay(dateStr);
    }
    
    // 触发成就检查（无论添加还是删除）
    const totalDays = this.selectedDates.size;
    await this.achievementHelper.checkAchievements(totalDays);
    
    this.makeupDays = Array.from(this.selectedDates);
    // 触发数据更新，通知其他页面刷新
    this.dataUpdateTrigger = Date.now().toString();
  }

  prevMonth() {
    if (this.currentMonth === 0) {
      this.currentMonth = 11;
      this.currentYear--;
    } else {
      this.currentMonth--;
    }
  }

  nextMonth() {
    if (this.currentMonth === 11) {
      this.currentMonth = 0;
      this.currentYear++;
    } else {
      this.currentMonth++;
    }
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text('‹')
          .fontSize(28)
          .fontColor(this.txt())
          .onClick(() => {
            router.back();
          })

        Text('补录达标天数')
          .fontSize(18)
          .fontColor(this.txt())
          .fontWeight(FontWeight.Medium)
          .margin({ left: 12 })
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.statusBarHeight + 8, bottom: 12 })
      .backgroundColor(this.card())

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(50)
            .height(50)
            .color('#4CAF50')
          Text('加载中...')
            .fontSize(14)
            .fontColor(this.sub())
            .margin({ top: 12 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // 统计信息
            Row() {
              Column() {
                Text('已补录天数')
                  .fontSize(12)
                  .fontColor(this.sub())
                Text(this.makeupDays.length.toString())
                  .fontSize(24)
                  .fontColor('#4CAF50')
                  .fontWeight(FontWeight.Bold)
                  .margin({ top: 4 })
              }
              .layoutWeight(1)

              Column() {
                Text('提示')
                  .fontSize(12)
                  .fontColor(this.sub())
                Text('点击日期添加/移除')
                  .fontSize(12)
                  .fontColor(this.txt())
                  .margin({ top: 4 })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.card())
            .borderRadius(12)
            .margin({ top: 12, left: 16, right: 16 })

            // 日历
            Column() {
              // 月份导航
              Row() {
                Text('‹')
                  .fontSize(28)
                  .fontColor(this.txt())
                  .onClick(() => this.prevMonth())

                Text(`${this.currentYear}年${this.currentMonth + 1}月`)
                  .fontSize(18)
                  .fontColor(this.txt())
                  .fontWeight(FontWeight.Medium)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)

                Text('›')
                  .fontSize(28)
                  .fontColor(this.txt())
                  .onClick(() => this.nextMonth())
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 16, bottom: 16 })

              // 星期标题
              Row() {
                ForEach(['日', '一', '二', '三', '四', '五', '六'], (day: string) => {
                  Text(day)
                    .width('14.28%')
                    .textAlign(TextAlign.Center)
                    .fontSize(14)
                    .fontColor(this.sub())
                })
              }
              .width('100%')
              .padding({ left: 8, right: 8 })

              // 日期网格
              Flex({ wrap: FlexWrap.Wrap }) {
                // 空白填充
                ForEach(Array.from({ length: this.getFirstDayOfMonth(this.currentYear, this.currentMonth) }), 
                  (_: undefined, index: number) => {
                    Text('')
                      .width('14.28%')
                      .height(40)
                  }
                )

                // 日期
                ForEach(Array.from({ length: this.getMonthDays(this.currentYear, this.currentMonth) }), 
                  (_: undefined, index: number) => {
                    Column() {
                      Text((index + 1).toString())
                        .fontSize(16)
                        .fontColor(this.isFutureDate(this.currentYear, this.currentMonth, index + 1) ? 
                          (this.theme === 'dark' ? '#555555' : '#CCCCCC') : 
                          (this.selectedDates.has(this.formatDate(this.currentYear, this.currentMonth, index + 1)) ? '#FFFFFF' : this.txt()))
                        .fontWeight(this.isToday(this.currentYear, this.currentMonth, index + 1) ? FontWeight.Bold : FontWeight.Normal)
                    }
                    .width('14.28%')
                    .height(40)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(this.selectedDates.has(this.formatDate(this.currentYear, this.currentMonth, index + 1)) ? '#4CAF50' : 'transparent')
                    .borderRadius(20)
                    .border(this.isToday(this.currentYear, this.currentMonth, index + 1) && 
                      !this.selectedDates.has(this.formatDate(this.currentYear, this.currentMonth, index + 1)) ? 
                      { width: 2, color: '#4CAF50' } : { width: 0 })
                    .opacity(this.isFutureDate(this.currentYear, this.currentMonth, index + 1) ? 0.3 : 1)
                    .onClick(() => {
                      if (!this.isFutureDate(this.currentYear, this.currentMonth, index + 1)) {
                        this.toggleDate(this.formatDate(this.currentYear, this.currentMonth, index + 1));
                      }
                    })
                  }
                )
              }
              .width('100%')
              .padding({ left: 8, right: 8, bottom: 16 })
            }
            .width('100%')
            .backgroundColor(this.card())
            .borderRadius(12)
            .margin({ top: 12, left: 16, right: 16 })

            // 已选日期列表
            if (this.makeupDays.length > 0) {
              Column() {
                Text('已补录日期')
                  .fontSize(14)
                  .fontColor(this.sub())
                  .width('100%')
                  .margin({ bottom: 8 })

                ForEach(this.makeupDays.sort((a: string, b: string) => b.localeCompare(a)), (date: string) => {
                  Row() {
                    Text(date)
                      .fontSize(14)
                      .fontColor(this.txt())
                      .layoutWeight(1)

                    Text('×')
                      .fontSize(20)
                      .fontColor('#FF6B6B')
                      .onClick(async () => {
                        await this.toggleDate(date);
                      })
                  }
                  .width('100%')
                  .padding(12)
                  .backgroundColor(this.inputBg())
                  .borderRadius(8)
                  .margin({ bottom: 8 })
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.card())
              .borderRadius(12)
              .margin({ top: 12, left: 16, right: 16, bottom: 16 })
            }
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.bg())
  }
}
