import { Constants } from '../common/Constants';
import { AchievementInfo, AchievementHelper, ACHIEVEMENT_LEVELS } from '../model/AchievementHelper';
import { GlobalData } from '../common/GlobalData';

@Component
export struct AccountTab {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @StorageLink('dataUpdateTrigger') @Watch('onDataUpdate') dataUpdateTrigger: string = '';
  @Prop textColor: string = '#FFFFFF';
  @Prop subTextColor: string = '#AAAAAA';
  @Prop cardColor: string = '#1E1E2E';
  @Prop isLoggedIn: boolean = false;
  @Prop userName: string = '';
  onNavigate: (page: string) => void = () => {};
  
  @State achievements: AchievementInfo[] = [];
  @State unlockedCount: number = 0;
  @State totalCount: number = ACHIEVEMENT_LEVELS.length;
  @State showAchievementDialog: boolean = false; // 控制成就弹窗显示
  @State selectedAchievement: AchievementInfo | null = null; // 选中的成就
  
  private achievementHelper: AchievementHelper = new AchievementHelper(GlobalData.prefs);
  
  aboutToAppear(): void {
    this.loadAchievements();
  }
  
  // 监听数据更新触发器
  onDataUpdate(): void {
    if (this.dataUpdateTrigger.length > 0) {
      this.loadAchievements();
    }
  }
  
  async loadAchievements(): Promise<void> {
    try {
      this.achievements = await this.achievementHelper.getAllAchievements();
      this.unlockedCount = this.achievements.filter(a => a.unlocked).length;
    } catch (err) {
      console.error('loadAchievements error:', JSON.stringify(err));
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('账号').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 + this.statusBarHeight, bottom: 16 })

        Row() {
          Stack() {
            Circle().width(56).height(56).fill(this.isLoggedIn ? '#CF0A2C' : '#555555')
            if (this.isLoggedIn && this.userName.length > 0) {
              Text(this.userName.charAt(0)).fontSize(26).fontColor(Color.White)
            } else {
              Text('👤').fontSize(24)
            }
          }
          Column() {
            Text(this.isLoggedIn && this.userName.length > 0 ? this.userName : '未登录')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor(this.textColor)
            Text(this.isLoggedIn ? 'HUAWEI 账号已绑定' : '登录后同步数据到云端')
              .fontSize(12).fontColor(this.subTextColor).margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 12 })
          Blank()
        }
        .width('100%').padding(16).backgroundColor(this.cardColor).borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 10 })
        .onClick(() => { this.onNavigate(Constants.PAGE_LOGIN); })

        this.accountMenuItem('👤', '个人信息', '身高、体重、性别设置', () => { this.onNavigate(Constants.PAGE_PROFILE); })
        this.accountMenuItem('⚙️', '设置', '通知、目标、主题、关于', () => { this.onNavigate(Constants.PAGE_SETTINGS); })
        this.accountMenuItem('📊', '健康报告', '查看周报月报', () => { this.onNavigate(Constants.PAGE_REPORT); })
        this.accountMenuItem('🗑️', '回收站', '恢复已删除的数据', () => { this.onNavigate(Constants.PAGE_RECYCLE_BIN); })

        // 补录达标天数
        Row() {
          Text('📅').fontSize(22)
          Column() {
            Text('补录达标天数').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
            Text('手动添加历史达标记录')
              .fontSize(11)
              .fontColor(this.subTextColor)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
          Text('›').fontSize(20).fontColor(this.subTextColor)
        }
        .width('100%').padding(14).backgroundColor(this.cardColor).borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 8 })
        .onClick(() => { this.onNavigate(Constants.PAGE_MAKEUP_DAYS); })

        // 成就墙（卡片样式）
        Row() {
          Text('🏆').fontSize(22)
          Column() {
            Text('我的成就墙').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
            Text(`已解锁 ${this.unlockedCount}/${this.totalCount} 个成就`)
              .fontSize(11)
              .fontColor(this.subTextColor)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
          Text('›').fontSize(20).fontColor(this.subTextColor)
        }
        .width('100%').padding(14).backgroundColor(this.cardColor).borderRadius(12)
        .margin({ left: 16, right: 16, bottom: 8 })
        .onClick(() => { this.showAchievementDialog = true; })

        Divider().opacity(0).height(24)
      }
      .width('100%')
    }
    .bindSheet($$this.showAchievementDialog, this.achievementSheet(), {
      height: '70%',
      backgroundColor: this.cardColor,
      dragBar: true,
      showClose: false
    })
  }

  // 成就弹窗内容
  @Builder achievementSheet() {
    Column() {
      // 标题
      Row() {
        Text('🏆')
          .fontSize(24)
        Text('我的成就墙')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .margin({ left: 8 })
        Blank()
        Text(`${this.unlockedCount}/${this.totalCount}`)
          .fontSize(14)
          .fontColor(this.subTextColor)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 16 })

      // 成就网格
      if (this.achievements.length > 0) {
        Scroll() {
          Grid() {
            ForEach(this.achievements, (achievement: AchievementInfo) => {
              GridItem() {
                this.achievementItem(achievement)
              }
            }, (achievement: AchievementInfo) => achievement.days.toString())
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsGap(16)
          .columnsGap(16)
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 20 })
        }
        .layoutWeight(1)
      } else {
        Column() {
          Text('暂无成就数据')
            .fontSize(16)
            .fontColor(this.subTextColor)
            .margin({ top: 40 })
        }
        .layoutWeight(1)
      }

      // 成就详情弹窗
      if (this.selectedAchievement) {
        this.achievementDetailDialog()
      }
    }
    .width('100%')
    .height('100%')
  }

  // 成就详情弹窗
  @Builder achievementDetailDialog() {
    if (this.selectedAchievement) {
      Column() {
        // 遮罩层
        Column() {
          Column() {
            // 关闭按钮
            Row() {
              Blank()
              Text('✕')
                .fontSize(20)
                .fontColor(this.subTextColor)
                .onClick(() => { this.selectedAchievement = null; })
            }
            .width('100%')
            .padding(16)

            // 成就奖牌
            Column() {
              Stack() {
                Circle()
                  .width(120)
                  .height(120)
                  .fill(this.selectedAchievement.unlocked ? '#FFD700' : '#333333')
                
                if (this.selectedAchievement.unlocked) {
                  Column() {
                    Text('🏆')
                      .fontSize(60)
                  }
                } else {
                  Column() {
                    Text(`${this.selectedAchievement.days}`)
                      .fontSize(32)
                      .fontColor('#666666')
                      .fontWeight(FontWeight.Bold)
                    Text('天')
                      .fontSize(16)
                      .fontColor('#666666')
                  }
                }
              }
              .margin({ top: 20 })

              // 成就名称
              Text(this.selectedAchievement.name)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.selectedAchievement.unlocked ? '#FFD700' : this.subTextColor)
                .margin({ top: 24 })

              // 成就描述
              Text(this.selectedAchievement.description)
                .fontSize(16)
                .fontColor(this.textColor)
                .margin({ top: 12 })
                .textAlign(TextAlign.Center)

              // 解锁状态
              if (this.selectedAchievement.unlocked) {
                Column() {
                  Text('🎉 已解锁')
                    .fontSize(18)
                    .fontColor('#4CAF50')
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: 20 })
                  
                  if (this.selectedAchievement.unlockDate) {
                    Text(`解锁时间：${this.formatDate(this.selectedAchievement.unlockDate)}`)
                      .fontSize(14)
                      .fontColor(this.subTextColor)
                      .margin({ top: 8 })
                  }
                }
              } else {
                Column() {
                  Text('🔒 未解锁')
                    .fontSize(18)
                    .fontColor(this.subTextColor)
                    .fontWeight(FontWeight.Bold)
                    .margin({ top: 20 })
                  
                  Text(`需要连续 ${this.selectedAchievement.days} 天`)
                    .fontSize(14)
                    .fontColor(this.subTextColor)
                    .margin({ top: 8 })
                }
              }
            }
            .padding({ bottom: 40 })
          }
          .width('85%')
          .backgroundColor(this.cardColor)
          .borderRadius(20)
          .padding(20)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.7)')
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .onClick(() => { this.selectedAchievement = null; })
    }
  }

  @Builder achievementItem(achievement: AchievementInfo) {
    Column() {
      // 成就图标
      Stack() {
        Circle()
          .width(60)
          .height(60)
          .fill(achievement.unlocked ? '#FFD700' : '#333333')
        
        if (achievement.unlocked) {
          // 已解锁：显示奖杯图标
          Text('🏆')
            .fontSize(32)
        } else {
          // 未解锁：显示天数
          Text(`${achievement.days}天`)
            .fontSize(14)
            .fontColor('#666666')
            .fontWeight(FontWeight.Bold)
        }
      }
      .margin({ top: 8 })

      // 成就名称
      Text(achievement.name)
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(achievement.unlocked ? this.textColor : this.subTextColor)
        .margin({ top: 8 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 成就描述
      Text(achievement.description)
        .fontSize(11)
        .fontColor(this.subTextColor)
        .margin({ top: 4 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 解锁时间
      if (achievement.unlocked && achievement.unlockDate) {
        Text(this.formatDate(achievement.unlockDate))
          .fontSize(10)
          .fontColor('#888888')
          .margin({ top: 4 })
      } else if (!achievement.unlocked) {
        Text('未解锁')
          .fontSize(10)
          .fontColor('#666666')
          .margin({ top: 4 })
      }
    }
    .width('100%')
    .padding(8)
    .backgroundColor(achievement.unlocked ? 'rgba(255, 215, 0, 0.1)' : 'transparent')
    .borderRadius(8)
    .border({
      width: achievement.unlocked ? 2 : 1,
      color: achievement.unlocked ? '#FFD700' : '#333333'
    })
    .onClick(() => {
      this.selectedAchievement = achievement;
    })
  }

  formatDate(dateStr: string): string {
    try {
      const date = new Date(dateStr);
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, '0');
      const day = String(date.getDate()).padStart(2, '0');
      return `${year}-${month}-${day}`;
    } catch (err) {
      return dateStr;
    }
  }

  @Builder accountMenuItem(icon: string, title: string, desc: string, action: () => void) {
    Row() {
      Text(icon).fontSize(22)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.textColor)
        Text(desc).fontSize(11).fontColor(this.subTextColor).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.subTextColor)
    }
    .width('100%').padding(14).backgroundColor(this.cardColor).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(() => { action(); })
  }
}
