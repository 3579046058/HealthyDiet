import { GlobalData } from '../common/GlobalData';
import { ThemeColors } from '../common/Constants';

@CustomDialog
export struct WeightDialog {
  controller: CustomDialogController;
  @StorageLink('currentTheme') theme: string = 'dark';
  @State weightInput: string = '70';
  @State skipNext: boolean = false;

  get bg(): string { return ThemeColors.bg(this.theme); }
  get card(): string { return ThemeColors.card(this.theme); }
  get txt(): string { return ThemeColors.text(this.theme); }
  get sub(): string { return ThemeColors.subText(this.theme); }

  async onConfirm(): Promise<void> {
    const val = parseFloat(this.weightInput);
    if (!isNaN(val) && val > 0) {
      const config = await GlobalData.prefs.getGoalConfig();
      config.weightKg = val;
      await GlobalData.prefs.saveGoalConfig(config);
      await GlobalData.prefs.setWeight(val);
      await GlobalData.prefs.markWeightConfigured();
    } else {
      await GlobalData.prefs.markWeightConfigured();
    }
    await GlobalData.prefs.setWeightSkipPrompt(this.skipNext);
    this.controller.close();
  }

  build() {
    Column() {
      Text('设置你的体重').fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.txt)
        .width('100%').margin({ bottom: 8 })

      Text('运动热量、活动消耗等需要体重数据来计算').fontSize(12).fontColor(this.sub)
        .width('100%').margin({ bottom: 16 })

      Row() {
        TextInput({ placeholder: '70', text: this.weightInput })
          .type(InputType.Number).layoutWeight(1).height(44)
          .backgroundColor(ThemeColors.inputBg(this.theme))
          .fontColor(this.txt).placeholderColor(this.sub)
          .onChange((v: string) => { this.weightInput = v; })
        Text('kg').fontSize(14).fontColor(this.sub).margin({ left: 8 })
      }
      .width('100%')

      Row() {
        Text('设置后不再弹出').fontSize(13).fontColor(this.sub)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: this.skipNext })
          .selectedColor('#FF6B35')
          .onChange((on: boolean) => { this.skipNext = on; })
      }
      .width('100%').margin({ top: 16 })

      Row() {
        Button('暂不设置').layoutWeight(1).height(44)
          .backgroundColor('#555555').borderRadius(22)
          .fontColor(this.txt).fontSize(15)
          .onClick(() => {
            GlobalData.prefs.setWeightSkipPrompt(this.skipNext);
            this.controller.close();
          })
        Button('确定').layoutWeight(1).height(44)
          .backgroundColor('#FF6B35').borderRadius(22)
          .fontColor(Color.White).fontSize(15)
          .margin({ left: 12 })
          .onClick(() => { this.onConfirm(); })
      }
      .width('100%').margin({ top: 20 })
    }
    .width('100%').padding(20)
    .backgroundColor(this.bg).borderRadius(16)
  }
}
