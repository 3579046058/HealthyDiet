import { router } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';

@Entry
@Component
struct SettingsPage {
  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') systemDark: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  themeLabel(): string {
    if (this.themeMode === 'dark') { return '深色模式'; }
    if (this.themeMode === 'light') { return '浅色模式'; }
    return '跟随系统';
  }

  toggleTheme(): void {
    const next: string = this.themeMode === 'dark' ? 'light' : (this.themeMode === 'light' ? 'follow' : 'dark');
    this.themeMode = next;
    GlobalData.prefs.setTheme(next);
    if (next === 'follow') {
      this.theme = this.systemDark ? 'dark' : 'light';
    } else {
      this.theme = next;
    }
    AppStorage.setOrCreate('currentTheme', this.theme);
  }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .accessibilityText('返回上一页')
          .accessibilityLevel('important')
          .onClick(() => { router.back(); })
        Text('设置').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      Scroll() {
        Column() {
          Text('通用设置').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 8 })

          this.settingItem('🔔', '通知设置', '喝水、久坐、用药提醒', () => { this.navigate('pages/NotificationPage'); })
          this.settingItem('🎯', '目标设置', '步数、喝水、运动、睡眠目标', () => { this.navigate('pages/GoalPage'); })
          this.settingItem('🎨', '主题切换', '当前：' + this.themeLabel(), () => { this.toggleTheme(); })
          this.settingItem('🔐', '权限管理', '管理运动、位置、蓝牙、健康数据等权限', () => { this.navigate('pages/PermissionPage'); })

          Text('关于').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, top: 20, bottom: 8 })

          this.settingItem('⭐', '评分标准', '查看健康评分规则说明', () => {
            this.showScoreRule();
          })
          this.settingItem('ℹ️', '关于', 'Harmony健康 v1.0', () => {
            this.showAbout();
          })
          this.settingItem('💾', '数据说明', '数据存储在本地数据库，无需联网。关机会保留。', () => {
            this.showDataInfo();
          })

          Divider().opacity(0).height(30)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  navigate(page: string): void {
    router.pushUrl({ url: page }).catch(() => {});
  }

  showScoreRule(): void {
    AlertDialog.show({
      title: '评分标准',
      message: '每项按完成率计分后加总：\n' +
        '· 步数（满分30）：完成率 × 30\n' +
        '· 喝水（满分30）：完成率 × 30\n' +
        '· 睡眠（满分20）：睡眠评分 × 0.2\n' +
        '· 运动（满分20）：运动分钟/60 × 20\n' +
        '· 饮食（±10）：摄入量在推荐热量的90%~110% 得满分 +10；' +
        '偏低递减；超标 110%~130% 扣8、130%~160% 扣15、超160% 扣20\n\n' +
        '短板加权：完成率最低的一项权重提升 1.5 倍，其余项按比例缩小，总分满分保持 100。\n\n' +
        '未记录的项目不参与评分；完全没有数据时显示 "--"。\n' +
        '总分范围 -100 ~ 100。',
      confirm: { value: '知道了', action: () => {} }
    });
  }

  showAbout(): void {
    AlertDialog.show({
      title: '关于',
      message: 'Harmony健康 v1.0\n一款个人健康管理应用\n开发：健康1st团队',
      confirm: { value: '知道了', action: () => {} }
    });
  }

  showDataInfo(): void {
    AlertDialog.show({
      title: '数据说明',
      message: '所有数据存储在您的设备本地数据库（SQLite），无需联网，关闭手机后数据依然保留。删除应用后数据将永久删除。',
      confirm: { value: '知道了', action: () => {} }
    });
  }

  @Builder settingItem(icon: string, title: string, desc: string, action: () => void) {
    Row() {
      Text(icon).fontSize(20)
      Column() {
        Text(title).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
        Text(desc).fontSize(11).fontColor(this.sub()).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
      Text('›').fontSize(20).fontColor(this.sub())
    }
    .width('100%').padding(14).backgroundColor(this.card()).borderRadius(12)
    .margin({ left: 16, right: 16, bottom: 8 })
    .onClick(() => { action(); })
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
