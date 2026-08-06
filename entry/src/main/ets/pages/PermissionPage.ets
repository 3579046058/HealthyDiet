import { router, promptAction } from '@kit.ArkUI';
import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { ThemeColors } from '../common/Constants';

interface PermissionItem {
  name: Permissions;
  label: string;
  desc: string;
}

@Entry
@Component
struct PermissionPage {
  @StorageLink('currentTheme') theme: string = 'dark';
  @StorageLink('statusBarHeight') statusBarHeight: number = 47;
  @State permissionStatus: Map<string, boolean> = new Map<string, boolean>();
  private atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  private tokenId: number = 0;

  readonly permissionList: PermissionItem[] = [
    {
      name: 'ohos.permission.ACTIVITY_MOTION',
      label: '运动与健身',
      desc: '读取计步传感器，记录每日步数和运动状态'
    },
    {
      name: 'ohos.permission.LOCATION',
      label: '位置信息',
      desc: '运动时记录 GPS 实际路程（走路/跑步/骑行）'
    },
    {
      name: 'ohos.permission.READ_HEALTH_DATA',
      label: '健康数据',
      desc: '读取和记录健康数据'
    },
    {
      name: 'ohos.permission.PUBLISH_AGENT_REMINDER',
      label: '通知提醒',
      desc: '发送喝水、久坐和用药提醒通知'
    }
  ];

  aboutToAppear(): void {
    this.initToken();
  }

  onPageShow(): void {
    this.initToken();
  }

  initToken(): void {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION);
      this.tokenId = bundleInfo.appInfo.accessTokenId;
      this.refreshStatus();
    } catch (err) {
      console.error('PermissionPage get token error:', JSON.stringify(err));
    }
  }

  async refreshStatus(): Promise<void> {
    try {
      const newMap: Map<string, boolean> = new Map<string, boolean>();
      for (const item of this.permissionList) {
        try {
          const status = await this.atManager.checkAccessToken(this.tokenId, item.name);
          newMap.set(item.name, status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED);
        } catch (e) {
          newMap.set(item.name, false);
        }
      }
      this.permissionStatus = newMap;
    } catch (err) {
      console.error('PermissionPage refreshStatus error:', JSON.stringify(err));
    }
  }

  async openPermissionSetting(permissionName: Permissions): Promise<void> {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    try {
      // 未授权时尝试重新弹窗申请（user_grant 权限）
      if (!this.isGranted(permissionName)) {
        const result = await this.atManager.requestPermissionsFromUser(context, [permissionName]);
        const granted = result.authResults.length > 0 && result.authResults[0] === 0;
        if (granted) {
          promptAction.showToast({ message: '授权成功' });
        } else {
          promptAction.showToast({ message: '已拒绝，可在系统设置中开启' });
        }
      } else {
        promptAction.showToast({ message: '该权限已授权' });
      }
    } catch (err) {
      const e = err as BusinessError;
      if (e.code === 16000005) {
        promptAction.showToast({ message: '请在系统设置中修改权限' });
      } else {
        console.error('request permission error:', JSON.stringify(err));
        promptAction.showToast({ message: '无法打开权限设置' });
      }
    }
    await this.refreshStatus();
  }

  isGranted(permissionName: string): boolean {
    return this.permissionStatus.get(permissionName) === true;
  }

  bg(): string { return ThemeColors.pageBg(this.theme); }
  card(): string { return ThemeColors.cardBg(this.theme); }
  txt(): string { return ThemeColors.textPrimary(this.theme); }
  sub(): string { return ThemeColors.textSecondary(this.theme); }

  build() {
    Column() {
      Row() {
        Text('←').fontSize(22).fontColor(this.txt()).onClick(() => { router.back(); })
        Text('权限管理').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.txt()).margin({ left: 12 })
        Blank()
      }
      .width('100%').padding({ left: 16, right: 16, top: 12 + this.statusBarHeight, bottom: 12 })

      Scroll() {
        Column() {
          Text('权限用于保护你的隐私数据。关闭权限后，对应功能将无法使用。')
            .fontSize(12).fontColor(this.sub()).width('100%')
            .padding({ left: 20, bottom: 12 })

          ForEach(this.permissionList, (item: PermissionItem) => {
            Row() {
              Column() {
                Text(item.label).fontSize(15).fontWeight(FontWeight.Medium).fontColor(this.txt())
                Text(item.desc).fontSize(11).fontColor(this.sub()).margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start).margin({ left: 4 }).layoutWeight(1)

              if (this.isGranted(item.name)) {
                Text('已授权').fontSize(12).fontColor('#4CAF50')
              } else {
                Text('未授权').fontSize(12).fontColor('#FF9800')
              }
            }
            .width('100%').padding(14).backgroundColor(this.card()).borderRadius(12)
            .margin({ left: 16, right: 16, bottom: 8 })
            .onClick(() => { this.openPermissionSetting(item.name); })
          }, (item: PermissionItem): string => item.name)

          Text('提示：修改权限后返回本页面可查看最新状态')
            .fontSize(11).fontColor(this.sub()).width('100%')
            .padding({ left: 20, top: 8 })

          Divider().opacity(0).height(30)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%').backgroundColor(this.bg())
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  pageTransition() {
    PageTransitionEnter({ duration: 300, curve: Curve.Friction }).slide(SlideEffect.Right)
    PageTransitionExit({ duration: 200, curve: Curve.FastOutLinearIn }).slide(SlideEffect.Left)
  }
}
