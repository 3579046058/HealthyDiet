import { router, promptAction } from '@kit.ArkUI';
import { ThemeColors, AiConfig, AiDefaults } from '../common/Constants';
import { GlobalData } from '../common/GlobalData';
import { ChatService } from '../services/ChatService';

@Entry
@Component
struct SettingsPage {
  @StorageLink('themeMode') themeMode: string = 'follow';
  @StorageLink('systemDark') systemDark: boolean = false;
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State apiUrlInput: string = '';
  @State apiKeyInput: string = '';
  @State chatModelInput: string = '';
  @State keyStatus: string = '';
  @State aiJsonText: string = '';

  aboutToAppear(): void {
    this.refreshAiStatus();
    this.refreshAiJson();
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
                Text('AI 模型服务').fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
                Text(this.keyStatus).fontSize(11).fontColor(this.sub()).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start).margin({ left: 12 }).layoutWeight(1)
            }
            .width('100%')

            TextInput({ placeholder: 'API 地址（默认智谱开放平台）', text: this.apiUrlInput })
              .width('100%')
              .height(42)
              .fontSize(13)
              .fontColor(this.txt())
              .placeholderColor(this.sub())
              .backgroundColor(this.bg())
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .margin({ top: 10 })
              .onChange((value: string) => { this.apiUrlInput = value; })

            TextInput({ placeholder: 'API Key', text: this.apiKeyInput })
              .width('100%')
              .height(42)
              .fontSize(13)
              .fontColor(this.txt())
              .placeholderColor(this.sub())
              .type(InputType.Password)
              .backgroundColor(this.bg())
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .margin({ top: 10 })
              .onChange((value: string) => { this.apiKeyInput = value; })

            TextInput({ placeholder: '对话模型（默认 glm-4-flash，可换其他厂商模型）', text: this.chatModelInput })
              .width('100%')
              .height(42)
              .fontSize(13)
              .fontColor(this.txt())
              .placeholderColor(this.sub())
              .backgroundColor(this.bg())
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .margin({ top: 10 })
              .onChange((value: string) => { this.chatModelInput = value; })

            Text('识图模型固定使用智谱 GLM（glm-4v-flash），不可更改')
              .fontSize(10)
              .fontColor(this.sub())
              .width('100%')
              .margin({ top: 8 })

            Row() {
              Button('保存配置')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .backgroundColor('#9C27B0')
                .layoutWeight(1)
                .height(38)
                .borderRadius(10)
                .onClick(() => { this.saveAiConfig(); })

              Button('恢复内置')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.txt())
                .backgroundColor(this.bg())
                .layoutWeight(1)
                .height(38)
                .borderRadius(10)
                .margin({ left: 10 })
                .onClick(() => { this.clearAiConfig(); })
            }
            .width('100%')
            .margin({ top: 12 })

            Divider().margin({ top: 14, bottom: 4 })

            Text('当前配置（JSON，可直接编辑后导入）').fontSize(12).fontColor(this.sub()).width('100%')

            TextArea({ text: this.aiJsonText, placeholder: '{\n  "apiUrl": "",\n  "apiKey": "",\n  "chatModel": ""\n}' })
              .width('100%')
              .height(150)
              .fontSize(11)
              .fontColor(this.txt())
              .placeholderColor(this.sub())
              .backgroundColor(this.bg())
              .borderRadius(10)
              .padding({ left: 12, right: 12, top: 10, bottom: 10 })
              .margin({ top: 8 })
              .onChange((value: string) => { this.aiJsonText = value; })

            Button('导入 JSON 配置')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .backgroundColor('#9C27B0')
              .width('100%')
              .height(38)
              .borderRadius(10)
              .margin({ top: 10 })
              .onClick(() => { this.importAiJson(); })
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

  async refreshAiStatus(): Promise<void> {
    const cfg: AiConfig = await GlobalData.prefs.getAiConfig();
    let status: string = '使用内置配置';
    if (cfg.apiUrl.length > 0 || cfg.apiKey.length > 0 || cfg.chatModel.length > 0) {
      const chat: string = cfg.chatModel.length > 0 ? cfg.chatModel : AiDefaults.CHAT_MODEL;
      let keyText: string = '内置密钥';
      if (cfg.apiKey.length > 0) {
        const head: string = cfg.apiKey.length > 6 ? cfg.apiKey.slice(0, 6) : cfg.apiKey;
        keyText = head + '…';
      }
      status = chat + '｜' + keyText;
    }
    this.keyStatus = status;
  }

  async refreshAiJson(): Promise<void> {
    const cfg: AiConfig = await GlobalData.prefs.getAiConfig();
    this.aiJsonText = JSON.stringify(cfg, null, 2);
  }

  async importAiJson(): Promise<void> {
    const text: string = this.aiJsonText.trim();
    if (text.length === 0) {
      promptAction.showToast({ message: '请输入 JSON 配置' });
      return;
    }
    try {
      const parsed = JSON.parse(text) as Record<string, Object>;
      const cfg: AiConfig = new AiConfig();
      cfg.apiUrl = String(parsed['apiUrl'] ?? '');
      cfg.apiKey = String(parsed['apiKey'] ?? '');
      cfg.chatModel = String(parsed['chatModel'] ?? '');
      await GlobalData.prefs.setAiConfig(cfg);
      const ctx: Context = getContext(this);
      await ChatService.getInstance().reloadConfig(ctx);
      await this.refreshAiStatus();
      await this.refreshAiJson();
      promptAction.showToast({ message: 'JSON 配置已导入并生效' });
    } catch (err) {
      promptAction.showToast({ message: 'JSON 格式错误，请检查' });
    }
  }

  async saveAiConfig(): Promise<void> {
    const cfg: AiConfig = new AiConfig();
    cfg.apiUrl = this.apiUrlInput.trim();
    cfg.apiKey = this.apiKeyInput.trim();
    cfg.chatModel = this.chatModelInput.trim();
    if (cfg.apiUrl.length === 0 && cfg.apiKey.length === 0 && cfg.chatModel.length === 0) {
      promptAction.showToast({ message: '请输入至少一项配置' });
      return;
    }
    await GlobalData.prefs.setAiConfig(cfg);
    const ctx: Context = getContext(this);
    await ChatService.getInstance().reloadConfig(ctx);
    this.apiUrlInput = '';
    this.apiKeyInput = '';
    this.chatModelInput = '';
    await this.refreshAiStatus();
    await this.refreshAiJson();
    promptAction.showToast({ message: 'AI 配置已保存并生效' });
  }

  async clearAiConfig(): Promise<void> {
    const empty: AiConfig = new AiConfig();
    await GlobalData.prefs.setAiConfig(empty);
    const ctx: Context = getContext(this);
    await ChatService.getInstance().reloadConfig(ctx);
    await this.refreshAiStatus();
    await this.refreshAiJson();
    promptAction.showToast({ message: '已恢复内置配置' });
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
