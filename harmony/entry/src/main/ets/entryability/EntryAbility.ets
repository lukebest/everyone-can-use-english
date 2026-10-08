import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { setContext } from '../common/AppContext';
import { Settings } from '../common/Settings';
import { Db } from '../data/Db';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    setContext(this.context);
    hilog.info(0x0000, 'Enjoy', 'launch %{public}s %{public}d', want.bundleName ?? '', launchParam.launchReason);
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    const stage = windowStage;
    const context = this.context;
    Db.init(context).then(() => {
      return Settings.load(context);
    }).then(() => {
      stage.loadContent('pages/Index');
    }).catch(() => {
      stage.loadContent('pages/Index');
    });
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
  }

  onBackground(): void {
  }
}
