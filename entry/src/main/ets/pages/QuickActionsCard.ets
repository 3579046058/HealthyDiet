/**
 * 桌面快捷健康卡片（2*4）
 * 功能：快速记录喝水、入睡/醒来 + 今日三环 + 健康评分
 * 深浅色跟随系统（colorMode: auto + 资源限定符）
 */
@Entry
@Component
struct QuickActionsCard {
  @LocalStorageProp('waterMl') waterMl: string = '0'
  @LocalStorageProp('waterGoal') waterGoal: string = '2000'
  @LocalStorageProp('stepPercent') stepPercent: string = '0'
  @LocalStorageProp('sleepPercent') sleepPercent: string = '0'
  @LocalStorageProp('moodPercent') moodPercent: string = '0'
  @LocalStorageProp('stepValue') stepValue: string = '--'
  @LocalStorageProp('sleepValue') sleepValue: string = '--'
  @LocalStorageProp('moodValue') moodValue: string = '--'
  @LocalStorageProp('healthScore') healthScore: string = '0'
  @LocalStorageProp('scoreColor') scoreColor: string = '#4CAF50'
  @LocalStorageProp('isSleeping') isSleeping: string = 'false'

  postAction(action: string): void {
    console.info('CardAction clicked: ' + action)
    postCardAction(this, {
      action: 'message',
      params: { action: action }
    })
  }

  postRouter(page: string): void {
    console.info('CardAction router: ' + page)
    postCardAction(this, {
      action: 'router',
      abilityName: 'EntryAbility',
      params: { targetPage: page }
    })
  }

  build() {
    Column() {
      // 主区：左到右 = 评分 | 数据 | 三环
      Row() {
        // 左侧：评分
        Column() {
          Text('健康评分')
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
          Text(this.healthScore)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.scoreColor)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 中间：数据竖排
        Column() {
          Row() {
            Text('●').fontSize(8).fontColor('#FF6B35')
            Text('步数 ' + this.stepValue).fontSize(10).fontColor($r('app.color.text_primary')).margin({ left: 4 })
          }
          .width('100%')
          Row() {
            Text('●').fontSize(8).fontColor('#9C27B0')
            Text('睡眠 ' + this.sleepValue).fontSize(10).fontColor($r('app.color.text_primary')).margin({ left: 4 })
          }
          .width('100%')
          .margin({ top: 4 })
          Row() {
            Text('●').fontSize(8).fontColor('#FFC107')
            Text('心情 ' + this.moodValue).fontSize(10).fontColor($r('app.color.text_primary')).margin({ left: 4 })
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        // 右侧：三环叠加
        Stack() {
          Progress({ value: Number(this.stepPercent), total: 100, type: ProgressType.Ring })
            .width(60)
            .height(60)
            .color('#FF6B35')
            .backgroundColor('#33FF6B35')
            .style({ strokeWidth: 5 })
          Progress({ value: Number(this.sleepPercent), total: 100, type: ProgressType.Ring })
            .width(45)
            .height(45)
            .color('#9C27B0')
            .backgroundColor('#339C27B0')
            .style({ strokeWidth: 4 })
          Progress({ value: Number(this.moodPercent), total: 100, type: ProgressType.Ring })
            .width(30)
            .height(30)
            .color('#FFC107')
            .backgroundColor('#33FFC107')
            .style({ strokeWidth: 4 })
        }
        .width(60)
        .height(60)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 快捷按钮区
      Row() {
        // 喝水按钮
        Column() {
          Text('💧')
            .fontSize(20)
          Text('喝水')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
          Text(this.waterMl + '/' + this.waterGoal)
            .fontSize(8)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height(64)
        .borderRadius(10)
        .backgroundColor('#2203A9F4')
        .justifyContent(FlexAlign.Center)
        .margin({ right: 10 })
        .onClick(() => { this.postRouter('WaterPage') })

        // 入睡/醒来按钮
        Column() {
          Text(this.isSleeping === 'true' ? '😴' : '🌙')
            .fontSize(20)
          Text(this.isSleeping === 'true' ? '醒来' : '入睡')
            .fontSize(10)
            .fontColor($r('app.color.text_secondary'))
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .height(64)
        .borderRadius(10)
        .backgroundColor('#229C27B0')
        .justifyContent(FlexAlign.Center)
        .onClick(() => { this.postRouter('SleepPage') })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor($r('app.color.card_bg'))
  }
}
