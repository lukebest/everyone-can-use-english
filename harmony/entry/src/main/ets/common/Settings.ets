import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const FILE: string = 'enjoy_settings';

export class SettingsData {
  relayUrl: string = '';
  relayToken: string = '';
}

export class Settings {
  static async load(context: common.UIAbilityContext): Promise<SettingsData> {
    const pref = await preferences.getPreferences(context, FILE);
    const data = new SettingsData();
    const url = await pref.get('relayUrl', '');
    const token = await pref.get('relayToken', '');
    data.relayUrl = typeof url === 'string' ? url : '';
    data.relayToken = typeof token === 'string' ? token : '';
    AppStorage.setOrCreate('relayUrl', data.relayUrl);
    AppStorage.setOrCreate('relayToken', data.relayToken);
    return data;
  }

  static async save(context: common.UIAbilityContext, data: SettingsData): Promise<void> {
    const pref = await preferences.getPreferences(context, FILE);
    await pref.put('relayUrl', data.relayUrl.trim());
    await pref.put('relayToken', data.relayToken.trim());
    await pref.flush();
    AppStorage.setOrCreate('relayUrl', data.relayUrl.trim());
    AppStorage.setOrCreate('relayToken', data.relayToken.trim());
  }
}
