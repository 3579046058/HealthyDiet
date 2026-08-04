import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
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

    if (this.permRequested) {
      return;
    }
    this.permRequested = true;
    const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
    const perms: Permissions[] = [
      'ohos.permission.ACTIVITY_MOTION',
      'ohos.permission.ACCESS_BLUETOOTH',
      'ohos.permission.LOCATION',
      'ohos.permission.APPROXIMATELY_LOCATION',
    ];
    try {
      const result = await atManager.requestPermissionsFromUser(context, perms);
      const authResults: number[] = result.authResults;
      for (let i = 0; i < authResults.length; i++) {
        if (authResults[i] !== 0) {
          console.error('Permission denied: ' + perms[i]);
        }
      }
      console.info('PermissionService: requested done, granted count=' + String(
        authResults.filter((r: number) => r === 0).length));
    } catch (err) {
      const error = err as BusinessError;
      console.error('PermissionService request error: ' + error.code + ' ' + error.message);
    }

    await NotificationService.getInstance().requestEnable();
  }
}
