import { GlobalData } from '../common/GlobalData';

@Component
export struct WeightOverlay {
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop overlayGenders: string[] = ['男', '女'];
  @Prop overlayGender: string = '男';
  @Prop overlayHeightInput: string = '170';
  @Prop overlayWeightInput: string = '70';
  @Prop overlaySkipNext: boolean = false;
  onGenderChange: (v: string) => void = () => {};
  onHeightChange: (v: string) => void = () => {};
  onWeightChange: (v: string) => void = () => {};
  onSkipChange: (on: boolean) => void = () => {};
  onSkip: () => void = () => {};
  onSave: () => void = () => {};

  build() {
    Column() {
      Blank()
      Column() {
        Text('完善你的个人信息').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').margin({ bottom: 8 })

        Text('身高、体重、性别用于计算 BMI 和运动热量').fontSize(12).fontColor(this.subTextColor)
          .width('100%').margin({ bottom: 20 })

        Text('性别').fontSize(14).fontColor(this.textColor).width('100%').margin({ bottom: 8 })
        Row() {
          ForEach(this.overlayGenders, (item: string) => {
            Text(item)
              .fontSize(15)
              .fontColor(this.overlayGender === item ? Color.White : this.subTextColor)
              .backgroundColor(this.overlayGender === item ? '#FF6B35' : this.cardColor)
              .borderRadius(20).padding({ left: 28, right: 28, top: 10, bottom: 10 })
              .margin({ right: 12 })
              .onClick(() => { this.onGenderChange(item); })
          })
        }
        .width('100%')
        .margin({ bottom: 18 })

        Text('身高').fontSize(14).fontColor(this.textColor).width('100%').margin({ bottom: 8 })
        Row() {
          TextInput({ placeholder: '170', text: this.overlayHeightInput })
            .type(InputType.Number).layoutWeight(1).height(46)
            .backgroundColor(this.cardColor).fontColor(this.textColor).placeholderColor(this.subTextColor)
            .borderRadius(10)
            .onChange((v: string) => { this.onHeightChange(v); })
          Text('cm').fontSize(14).fontColor(this.subTextColor).margin({ left: 10 })
        }
        .width('100%')
        .margin({ bottom: 18 })

        Text('体重').fontSize(14).fontColor(this.textColor).width('100%').margin({ bottom: 8 })
        Row() {
          TextInput({ placeholder: '70', text: this.overlayWeightInput })
            .type(InputType.Number).layoutWeight(1).height(46)
            .backgroundColor(this.cardColor).fontColor(this.textColor).placeholderColor(this.subTextColor)
            .borderRadius(10)
            .onChange((v: string) => { this.onWeightChange(v); })
          Text('kg').fontSize(14).fontColor(this.subTextColor).margin({ left: 10 })
        }
        .width('100%')

        Row() {
          Text('设置后不再弹出').fontSize(13).fontColor(this.subTextColor)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.overlaySkipNext })
            .selectedColor('#FF6B35')
            .onChange((on: boolean) => { this.onSkipChange(on); })
        }
        .width('100%').margin({ top: 20 })

        Row() {
          Button('暂不设置').layoutWeight(1).height(46)
            .backgroundColor('#555555').borderRadius(23)
            .fontColor(Color.White).fontSize(15)
            .onClick(() => { this.onSkip(); })
          Button('保存').layoutWeight(1).height(46)
            .backgroundColor('#FF6B35').borderRadius(23)
            .fontColor(Color.White).fontSize(15)
            .margin({ left: 12 })
            .onClick(() => { this.onSave(); })
        }
        .width('100%').margin({ top: 24 })
      }
      .width('88%')
      .padding(24)
      .backgroundColor(this.cardColor)
      .borderRadius(18)
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.7)')
  }
}

@Component
export struct MoodOverlay {
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop overlayMoodDate: string = '';
  @Prop overlayMood: number = 3;
  @Prop overlayMoodNote: string = '';
  onMoodChange: (mood: number) => void = () => {};
  onNoteChange: (v: string) => void = () => {};
  onCancel: () => void = () => {};
  onSave: () => void = () => {};

  getMoodEmoji(moodVal: number): string {
    if (moodVal >= 4.5) { return '😄'; }
    if (moodVal >= 3.5) { return '🙂'; }
    if (moodVal >= 2.5) { return '😐'; }
    if (moodVal >= 1.5) { return '😔'; }
    return '😢';
  }

  getMoodLabel(mood: number): string {
    if (mood === 5) { return '很好'; }
    if (mood === 4) { return '不错'; }
    if (mood === 3) { return '一般'; }
    if (mood === 2) { return '不好'; }
    return '很差';
  }

  build() {
    Column() {
      Blank()
      Column() {
        Text('记录心情').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          .width('100%').margin({ bottom: 4 })

        Text(this.overlayMoodDate.length > 0 ? this.overlayMoodDate : '--').fontSize(14).fontColor(this.subTextColor)
          .width('100%').margin({ bottom: 16 })

        Text('今天心情怎么样？').fontSize(14).fontColor(this.textColor)
          .width('100%').margin({ bottom: 14 })

        Row() {
          ForEach([1, 2, 3, 4, 5], (mood: number) => {
            Column() {
              Text(this.getMoodEmoji(mood)).fontSize(32).lineHeight(40)
              Text(this.getMoodLabel(mood)).fontSize(11).fontColor(this.subTextColor).margin({ top: 2 })
            }
            .width(54).height(78)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .borderRadius(10)
            .backgroundColor(this.overlayMood === mood ? '#FFC107' : this.cardColor)
            .border({ width: 2, color: this.overlayMood === mood ? '#FFC107' : this.cardColor, style: BorderStyle.Solid })
            .onClick(() => { this.onMoodChange(mood); })
          }, (mood: number): string => mood.toString())
        }
        .width('100%').justifyContent(FlexAlign.SpaceEvenly)

        TextArea({ placeholder: '说点什么吧', text: this.overlayMoodNote })
          .width('100%').height(80)
          .backgroundColor(this.cardColor)
          .placeholderColor('#888888')
          .fontColor(Color.White).borderRadius(10).padding(10)
          .onChange((value: string) => { this.onNoteChange(value); })
          .margin({ top: 16 })

        Row() {
          Button('稍后').layoutWeight(1).height(46)
            .backgroundColor(this.cardColor).borderRadius(23)
            .fontColor(this.textColor).fontSize(15)
            .onClick(() => { this.onCancel(); })
          Button('保存').layoutWeight(1).height(46)
            .backgroundColor('#FFC107').fontColor('#0D0D1A')
            .fontWeight(FontWeight.Bold).borderRadius(23)
            .fontSize(15).margin({ left: 12 })
            .onClick(() => { this.onSave(); })
        }
        .width('100%').margin({ top: 20 })
      }
      .width('88%')
      .padding(24)
      .backgroundColor(this.cardColor)
      .borderRadius(18)
      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.7)')
  }
}
