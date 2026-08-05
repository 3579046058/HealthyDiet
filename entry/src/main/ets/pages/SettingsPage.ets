import { router, promptAction } from '@kit.ArkUI';
import { ThemeColors } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { ChatService } from '../services/ChatService';
import { FoodRecognitionService } from '../services/FoodRecognitionService';

@Entry
@Component
struct SettingsPage {
  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') systemDark: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State apiKeyInput: string = '';
  @State keyStatus: string = '';

  aboutToAppear(): void {
    this.refreshKeyStatus();
  }

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

          Text('AI 服务').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, top: 20, bottom: 8 })

          Column() {
            Row() {
              Text('🤖').fontSize(20)
              Column() {
                Text('AI 问答密钥').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
                Text(this.keyStatus).fontSize(11).fontColor(this.sub()).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
            }
            .width('100%')

            TextInput({ placeholder: '粘贴新的 API Key（留空保存则恢复内置）', text: this.apiKeyInput })
              .width('100%')
              .height(42)
              .fontSize(14)
              .fontColor(this.txt())
              .placeholderColor(this.sub())
              .type(InputType.Password)
              .backgroundColor(this.bg())
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .margin({ top: 12 })
              .onChange((value: string) => { this.apiKeyInput = value; })

            Row() {
              Button('保存密钥')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor('#9C27B0')
                .layoutWeight(1)
                .height(38)
                .borderRadius(10)
                .onClick(() => { this.saveApiKey(); })

              Button('恢复内置')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.txt())
                .backgroundColor(this.bg())
                .layoutWeight(1)
                .height(38)
                .borderRadius(10)
                .margin({ left: 10 })
                .onClick(() => { this.clearApiKey(); })
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.card())
          .borderRadius(12)
          .margin({ left: 16, right: 16, bottom: 8 })

          Text('关于').fontSize(14).fontColor(this.sub()).width('100%')
            .padding({ left: 20, top: 20, bottom: 8 })

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

  async refreshKeyStatus(): Promise<void> {
    const custom: string = await GlobalData.prefs.getAiApiKey();
    if (custom.length > 0) {
      const head: string = custom.length > 6 ? custom.slice(0, 6) : custom;
      const tail: string = custom.length > 4 ? custom.slice(-4) : '';
      this.keyStatus = '自定义密钥已配置（' + head + '…' + tail + '）';
    } else {
      this.keyStatus = '使用内置密钥（ai_config.json）';
    }
  }

  async saveApiKey(): Promise<void> {
    const key: string = this.apiKeyInput.trim();
    if (key.length === 0) {
      promptAction.showToast({ message: '请输入 API Key' });
      return;
    }
    await GlobalData.prefs.setAiApiKey(key);
    const ctx: Context = getContext(this);
    await ChatService.getInstance().reloadApiKey(ctx);
    await FoodRecognitionService.getInstance().reloadApiKey(ctx);
    this.apiKeyInput = '';
    await this.refreshKeyStatus();
    promptAction.showToast({ message: 'API Key 已保存并生效' });
  }

  async clearApiKey(): Promise<void> {
    await GlobalData.prefs.setAiApiKey('');
    const ctx: Context = getContext(this);
    await ChatService.getInstance().reloadApiKey(ctx);
    await FoodRecognitionService.getInstance().reloadApiKey(ctx);
    await this.refreshKeyStatus();
    promptAction.showToast({ message: '已恢复内置密钥' });
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
