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
        Row() {
          Text('分享我的健康日记').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
          Text('✕').fontSize(20).fontColor(this.subTextColor).onClick(() => { this.onClose(); })
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 })

        Text('选择要分享的内容').fontSize(12).fontColor(this.subTextColor).width('100%')
          .padding({ left: 20, top: 8, bottom: 8 })

        this.shareCheckItem('🍎', '饮食记录', this.diaryDietRecords.length > 0, this.shareDiet, (on: boolean) => { this.onDietChange(on); })
        this.shareCheckItem('🏃', '运动记录', this.diarySportRecords.length > 0, this.shareSport, (on: boolean) => { this.onSportChange(on); })
        this.shareCheckItem('😴', '睡眠记录', this.diarySleepRecords.length > 0, this.shareSleep, (on: boolean) => { this.onSleepChange(on); })
        this.shareCheckItem('😊', '情绪记录', this.diaryMoodRecords.length > 0, this.shareMood, (on: boolean) => { this.onMoodChange(on); })
        this.shareCheckItem('📊', '今日健康概览', true, this.shareOverview, (on: boolean) => { this.onOverviewChange(on); })

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

  @Builder shareCheckItem(icon: string, label: string, hasData: boolean, checked: boolean, onChange: (on: boolean) => void) {
    Row() {
      Text(icon).fontSize(18)
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
    .width('90%').padding(12).backgroundColor(this.cardColor).borderRadius(10).margin({ bottom: 8 })
    .opacity(hasData ? 1 : 0.4)
  }
}
