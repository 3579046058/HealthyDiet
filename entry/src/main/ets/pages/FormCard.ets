 /**
  * 桌面 Widget 卡片页面
  * 显示步数、心率和饮水进度
  */
 @Entry
 @Component
 struct FormCard {
   @LocalStorageProp('steps') steps: string = ''
   @LocalStorageProp('stepGoal') stepGoal: string = ''
   @LocalStorageProp('stepPercent') stepPercent: string = ''
   @LocalStorageProp('heartRate') heartRate: string = ''
   @LocalStorageProp('waterMl') waterMl: string = ''
   @LocalStorageProp('date') date: string = ''
 
   build() {
     Column() {
       // 步数
       Row() {
         Text('👟')
           .fontSize(20)
         Text('步数')
           .fontSize(13)
           .fontColor('#FF9800')
           .margin({ left: 4 })
         Blank()
         Text(this.heartRate + ' bpm')
           .fontSize(13)
           .fontColor('#F44336')
       }
       .width('100%')
       .padding({ bottom: 6 })
 
       // 步数值
       Text(this.steps + ' / ' + this.stepGoal)
         .fontSize(22)
         .fontWeight(FontWeight.Bold)
         .width('100%')
 
       // 步数进度条
       Stack() {
         Row()
           .width('100%')
           .height(6)
           .backgroundColor('#333333')
           .borderRadius(3)
         Row()
           .width(this.stepPercent + '%')
           .height(6)
           .backgroundColor('#FF6B35')
           .borderRadius(3)
       }
       .width('100%')
       .margin({ top: 6 })
 
       // 饮水
       Row() {
         Text('💧')
           .fontSize(14)
         Text(this.waterMl + 'ml')
           .fontSize(12)
           .fontColor('#03A9F4')
           .margin({ left: 4 })
         Blank()
         Text(this.date)
           .fontSize(10)
           .fontColor('#666666')
       }
       .width('100%')
       .margin({ top: 8 })
     }
     .width('100%')
     .height('100%')
     .padding(12)
     .backgroundColor('#0D0D1A')
   }
 }
