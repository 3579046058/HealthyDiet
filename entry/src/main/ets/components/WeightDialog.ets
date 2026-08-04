import { GlobalData } from '../common/GlobalData';
import { ThemeColors } from '../common/Constants';

@CustomDialog
export struct WeightDialog {
  controller: CustomDialogController;
  @StorageLink('currentTheme') theme: string = 'dark';
  @State heightInput: string = '170';
  @State weightInput: string = '70';
  @State gender: string = '男';
  @State skipNext: boolean = false;
  readonly genders: string[] = ['男', '女'];

  get bg(): string { return ThemeColors.bg(this.theme); }
  get card(): string { return ThemeColors.card(this.theme); }
  get txt(): string { return ThemeColors.text(this.theme); }
  get sub(): string { return ThemeColors.subText(this.theme); }

  // 弹窗固定深色样式：深色背景 + 白色文字，任何主题下都清晰
  get dialogTxt(): string { return '#FFFFFF'; }
  get dialogSub(): string { return '#AAAAAA'; }
  get dialogCard(): string { return '#1E1E2E'; }
  get dialogBg(): string { return '#1A1A2E'; }

  aboutToAppear(): void {
    GlobalData.prefs.getGoalConfig().then((config) => {
      if (config.heightCm > 0) {
        this.heightInput = String(config.heightCm);
      }
      if (config.weightKg > 0) {
        this.weightInput = String(config.weightKg);
      }
    });
    GlobalData.prefs.getGender().then((g: string) => {
      if (g.length > 0) {
        this.gender = g;
      }
    });
  }

  async onConfirm(): Promise<void> {
    const h = parseInt(this.heightInput);
    const w = parseFloat(this.weightInput);
    if (!isNaN(h) && h > 0 && !isNaN(w) && w > 0) {
      const config = await GlobalData.prefs.getGoalConfig();
      config.heightCm = h;
      config.weightKg = w;
      await GlobalData.prefs.saveGoalConfig(config);
      await GlobalData.prefs.setWeight(w);
      await GlobalData.prefs.setGender(this.gender);
    }
    await GlobalData.prefs.markWeightConfigured();
    await GlobalData.prefs.setWeightSkipPrompt(this.skipNext);
    this.controller.close();
  }

  build() {
    Column() {
      Text('完善你的个人信息').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.dialogTxt)
        .width('100%').margin({ bottom: 4 })

      Text('身高、体重、性别用于计算 BMI 和运动热量').fontSize(12).fontColor(this.dialogSub)
        .width('100%').margin({ bottom: 16 })

      // 性别
      Text('性别').fontSize(13).fontColor(this.dialogSub).width('100%').margin({ bottom: 6 })
      Row() {
        ForEach(this.genders, (item: string) => {
          Text(item)
            .fontSize(14)
            .fontColor(this.gender === item ? '#FFFFFF' : this.dialogSub)
            .backgroundColor(this.gender === item ? '#FF6B35' : this.dialogCard)
            .borderRadius(18).padding({ left: 22, right: 22, top: 8, bottom: 8 })
            .margin({ right: 10 })
            .onClick(() => { this.gender = item; })
        })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 身高
      Row() {
        TextInput({ placeholder: '170', text: this.heightInput })
          .type(InputType.Number).layoutWeight(1).height(44)
          .backgroundColor('#2A2A3E')
          .fontColor(this.dialogTxt).placeholderColor(this.dialogSub)
          .onChange((v: string) => { this.heightInput = v; })
        Text('cm').fontSize(14).fontColor(this.dialogSub).margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // 体重
      Row() {
        TextInput({ placeholder: '70', text: this.weightInput })
          .type(InputType.Number).layoutWeight(1).height(44)
          .backgroundColor('#2A2A3E')
          .fontColor(this.dialogTxt).placeholderColor(this.dialogSub)
          .onChange((v: string) => { this.weightInput = v; })
        Text('kg').fontSize(14).fontColor(this.dialogSub).margin({ left: 8 })
      }
      .width('100%')

      Row() {
        Text('设置后不再弹出').fontSize(13).fontColor(this.dialogSub)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.skipNext })
          .selectedColor('#FF6B35')
          .onChange((on: boolean) => { this.skipNext = on; })
      }
      .width('100%').margin({ top: 16 })

      Row() {
        Button('暂不设置').layoutWeight(1).height(44)
          .backgroundColor('#555555').borderRadius(22)
          .fontColor(this.dialogTxt).fontSize(15)
          .onClick(() => {
            GlobalData.prefs.setWeightSkipPrompt(this.skipNext);
            this.controller.close();
          })
        Button('保存').layoutWeight(1).height(44)
          .backgroundColor('#FF6B35').borderRadius(22)
          .fontColor(Color.White).fontSize(15)
          .margin({ left: 12 })
          .onClick(() => { this.onConfirm(); })
      }
      .width('100%').margin({ top: 20 })
    }
    .width('100%').padding(20)
    .backgroundColor(this.dialogBg).borderRadius(16)
  }
}
