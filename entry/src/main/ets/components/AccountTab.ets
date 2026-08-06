import { Constants } from '../common/Constants';
import { AchievementInfo, AchievementHelper, ACHIEVEMENT_LEVELS } from '../model/AchievementHelper';
import { GlobalData } from '../common/GlobalData';
import { DataBackupHelper } from '../model/DataBackupHelper';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

@Component
export struct AccountTab {
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @StorageLink('dataUpdateTrigger') @Watch('onDataUpdate') dataUpdateTrigger: string = '';
  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') systemDark: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
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
  @State showBackupDialog: boolean = false; // 控制数据备份弹窗显示
  @State backupStatus: string = ''; // 备份状态提示
  
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

  // 主题切换
  toggleTheme(): void {
    const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
    this.themeMode = next;
    GlobalData.prefs.setTheme(next);
    if (next !== 'follow') {
      this.theme = next;
      AppStorage.setOrCreate('currentTheme', next);
    } else {
      const resolved: string = this.systemDark ? 'dark' : 'light';
      this.theme = resolved;
      AppStorage.setOrCreate('currentTheme', resolved);
    }
    console.info('THEME toggle next=' + next + ' currentTheme=' + AppStorage.get<string>('currentTheme'));
  }

  // 获取主题状态文字
  themeLabel(): string {
    if (this.themeMode === 'dark') { return '深色模式'; }
    if (this.themeMode === 'light') { return '浅色模式'; }
    return '跟随系统（' + (this.systemDark ? '深色' : '浅色') + '）';
  }
  
  async loadAchievements(): Promise<void> {
    try {
      this.achievements = await this.achievementHelper.getAllAchievements();
      this.unlockedCount = this.achievements.filter(a => a.unlocked).length;
    } catch (err) {
      console.error('loadAchievements error:', JSON.stringify(err));
    }
  }

  // 导出数据
  async exportData(): Promise<void> {
    try {
      this.backupStatus = '正在导出数据...';
      const dbHelper = GlobalData.db;
      const context = getContext(this) as common.UIAbilityContext;
      const backupHelper = new DataBackupHelper(dbHelper, context);
      
      const filePath = await backupHelper.saveBackupFile();
      this.backupStatus = '导出成功！';
      
      promptAction.showToast({
        message: '数据导出成功！文件已保存',
        duration: 2000
      });
      
      console.info('数据导出成功，文件路径:', filePath);
    } catch (error) {
      this.backupStatus = '导出失败';
      console.error('导出数据失败:', error);
      promptAction.showToast({
        message: '导出失败，请重试',
        duration: 2000
      });
    }
  }

  // 导入数据
  async importData(): Promise<void> {
    try {
      this.backupStatus = '正在导入数据...';
      const dbHelper = GlobalData.db;
      const context = getContext(this) as common.UIAbilityContext;
      const backupHelper = new DataBackupHelper(dbHelper, context);

      // 通过文件选择器选择备份文件并读取
      const jsonData: string = await backupHelper.pickAndReadBackupFile();
      if (jsonData.length > 0) {
        // 旧版纯 JSON 备份：执行导入
        await backupHelper.importData(jsonData);
      }
      this.backupStatus = '';
      promptAction.showToast({ message: '数据导入成功！', duration: 2000 });
      console.info('数据导入成功');
    } catch (error) {
      this.backupStatus = '';
      console.error('导入数据失败:', error);
      promptAction.showToast({
        message: '导入失败，请确认选择的是备份文件',
        duration: 2500
      });
    }
  }

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('账号').fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.textColor)
          Blank()
          if (this.themeMode === 'dark') {
            Image($r('app.media.ic_theme_dark')).width(26).height(26).margin({ right: 12 }).supportSvg2(true)
              .accessibilityText(this.themeLabel())
              .accessibilityLevel('important')
              .onClick(() => {
                // 先计算下一个主题模式
                const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
                this.toggleTheme();
                // 显示切换后的主题状态
                const label = next === 'dark' ? '深色模式' : (next === 'light' ? '浅色模式' : '跟随系统');
                promptAction.showToast({ message: '已切换到：' + label, duration: 1500 });
              })
          } else if (this.themeMode === 'light') {
            Image($r('app.media.ic_theme_light')).width(26).height(26).margin({ right: 12 }).supportSvg2(true)
              .accessibilityText(this.themeLabel())
              .accessibilityLevel('important')
              .onClick(() => {
                // 先计算下一个主题模式
                const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
                this.toggleTheme();
                // 显示切换后的主题状态
                const label = next === 'dark' ? '深色模式' : (next === 'light' ? '浅色模式' : '跟随系统');
                promptAction.showToast({ message: '已切换到：' + label, duration: 1500 });
              })
          } else {
            Image($r('app.media.ic_theme_auto')).width(26).height(26).margin({ right: 12 }).supportSvg2(true)
              .accessibilityText(this.themeLabel())
              .accessibilityLevel('important')
              .onClick(() => {
                // 先计算下一个主题模式
                const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
                this.toggleTheme();
                // 显示切换后的主题状态
                const label = next === 'dark' ? '深色模式' : (next === 'light' ? '浅色模式' : '跟随系统');
                promptAction.showToast({ message: '已切换到：' + label, duration: 1500 });
              })
          }
        }
        .width('100%').padding({ left: 20, right: 20, top: 16 + this.statusBarHeight, bottom: 16 })

        Row() {
          Stack() {
            Circle().width(56).height(56).fill(this.isLoggedIn ? '#CF0A2C' : '#555555')
            if (this.isLoggedIn && this.userName.length > 0) {
              Text(this.userName.charAt(0)).fontSize(26).fontColor(Color.White)
            } else {
              Image($r('app.media.ic_account')).width(32).height(32).fillColor(Color.White)
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

        this.accountMenuItem($r('app.media.ic_account'), '个人信息', '身高、体重、性别设置', () => { this.onNavigate(Constants.PAGE_PROFILE); })
        this.accountMenuItem($r('app.media.ic_settings'), '设置', '通知、目标、主题、关于', () => { this.onNavigate(Constants.PAGE_SETTINGS); })
        this.accountMenuItem($r('app.media.ic_report'), '健康报告', '查看周报月报', () => { this.onNavigate(Constants.PAGE_REPORT); })
        this.accountMenuItem($r('app.media.ic_music'), '音乐播放器', '播放本地音乐', () => { this.onNavigate(Constants.PAGE_MUSIC); })
        this.accountMenuItem($r('app.media.ic_delete'), '回收站', '恢复已删除的数据', () => { this.onNavigate(Constants.PAGE_RECYCLE_BIN); })
        this.accountMenuItem($r('app.media.ic_save'), '数据备份', '导出/导入健康数据', () => { this.showBackupDialog = true; })

        // 补录达标天数
        Row() {
          Image($r('app.media.ic_calendar')).width(22).height(22).fillColor(this.textColor)
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
          Image($r('app.media.ic_trophy_color'))
            .width(24).height(24)
            .supportSvg2(true)
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

        // 数据备份弹窗（内部判断 showBackupDialog）
        this.backupDialog()
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
        Image($r('app.media.ic_trophy_color'))
          .width(26).height(26)
          .supportSvg2(true)
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

      // 数据备份弹窗（独立于成就弹窗）
      this.backupDialog()
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
                    Image($r('app.media.ic_trophy_color'))
                      .width(64).height(64)
                      .supportSvg2(true)
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
                  Row() {
                    Image($r('app.media.ic_check_circle')).width(18).height(18).fillColor('#4CAF50')
                    Text('已解锁')
                      .fontSize(18)
                      .fontColor('#4CAF50')
                      .fontWeight(FontWeight.Bold)
                      .margin({ left: 6 })
                  }
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
                  Row() {
                    Image($r('app.media.ic_lock')).width(18).height(18).fillColor(this.subTextColor)
                    Text('未解锁')
                      .fontSize(18)
                      .fontColor(this.subTextColor)
                      .fontWeight(FontWeight.Bold)
                      .margin({ left: 6 })
                  }
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

  @Builder backupDialog() {
    if (this.showBackupDialog) {
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
                .onClick(() => { 
                  this.showBackupDialog = false;
                  this.backupStatus = '';
                })
            }
            .width('100%')
            .padding(16)

            // 标题
            Text('数据备份与迁移')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.textColor)
              .margin({ top: 10, bottom: 20 })

            // 说明文字
            Text('将您的健康数据导出为JSON文件，方便备份或迁移到其他设备')
              .fontSize(14)
              .fontColor(this.subTextColor)
              .textAlign(TextAlign.Center)
              .margin({ bottom: 30 })
              .padding({ left: 20, right: 20 })

            // 状态提示
            if (this.backupStatus) {
              Text(this.backupStatus)
                .fontSize(14)
                .fontColor('#4CAF50')
                .margin({ bottom: 20 })
            }

            // 按钮区域
            Row() {
              // 导出按钮
              Column() {
                Image($r('app.media.ic_upload'))
                  .width(32).height(32)
                  .fillColor(this.textColor)
                  .margin({ bottom: 8 })
                Text('导出数据')
                  .fontSize(16)
                  .fontColor(this.textColor)
              }
              .width('40%')
              .padding(20)
              .backgroundColor(this.cardColor)
              .borderRadius(12)
              .onClick(() => { this.exportData(); })

              Blank().width('5%')

              // 导入按钮
              Column() {
                Image($r('app.media.ic_download'))
                  .width(32).height(32)
                  .fillColor(this.textColor)
                  .margin({ bottom: 8 })
                  .margin({ bottom: 8 })
                Text('导入数据')
                  .fontSize(16)
                  .fontColor(this.textColor)
              }
              .width('40%')
              .padding(20)
              .backgroundColor(this.cardColor)
              .borderRadius(12)
              .onClick(() => { this.importData(); })
            }
            .width('90%')
            .justifyContent(FlexAlign.Center)
            .margin({ bottom: 20 })

            // 提示信息
            Text('提示：导入数据将覆盖现有数据，请谨慎操作')
              .fontSize(12)
              .fontColor('#FF9800')
              .margin({ top: 10 })
          }
          .width('85%')
          .padding(20)
          .backgroundColor(this.cardColor)
          .borderRadius(20)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor('rgba(0, 0, 0, 0.7)')
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
      .onClick(() => { 
        this.showBackupDialog = false;
        this.backupStatus = '';
      })
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
          Image($r('app.media.ic_trophy_color'))
            .width(36).height(36)
            .supportSvg2(true)
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

  @Builder accountMenuItem(icon: ResourceStr, title: string, desc: string, action: () => void) {
    Row() {
      if (typeof icon === 'string') {
        Text(icon).fontSize(22)
      } else {
        Image(icon).width(22).height(22).fillColor(this.textColor)
      }
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
