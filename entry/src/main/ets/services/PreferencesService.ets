import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'PreferencesService';
const PREFERENCES_NAME: string = 'habit_timer_prefs';

export class PreferencesService {
  private preferencesInstance: preferences.Preferences | null = null;
  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  public async init(): Promise<void> {
    try {
      this.preferencesInstance = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      hilog.info(0x0000, TAG, 'Preferences initialized');
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `Failed to initialize preferences: ${businessError.message}`);
      throw new Error(`Failed to initialize preferences: ${businessError.message}`);
    }
  }

  public async putString(key: string, value: string): Promise<void> {
    if (!this.preferencesInstance) {
      hilog.error(0x0000, TAG, 'Preferences not initialized');
      return;
    }
    try {
      await this.preferencesInstance.put(key, value);
      await this.preferencesInstance.flush();
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `putString failed: ${businessError.message}`);
    }
  }

  public async getString(key: string, defaultValue: string): Promise<string> {
    if (!this.preferencesInstance) {
      hilog.error(0x0000, TAG, 'Preferences not initialized');
      return defaultValue;
    }
    try {
      const value = await this.preferencesInstance.get(key, defaultValue);
      return value as string;
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `getString failed: ${businessError.message}`);
      return defaultValue;
    }
  }

  public async putObject<T>(key: string, value: T): Promise<void> {
    try {
      const jsonString = JSON.stringify(value);
      await this.putString(key, jsonString);
    } catch (error) {
      hilog.error(0x0000, TAG, `putObject failed: ${error}`);
    }
  }

  public async getObject<T>(key: string, defaultValue: T): Promise<T> {
    try {
      const jsonString = await this.getString(key, '');
      if (jsonString === '') {
        return defaultValue;
      }
      return JSON.parse(jsonString) as T;
    } catch (error) {
      hilog.error(0x0000, TAG, `getObject failed: ${error}`);
      return defaultValue;
    }
  }

  public async delete(key: string): Promise<void> {
    if (!this.preferencesInstance) {
      hilog.error(0x0000, TAG, 'Preferences not initialized');
      return;
    }
    try {
      await this.preferencesInstance.delete(key);
      await this.preferencesInstance.flush();
    } catch (error) {
      const businessError = error as BusinessError;
      hilog.error(0x0000, TAG, `delete failed: ${businessError.message}`);
    }
  }
}
