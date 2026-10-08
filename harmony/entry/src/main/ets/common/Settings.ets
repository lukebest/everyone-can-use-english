import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const FILE: string = 'enjoy_settings';
const GLM_BASE: string = 'https://open.bigmodel.cn/api/coding/paas/v4';
const GLM_MODEL: string = 'glm-5.3';
const MINIMAX_BASE: string = 'https://api.minimaxi.com/v1';
const MINIMAX_MODEL: string = 'MiniMax-M2.7';

export class SettingsData {
  activeProvider: string = 'glm';
  glmBaseUrl: string = GLM_BASE;
  glmApiKey: string = '';
  glmModel: string = GLM_MODEL;
  minimaxBaseUrl: string = MINIMAX_BASE;
  minimaxApiKey: string = '';
  minimaxModel: string = MINIMAX_MODEL;
  speechUrl: string = '';
  speechToken: string = '';
}

function asString(value: preferences.ValueType): string {
  return typeof value === 'string' ? value : '';
}

function orDefault(value: string, fallback: string): string {
  return value.trim().length > 0 ? value.trim() : fallback;
}

export class Settings {
  static async load(context: common.UIAbilityContext): Promise<SettingsData> {
    const pref = await preferences.getPreferences(context, FILE);
    const data = new SettingsData();
    data.activeProvider = asString(await pref.get('activeProvider', 'glm'));
    if (data.activeProvider !== 'minimax') {
      data.activeProvider = 'glm';
    }
    data.glmBaseUrl = orDefault(asString(await pref.get('glmBaseUrl', '')), GLM_BASE);
    data.glmApiKey = asString(await pref.get('glmApiKey', ''));
    data.glmModel = orDefault(asString(await pref.get('glmModel', '')), GLM_MODEL);
    data.minimaxBaseUrl = orDefault(asString(await pref.get('minimaxBaseUrl', '')), MINIMAX_BASE);
    data.minimaxApiKey = asString(await pref.get('minimaxApiKey', ''));
    data.minimaxModel = orDefault(asString(await pref.get('minimaxModel', '')), MINIMAX_MODEL);
    data.speechUrl = asString(await pref.get('speechUrl', ''));
    data.speechToken = asString(await pref.get('speechToken', ''));
    if (data.speechUrl.length === 0) {
      data.speechUrl = asString(await pref.get('relayUrl', ''));
    }
    if (data.speechToken.length === 0) {
      data.speechToken = asString(await pref.get('relayToken', ''));
    }
    publish(data);
    return data;
  }

  static async save(context: common.UIAbilityContext, data: SettingsData): Promise<void> {
    const pref = await preferences.getPreferences(context, FILE);
    data.activeProvider = data.activeProvider === 'minimax' ? 'minimax' : 'glm';
    data.glmBaseUrl = orDefault(data.glmBaseUrl, GLM_BASE);
    data.glmModel = orDefault(data.glmModel, GLM_MODEL);
    data.minimaxBaseUrl = orDefault(data.minimaxBaseUrl, MINIMAX_BASE);
    data.minimaxModel = orDefault(data.minimaxModel, MINIMAX_MODEL);
    data.glmApiKey = data.glmApiKey.trim();
    data.minimaxApiKey = data.minimaxApiKey.trim();
    data.speechUrl = data.speechUrl.trim();
    data.speechToken = data.speechToken.trim();
    await pref.put('activeProvider', data.activeProvider);
    await pref.put('glmBaseUrl', data.glmBaseUrl);
    await pref.put('glmApiKey', data.glmApiKey);
    await pref.put('glmModel', data.glmModel);
    await pref.put('minimaxBaseUrl', data.minimaxBaseUrl);
    await pref.put('minimaxApiKey', data.minimaxApiKey);
    await pref.put('minimaxModel', data.minimaxModel);
    await pref.put('speechUrl', data.speechUrl);
    await pref.put('speechToken', data.speechToken);
    await pref.flush();
    publish(data);
  }
}

function publish(data: SettingsData): void {
  AppStorage.setOrCreate('activeProvider', data.activeProvider);
  AppStorage.setOrCreate('glmBaseUrl', data.glmBaseUrl);
  AppStorage.setOrCreate('glmApiKey', data.glmApiKey);
  AppStorage.setOrCreate('glmModel', data.glmModel);
  AppStorage.setOrCreate('minimaxBaseUrl', data.minimaxBaseUrl);
  AppStorage.setOrCreate('minimaxApiKey', data.minimaxApiKey);
  AppStorage.setOrCreate('minimaxModel', data.minimaxModel);
  AppStorage.setOrCreate('speechUrl', data.speechUrl);
  AppStorage.setOrCreate('speechToken', data.speechToken);
}
