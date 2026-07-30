 import { router } from '@kit.ArkUI';
 import { GlobalData } from '../common/GlobalData';
 import { GoalConfig } from '../common/Constants';
 
 @Entry
 @Component
 struct GoalPage {
   @State stepsGoal: string = '8000';
   @State waterGoal: string = '2000';
   @State sportDays: string = '3';
   @State sleepHours: string = '8';
   @State weightGoal: string = '70';
 
   aboutToAppear(): void {
     this.loadGoals();
   }
 
   async loadGoals(): Promise<void> {
     try {
       const config: GoalConfig = await GlobalData.prefs.getGoalConfig();
       this.stepsGoal = String(config.dailySteps);
       this.waterGoal = String(config.dailyWaterMl);
       this.sportDays = String(config.weeklySportDays);
       this.sleepHours = String(config.sleepHours);
       this.weightGoal = String(config.weightKg);
     } catch (err) {
       console.error('GoalPage load error:', JSON.stringify(err));
     }
   }
 
   async saveGoals(): Promise<void> {
     await GlobalData.prefs.saveGoalConfig({
       dailySteps: parseInt(this.stepsGoal) || 8000,
       dailyWaterMl: parseInt(this.waterGoal) || 2000,
       weeklySportDays: parseInt(this.sportDays) || 3,
       sleepHours: parseFloat(this.sleepHours) || 8,
       weightKg: parseFloat(this.weightGoal) || 70,
     });
     // 返回首页
     router.back();
   }
 
   @Builder goalInput(label: string, value: string, unit: string, onChange: (v: string) => void) {
     Row() {
       Text(label).fontSize(15).fontColor('#CCCCCC').width(90)
       TextInput({ placeholder: value, text: value })
         .type(InputType.Number)
         .width(140).height(44)
         .onChange((v: string) => { onChange(v); })
       Text(unit).fontSize(14).fontColor('#888888').margin({ left: 8 })
       Blank()
     }
     .width('100%').padding(12)
   }
 
   build() {
     Column() {
       Row() {
         Text('←').fontSize(22).onClick(() => { router.back(); })
         Text('目标设置').fontSize(20).fontWeight(FontWeight.Bold).margin({ left: 12 })
         Blank()
       }
       .width('100%').padding(16)
 
       Scroll() {
         Column() {
           // 目标卡片
           Column() {
             Text('每日步数目标').fontSize(16).fontWeight(FontWeight.Bold)
               .width('100%').padding({ left: 12, top: 12 })
             Row() {
               Text('步数').fontSize(15).fontColor('#CCCCCC').width(90)
               TextInput({ placeholder: this.stepsGoal, text: this.stepsGoal })
                 .type(InputType.Number).width(140).height(44)
                 .onChange((v: string) => { this.stepsGoal = v; })
               Text('步').fontSize(14).fontColor('#888888').margin({ left: 8 })
               Blank()
             }
             .width('100%').padding(12)
           }
           .width('100%').padding(8).backgroundColor('#1A1A2E').borderRadius(14)
           .margin({ left: 16, right: 16, bottom: 12 })
 
           Column() {
             Text('每日喝水目标').fontSize(16).fontWeight(FontWeight.Bold)
               .width('100%').padding({ left: 12, top: 12 })
             Row() {
               Text('喝水').fontSize(15).fontColor('#CCCCCC').width(90)
               TextInput({ placeholder: this.waterGoal, text: this.waterGoal })
                 .type(InputType.Number).width(140).height(44)
                 .onChange((v: string) => { this.waterGoal = v; })
               Text('ml').fontSize(14).fontColor('#888888').margin({ left: 8 })
               Blank()
             }
             .width('100%').padding(12)
           }
           .width('100%').padding(8).backgroundColor('#1A1A2E').borderRadius(14)
           .margin({ left: 16, right: 16, bottom: 12 })
 
           Column() {
             Text('每周运动天数').fontSize(16).fontWeight(FontWeight.Bold)
               .width('100%').padding({ left: 12, top: 12 })
             Row() {
               Text('运动').fontSize(15).fontColor('#CCCCCC').width(90)
               TextInput({ placeholder: this.sportDays, text: this.sportDays })
                 .type(InputType.Number).width(140).height(44)
                 .onChange((v: string) => { this.sportDays = v; })
               Text('天/周').fontSize(14).fontColor('#888888').margin({ left: 8 })
               Blank()
             }
             .width('100%').padding(12)
           }
           .width('100%').padding(8).backgroundColor('#1A1A2E').borderRadius(14)
           .margin({ left: 16, right: 16, bottom: 12 })
 
           Column() {
             Text('每日睡眠目标').fontSize(16).fontWeight(FontWeight.Bold)
               .width('100%').padding({ left: 12, top: 12 })
             Row() {
               Text('睡眠').fontSize(15).fontColor('#CCCCCC').width(90)
               TextInput({ placeholder: this.sleepHours, text: this.sleepHours })
                 .type(InputType.Number).width(140).height(44)
                 .onChange((v: string) => { this.sleepHours = v; })
               Text('小时').fontSize(14).fontColor('#888888').margin({ left: 8 })
               Blank()
             }
             .width('100%').padding(12)
           }
           .width('100%').padding(8).backgroundColor('#1A1A2E').borderRadius(14)
           .margin({ left: 16, right: 16, bottom: 12 })
 
           Column() {
             Text('目标体重').fontSize(16).fontWeight(FontWeight.Bold)
               .width('100%').padding({ left: 12, top: 12 })
             Row() {
               Text('体重').fontSize(15).fontColor('#CCCCCC').width(90)
               TextInput({ placeholder: this.weightGoal, text: this.weightGoal })
                 .type(InputType.Number).width(140).height(44)
                 .onChange((v: string) => { this.weightGoal = v; })
               Text('kg').fontSize(14).fontColor('#888888').margin({ left: 8 })
               Blank()
             }
             .width('100%').padding(12)
           }
           .width('100%').padding(8).backgroundColor('#1A1A2E').borderRadius(14)
           .margin({ left: 16, right: 16, bottom: 12 })
 
           // 保存按钮
           Button() {
             Text('保存目标').fontSize(18).fontColor('#FFFFFF')
           }
           .width('90%').height(52).backgroundColor('#FF6B35').borderRadius(26)
           .margin({ top: 20, bottom: 40 })
           .onClick(() => { this.saveGoals(); })
         }
         .width('100%')
       }
     }
     .width('100%').height('100%').backgroundColor('#0D0D1A')
   }
 }
