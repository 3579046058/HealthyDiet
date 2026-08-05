import { router } from '@kit.ArkUI';
import { authentication } from '@kit.AccountKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { GlobalData } from '../common/GlobalData';
import { ThemeColors } from '../common/Constants';

@Entry
@Component
struct LoginPage {
  @State isLoggedIn: boolean = false;
  @State userName: string = '';
  @State showLogoutConfirm: boolean = false;
  @State heightCm: string = '';
  @State weightKg: string = '';
  @State skipWeightPrompt: boolean = false;
  @State unionId: string = '';
  @State loginError: string = '';
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;

  aboutToAppear(): void {
    this.checkLoginStatus();
  }

  async checkLoginStatus(): Promise<void> {
    try {
      const statusRaw: string | number | boolean = await GlobalData.prefs.get('login_status', 'false');
      if (String(statusRaw) === 'true') {
        const nameRaw: string | number | boolean = await GlobalData.prefs.get('user_name', '');
        this.isLoggedIn = true;
        this.userName = String(nameRaw);
        const unionRaw: string | number | boolean = await GlobalData.prefs.get('union_id', '');
        this.unionId = String(unionRaw);
      }
      const config = await GlobalData.prefs.getGoalConfig();
      this.heightCm = String(config.heightCm);
      this.weightKg = String(config.weightKg);
      this.skipWeightPrompt = await GlobalData.prefs.getWeightSkipPrompt();
    } catch (err) {
      console.error('LoginPage checkLoginStatus error:', JSON.stringify(err));
    }
  }

  async saveWeight(): Promise<void> {
    const val = parseFloat(this.weightKg);
    if (isNaN(val) || val <= 0) {
      return;
    }
    const config = await GlobalData.prefs.getGoalConfig();
    config.weightKg = val;
    await GlobalData.prefs.saveGoalConfig(config);
    await GlobalData.prefs.setWeight(val);
    await GlobalData.prefs.markWeightConfigured();
  }

  login(): void {
    this.loginError = '';
    try {
      const request = new authentication.HuaweiIDProvider()
        .createAuthorizationWithHuaweiIDRequest();
      request.scopes = ['openid', 'profile'];
      request.state = util.generateRandomUUID();
      request.forceAuthorization = false;

      const controller = new authentication.AuthenticationController();
      controller.executeRequest(request)
        .then((response: authentication.AuthorizationWithHuaweiIDResponse) => {
          const info = response.data;
          if (info) {
            const uid: string = info.unionID || '';
            const displayName: string = info.nickName || 'HUAWEI User';
            this.isLoggedIn = true;
            this.userName = displayName;
            this.unionId = uid;
            this.saveLoginState(displayName, uid);
          } else {
            this.loginError = '未获取到账号信息';
          }
        })
        .catch((error: BusinessError) => {
          console.error('Login error:', error.code, error.message);
          if (error.code === 1001502001) {
            this.loginError = '请先在本机登录华为账号';
          } else {
            this.loginError = '登录失败: ' + error.message;
          }
        });
    } catch (err) {
      console.error('Login exception:', JSON.stringify(err));
      this.loginError = '登录初始化失败';
    }
  }

  async saveLoginState(name: string, uid: string): Promise<void> {
    await GlobalData.prefs.put('login_status', 'true');
    await GlobalData.prefs.put('user_name', name);
    await GlobalData.prefs.put('union_id', uid);
    await GlobalData.prefs.flush();
  }

  async logout(): Promise<void> {
    this.isLoggedIn = false;
    this.userName = '';
    this.unionId = '';
    this.loginError = '';
    try {
      await GlobalData.prefs.put('login_status', 'false');
      await GlobalData.prefs.put('user_name', '');
      await GlobalData.prefs.put('union_id', '');
      await GlobalData.prefs.flush();
    } catch (err) {
      console.error('LoginPage logout error:', JSON.stringify(err));
    }
  }

  async saveHeight(): Promise<void> {
    const config = await GlobalData.prefs.getGoalConfig();
    config.heightCm = parseInt(this.heightCm) || 170;
    await GlobalData.prefs.saveGoalConfig(config);
  }

  async toggleSkipWeightPrompt(v: boolean): Promise<void> {
    this.skipWeightPrompt = v;
    await GlobalData.prefs.setWeightSkipPrompt(v);
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt())
          .onClick(() => { router.back(); })
        Blank()
        Text('账号登录').fontSize(18).fontColor(this.txt()).fontWeight(FontWeight.Medium)
        Blank()
        Text('').width(22)
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      if (!this.isLoggedIn) {
        Column() {
          Text('🔐').fontSize(72).margin({ top: 40 })
          Text('华为账号登录').fontSize(24).fontColor(this.txt()).fontWeight(FontWeight.Bold).margin({ top: 20 })
          Text('使用系统华为账号一键登录').fontSize(14).fontColor(this.sub()).margin({ top: 8 })

          Button('华为账号一键登录')
            .width('90%').height(48)
            .backgroundColor('#CF0A2C').borderRadius(24)
            .fontColor(this.txt()).fontSize(16).fontWeight(FontWeight.Medium)
            .margin({ top: 40 })
            .onClick(() => { this.login(); })

          if (this.loginError.length > 0) {
            Text(this.loginError).fontSize(13).fontColor('#FF6B6B').margin({ top: 16 })
          }

          Text('登录即表示同意 用户协议 和 隐私声明')
            .fontSize(11).fontColor(this.sub()).margin({ top: 20 })

          Divider().opacity(0).height(30)
          Text('⚠️ 接入说明').fontSize(14).fontColor(this.sub())
          Text('1. 在 AGC 开通华为账号服务').fontSize(12).fontColor(this.sub()).margin({ top: 8 })
          Text('2. 在 module.json5 配置 client_id').fontSize(12).fontColor(this.sub())
          Text('3. 配置 OAuth 回调地址').fontSize(12).fontColor(this.sub())
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      } else {
        Column() {
          Stack() {
            Circle().width(72).height(72).fill('#CF0A2C')
            Text(this.userName.charAt(0)).fontSize(32).fontColor(this.txt())
          }
          .margin({ top: 40 })

          Text(this.userName).fontSize(20).fontColor(this.txt()).fontWeight(FontWeight.Bold).margin({ top: 16 })

          Text('已登录')
            .fontSize(12).fontColor(this.txt())
            .backgroundColor('#4CAF50').borderRadius(12)
            .padding({ left: 12, right: 12, top: 4, bottom: 4 })
            .margin({ top: 12 })

          if (this.unionId.length > 0) {
            Text('Union ID: ' + this.unionId.slice(0, 12) + '...')
              .fontSize(11).fontColor(this.sub()).margin({ top: 8 })
          }

          Row() {
            Text('身高').fontSize(14).fontColor(this.sub()).margin({ right: 8 })
            TextInput({ placeholder: '170', text: this.heightCm })
              .type(InputType.Number).width(80).height(40)
              .backgroundColor(ThemeColors.inputBg(this.theme))
              .fontColor(this.txt())
              .placeholderColor(ThemeColors.textSecondary(this.theme))
              .onChange((v: string) => { this.heightCm = v; })
            Text('cm').fontSize(14).fontColor(this.sub()).margin({ left: 6 })
          }
          .margin({ top: 20 })

          Button('保存身高').width(160).height(40)
            .backgroundColor('#4CAF50').borderRadius(20)
            .fontColor(this.txt()).fontSize(14)
            .margin({ top: 8 })
            .onClick(() => { this.saveHeight(); })

          Row() {
            Text('体重').fontSize(14).fontColor(this.sub()).margin({ right: 8 })
            TextInput({ placeholder: '70', text: this.weightKg })
              .type(InputType.Number).width(80).height(40)
              .backgroundColor(ThemeColors.inputBg(this.theme))
              .fontColor(this.txt())
              .placeholderColor(ThemeColors.textSecondary(this.theme))
              .onChange((v: string) => { this.weightKg = v; })
            Text('kg').fontSize(14).fontColor(this.sub()).margin({ left: 6 })
          }
          .margin({ top: 16 })

          Button('保存体重').width(160).height(40)
            .backgroundColor('#FF6B35').borderRadius(20)
            .fontColor(this.txt()).fontSize(14)
            .margin({ top: 8 })
            .onClick(() => { this.saveWeight(); })

          Row() {
            Text('设置后不再弹出体重弹窗').fontSize(13).fontColor(this.sub())
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.skipWeightPrompt })
              .selectedColor('#FF6B35')
              .onChange((on: boolean) => { this.toggleSkipWeightPrompt(on); })
          }
          .width('100%').padding({ top: 12, left: 0 })

          Button('退出登录')
            .width('90%').height(48)
            .backgroundColor('#CF0A2C').borderRadius(24)
            .fontColor(this.txt()).fontSize(16).fontWeight(FontWeight.Medium)
            .margin({ top: 24 })
            .onClick(() => {
              this.showLogoutConfirm = true;
              AlertDialog.show({
                title: '提示',
                message: '确定要退出登录吗？',
                primaryButton: {
                  value: '取消',
                  action: () => { this.showLogoutConfirm = false; }
                },
                secondaryButton: {
                  value: '退出',
                  fontColor: '#CF0A2C',
                  action: () => {
                    this.logout();
                    this.showLogoutConfirm = false;
                  }
                }
              });
            })
        }
        .width('100%').alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
