import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { NotificationService } from './NotificationService';

export class PermissionService {
  private static instance: PermissionService;
  private permRequested: boolean = false;

  static getInstance(): PermissionService {
    if (!PermissionService.instance) {
      PermissionService.instance = new PermissionService();
    }
    return PermissionService.instance;
  }

  async requestRequiredPermissions(context: common.UIAbilityContext): Promise<void> {
    NotificationService.getInstance().setContext(context);

    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    // 1. 检查位置权限：未授权则请求（每次启动都检查，避免之前拒绝后不再请求）
    const locationGranted: boolean = await this.isGranted(atManager, 'ohos.permission.LOCATION');
    const approxGranted: boolean = await this.isGranted(atManager, 'ohos.permission.APPROXIMATELY_LOCATION');
    console.info('PermissionService: location granted state loc=' + String(locationGranted) +
      ' approx=' + String(approxGranted));
    if (!locationGranted || !approxGranted) {
      const locationPerms: Permissions[] = [
        'ohos.permission.LOCATION',
        'ohos.permission.APPROXIMATELY_LOCATION',
      ];
      try {
        const result = await atManager.requestPermissionsFromUser(context, locationPerms);
        const authResults: number[] = result.authResults;
        console.info('PermissionService: location requested, granted=' + String(
          authResults.filter((r: number) => r === 0).length) + '/' + String(locationPerms.length));
      } catch (err) {
        const error = err as BusinessError;
        console.error('PermissionService location request error: ' + error.code + ' ' + error.message);
      }
    } else {
      console.info('PermissionService: location already granted');
    }

    // 2. 请求运动权限（一次性）
    if (!this.permRequested) {
      this.permRequested = true;
      const otherPerms: Permissions[] = [
        'ohos.permission.ACTIVITY_MOTION',
      ];
      try {
        const result2 = await atManager.requestPermissionsFromUser(context, otherPerms);
        const authResults2: number[] = result2.authResults;
        console.info('PermissionService: other granted=' + String(
          authResults2.filter((r: number) => r === 0).length) + '/' + String(otherPerms.length));
      } catch (err) {
        const error = err as BusinessError;
        console.error('PermissionService other request error: ' + error.code + ' ' + error.message);
      }
    }

    await NotificationService.getInstance().requestEnable();
  }

  // 检查单个权限是否已授予
  private async isGranted(atManager: abilityAccessCtrl.AtManager, perm: string): Promise<boolean> {
    try {
      const bundleInfo: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenID: number = bundleInfo.appInfo.accessTokenId;
      const grantStatus: abilityAccessCtrl.GrantStatus = await atManager.checkAccessToken(tokenID, perm as Permissions);
      return grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
    } catch (err) {
      console.error('isGranted error for ' + perm + ': ' + JSON.stringify(err));
      return false;
    }
  }
}
