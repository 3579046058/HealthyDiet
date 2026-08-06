import { DbRow } from '../common/Constants';

@Component
export struct SharePanel {
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop bgColor: string = '#121212';
  @Prop accentColor: string = '#FF6B35';
  @Prop diaryDietRecords: DbRow[] = [];
  @Prop diarySportRecords: DbRow[] = [];
  @Prop diarySleepRecords: DbRow[] = [];
  @Prop diaryMoodRecords: DbRow[] = [];
  @Prop shareDiet: boolean = true;
  @Prop shareSport: boolean = true;
  @Prop shareSleep: boolean = true;
  @Prop shareMood: boolean = true;
  @Prop shareOverview: boolean = true;
  @Prop isGeneratingShare: boolean = false;
  @Prop healthScore: number = 0;
  @Prop hasScoreData: boolean = false;
  @Prop steps: number = 0;
  @Prop exerciseMin: number = 0;
  @Prop sleepHours: string = '0';
  @Prop diaryDate: string = '';
  onDietChange: (on: boolean) => void = () => {};
  onSportChange: (on: boolean) => void = () => {};
  onSleepChange: (on: boolean) => void = () => {};
  onMoodChange: (on: boolean) => void = () => {};
  onOverviewChange: (on: boolean) => void = () => {};
  onClose: () => void = () => {};
  onGenerate: () => void = () => {};

  build() {
    Column() {
      Blank()
      Column() {
        // 标题栏
        Row() {
          Text('分享我的健康日记').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
          Text('✕').fontSize(20).fontColor(this.subTextColor)
            .accessibilityText('关闭分享面板')
            .accessibilityLevel('important')
            .onClick(() => { this.onClose(); })
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 })

        // 可滚动的预览区域
        Text('预览').fontSize(12).fontColor(this.subTextColor).width('100%')
          .padding({ left: 20, top: 12, bottom: 8 })

        Scroll() {
          Column() {
            this.shareCardContent()
          }
          .width('100%')
        }
        .width('100%')
        .height(280)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 20, right: 20 })

        // 选择要分享的内容
        Text('选择要分享的内容').fontSize(12).fontColor(this.subTextColor).width('100%')
          .padding({ left: 20, top: 12, bottom: 8 })

        Column() {
          this.shareCheckItem($r('app.media.ic_diet'), '饮食记录', this.diaryDietRecords.length > 0, this.shareDiet, (on: boolean) => { this.onDietChange(on); })
          this.shareCheckItem($r('app.media.ic_sport'), '运动记录', this.diarySportRecords.length > 0, this.shareSport, (on: boolean) => { this.onSportChange(on); })
          this.shareCheckItem($r('app.media.ic_sleep'), '睡眠记录', this.diarySleepRecords.length > 0, this.shareSleep, (on: boolean) => { this.onSleepChange(on); })
          this.shareCheckItem($r('app.media.ic_mood'), '情绪记录', this.diaryMoodRecords.length > 0, this.shareMood, (on: boolean) => { this.onMoodChange(on); })
          this.shareCheckItem($r('app.media.ic_report'), '今日健康概览', true, this.shareOverview, (on: boolean) => { this.onOverviewChange(on); })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        Button(this.isGeneratingShare ? '生成中...' : '生成分享卡片')
          .width('90%').height(44).margin({ top: 16, bottom: 16 })
          .backgroundColor(this.accentColor)
          .fontColor(Color.White)
          .enabled(!this.isGeneratingShare)
          .onClick(() => { this.onGenerate(); })
      }
      .width('100%')
      .backgroundColor(this.bgColor)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
  }

  @Builder shareCardContent() {
    Column() {
      // 标题
      Row() {
        Column() {
          Text('健康1st').fontSize(16).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Text('我的健康日记').fontSize(10).fontColor(this.subTextColor).margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text(this.diaryDate).fontSize(11).fontColor(this.subTextColor)
      }
      .width('100%')

      // 健康概览
      if (this.shareOverview) {
        Column() {
          Row() {
            Text('健康评分').fontSize(10).fontColor(this.subTextColor)
            Blank()
            Text(this.hasScoreData ? String(this.healthScore) : '--')
              .fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor(this.hasScoreData ? this.getScoreColor(this.healthScore) : this.subTextColor)
          }.width('100%')
          Row() {
            Text('步数').fontSize(10).fontColor(this.subTextColor)
            Blank()
            Text(this.steps > 0 ? this.formatNumber(this.steps) : '--')
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }.width('100%').margin({ top: 4 })
          Row() {
            Text('运动').fontSize(10).fontColor(this.subTextColor)
            Blank()
            Text(this.exerciseMin > 0 ? String(this.exerciseMin) + '分钟' : '--')
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }.width('100%').margin({ top: 4 })
          Row() {
            Text('睡眠').fontSize(10).fontColor(this.subTextColor)
            Blank()
            Text(this.sleepHours !== '0' && this.sleepHours !== '0.0' ? this.sleepHours + '小时' : '--')
              .fontSize(14).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          }.width('100%').margin({ top: 4 })
        }
        .width('100%').padding(10)
        .backgroundColor(this.cardColor).borderRadius(10).margin({ top: 8 })
      }

      // 饮食记录
      if (this.shareDiet && this.diaryDietRecords.length > 0) {
        Text('🍎 饮食').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 8 })
        ForEach(this.diaryDietRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text(this.formatTime(Number(item.timestamp))).fontSize(10).fontColor(this.accentColor)
              Text(' · ').fontSize(10).fontColor(this.subTextColor)
              Text(this.getMealTypeName(String(item.meal_type))).fontSize(10).fontColor(this.subTextColor)
              Blank()
              Text(Number(item.calories) + ' kcal').fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
            }.width('100%')
            Row() {
              Text(String(item.food_name)).fontSize(12).fontColor(this.textColor)
              if (item.amount_g) {
                Text('  ' + Number(item.amount_g) + 'g').fontSize(10).fontColor(this.subTextColor)
              }
            }.width('100%').margin({ top: 2 })
          }
          .width('100%').padding(6).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 3 })
        }, (item: DbRow): string => String(item.id))
      }

      // 运动记录
      if (this.shareSport && this.diarySportRecords.length > 0) {
        Text('🏃 运动').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 8 })
        ForEach(this.diarySportRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text(this.formatTime(Number(item.timestamp))).fontSize(10).fontColor(this.accentColor)
              Text(' · ').fontSize(10).fontColor(this.subTextColor)
              Text(this.getSportTypeName(String(item.sport_type))).fontSize(10).fontColor(this.subTextColor)
              Blank()
              Text(Number(item.calories) + ' kcal').fontSize(11).fontWeight(FontWeight.Bold).fontColor(this.accentColor)
            }.width('100%')
            Row() {
              Text(this.formatDuration(Number(item.duration_min))).fontSize(12).fontColor(this.textColor)
              if (item.distance_km && Number(item.distance_km) > 0) {
                Text(' · ' + Number(item.distance_km).toFixed(1) + 'km').fontSize(10).fontColor(this.subTextColor)
              }
            }.width('100%').margin({ top: 2 })
          }
          .width('100%').padding(6).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 3 })
        }, (item: DbRow): string => String(item.id))
      }

      // 睡眠记录
      if (this.shareSleep && this.diarySleepRecords.length > 0) {
        Text('😴 睡眠').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 8 })
        ForEach(this.diarySleepRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text('入睡 ' + String(item.start_time || '--:--')).fontSize(11).fontColor(this.textColor)
              Text(' → ').fontSize(11).fontColor(this.subTextColor)
              Text('醒来 ' + String(item.end_time || '--:--')).fontSize(11).fontColor(this.textColor)
              Blank()
              Text('评分 ' + Number(item.score)).fontSize(11).fontWeight(FontWeight.Bold).fontColor('#7C3AED')
            }.width('100%')
            Row() {
              Text('总时长 ' + this.formatDuration(Number(item.total_minutes))).fontSize(10).fontColor(this.subTextColor)
            }.width('100%').margin({ top: 2 })
          }
          .width('100%').padding(6).backgroundColor(this.cardColor).borderRadius(6).margin({ top: 3 })
        }, (item: DbRow): string => String(item.id))
      }

      // 情绪记录
      if (this.shareMood && this.diaryMoodRecords.length > 0) {
        Text('😊 情绪').fontSize(12).fontWeight(FontWeight.Bold).fontColor(this.textColor).width('100%').margin({ top: 8 })
        ForEach(this.diaryMoodRecords, (item: DbRow) => {
          Column() {
            Row() {
              Text(this.formatTime(Number(item.timestamp))).fontSize(10).fontColor(this.accentColor)
              Blank()
              Text(this.getMoodEmoji(Number(item.mood))).fontSize(18)
            }.width('100%')
            if (item.note && String(item.note).length > 0) {
              Text(String(item.note)).fontSize(11).fontColor(this.textColor)
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%').margin({ top: 3 })
            }
          }
          .width('100%').padding(6).backgroundColor(this.cardColor).borderRadius(6)
          .alignItems(HorizontalAlign.Start).margin({ top: 3 })
        }, (item: DbRow): string => String(item.id))
      }

      Text('来自「健康1st」').fontSize(9).fontColor(this.subTextColor).width('100%')
        .textAlign(TextAlign.Center).margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.bgColor)
    .borderRadius(12)
  }

  @Builder shareCheckItem(icon: ResourceStr, label: string, hasData: boolean, checked: boolean, onChange: (on: boolean) => void) {
    Row() {
      if (typeof icon === 'string') {
        Text(icon).fontSize(18)
      } else {
        Image(icon).width(18).height(18).fillColor(this.textColor)
      }
      Text(label).fontSize(14).fontColor(this.textColor).margin({ left: 8 })
      if (!hasData) {
        Text('（无记录）').fontSize(11).fontColor(this.subTextColor).margin({ left: 4 })
      }
      Blank()
      if (hasData) {
        Toggle({ type: ToggleType.Checkbox, isOn: checked })
          .selectedColor(this.accentColor)
          .onChange((isOn: boolean) => { onChange(isOn); })
      }
    }
    .width('100%').padding(12).backgroundColor(this.cardColor).borderRadius(10).margin({ bottom: 8 })
    .opacity(hasData ? 1 : 0.4)
  }

  // 辅助方法
  formatTime(timestamp: number | undefined): string {
    if (!timestamp) return '--:--';
    const date: Date = new Date(timestamp);
    const h: number = date.getHours();
    const m: number = date.getMinutes();
    return `${h < 10 ? '0' + h : h}:${m < 10 ? '0' + m : m}`;
  }

  formatNumber(num: number): string {
    if (num >= 10000) {
      return (num / 10000).toFixed(1) + '万';
    }
    return String(num);
  }

  formatDuration(minutes: number): string {
    if (minutes < 60) {
      return `${minutes}分钟`;
    }
    const h: number = Math.floor(minutes / 60);
    const m: number = minutes % 60;
    return m > 0 ? `${h}时${m}分` : `${h}小时`;
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

  getMoodEmoji(mood: number): string {
    const emojis: string[] = ['😢', '😔', '😐', '🙂', '😄'];
    return emojis[mood - 1] || '😐';
  }

  getScoreColor(score: number): string {
    if (score >= 80) return '#10B981';
    if (score >= 60) return '#F59E0B';
    return '#EF4444';
  }
}
