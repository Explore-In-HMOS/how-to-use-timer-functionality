import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { notificationManager } from '@kit.NotificationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import GlobalContext from '../utils/GlobalContext';

const TAG: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  public onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    GlobalContext.getInstance().saveContext(this.context);
    hilog.info(0x0000, TAG, 'Ability onCreate');
  }

  public onDestroy(): void {
    hilog.info(0x0000, TAG, 'Ability onDestroy');
  }

  public onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'Ability onWindowStageCreate');

    notificationManager.requestEnableNotification(this.context)
      .then(() => {
        hilog.info(0x0000, TAG, 'Notification permission granted');
      })
      .catch((err: BusinessError) => {
        hilog.warn(0x0000, TAG, `Notification permission denied: ${err.message}`);
      });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, `Failed to load content: ${JSON.stringify(err)}`);
        return;
      }
      hilog.info(0x0000, TAG, 'Content loaded successfully');
    });
  }

  public onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'Ability onWindowStageDestroy');
  }

  public onForeground(): void {
    hilog.info(0x0000, TAG, 'Ability onForeground');
    AppStorage.set<boolean>('appForeground', true);
  }

  public onBackground(): void {
    hilog.info(0x0000, TAG, 'Ability onBackground');
    AppStorage.set<boolean>('appForeground', false);
  }
}
