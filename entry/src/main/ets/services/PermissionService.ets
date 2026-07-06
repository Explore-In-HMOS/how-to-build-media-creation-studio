import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

const MIC: Permissions = 'ohos.permission.MICROPHONE';

export class PermissionService {
  static async ensureMic(context: common.UIAbilityContext): Promise<boolean> {
    const atManager = abilityAccessCtrl.createAtManager();
    try {
      const result = await atManager.requestPermissionsFromUser(context, [MIC]);
      const statuses = result.authResults;
      if (statuses.length === 0) {
        return false;
      }
      return statuses[0] === 0;
    } catch (err) {
      const e = err as BusinessError;
      console.error(`PermissionService.ensureMic failed: ${e.code} ${e.message}`);
      return false;
    }
  }
}
