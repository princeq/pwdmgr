import preferences from '@ohos.data.preferences';
import { BusinessError } from '@kit.BasicServicesKit';
import { PasswordEntry } from './CsvParser';
import { common } from '@kit.AbilityKit';

// 定义存储的数据结构类
class StoredPassword {
  website: string = '';
  username: string = '';
  password: string = '';
  url: string = '';
  notes: string = '';
  createdAt: string = '';
}

// 定义返回结果类
class SaveResult {
  success: number = 0;
  failed: number = 0;
}

export class PasswordStorage {
  private preferencesName: string = 'imported_passwords';
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 获取Preferences实例
   */
  private async getPreferences(): Promise<preferences.Preferences> {
    try {
      let preference: preferences.Preferences = await preferences.getPreferences(this.context, this.preferencesName);
      return preference;
    } catch (err) {
      let error = err as BusinessError;
      console.error('获取Preferences失败:', error.message);
      throw new Error('获取Preferences失败');
    }
  }

  /**
   * 获取所有密码
   */
  async getAllPasswords(): Promise<PasswordEntry[]> {
    try {
      let preference: preferences.Preferences = await this.getPreferences();
      let allEntries: object = await preference.getAll();
      let passwords: PasswordEntry[] = [];

      // 使用 Object.keys 遍历，不使用索引访问
      let keys: string[] = Object.keys(allEntries);
      for (let i: number = 0; i < keys.length; i++) {
        let key: string = keys[i];
        // 使用类型断言访问属性
        let value: string = (allEntries as Record<string, string>)[key];
        if (value && typeof value === 'string') {
          try {
            let parsed: StoredPassword = JSON.parse(value) as StoredPassword;
            let entry: PasswordEntry = {
              website: parsed.website,
              username: parsed.username,
              password: parsed.password,
              url: parsed.url,
              notes: parsed.notes,
              createdAt: parsed.createdAt
            };
            passwords.push(entry);
          } catch (e) {
            console.error('解析失败:', key, e);
          }
        }
      }

      return passwords;
    } catch (err) {
      let error = err as BusinessError;
      console.error('获取密码失败:', error.message);
      return [];
    }
  }

  /**
   * 保存密码
   */
  async savePassword(entry: PasswordEntry): Promise<boolean> {
    try {
      let pref: preferences.Preferences = await this.getPreferences();
      let baseKey: string = entry.website + '_' + entry.username;
      let finalKey: string = baseKey;
      let counter: number = 1;

      // 检查 key 是否已存在，如果存在则添加后缀
      while (await pref.has(finalKey)) {
        finalKey = baseKey + '_' + counter;
        counter++;
      }

      // 构建存储对象
      let toStore: StoredPassword = new StoredPassword();
      toStore.website = entry.website;
      toStore.username = entry.username;
      toStore.password = entry.password;
      toStore.url = entry.url || '';
      toStore.notes = entry.notes || '';
      toStore.createdAt = entry.createdAt;

      await pref.put(finalKey, JSON.stringify(toStore));
      await pref.flush();
      return true;
    } catch (err) {
      let error = err as BusinessError;
      console.error('保存失败:', error.message);
      return false;
    }
  }

  /**
   * 批量保存密码
   */
  async savePasswords(entries: PasswordEntry[]): Promise<SaveResult> {
    let successCount: number = 0;
    let failedCount: number = 0;

    for (let i: number = 0; i < entries.length; i++) {
      let entry: PasswordEntry = entries[i];
      let success: boolean = await this.savePassword(entry);
      if (success) {
        successCount++;
      } else {
        failedCount++;
      }
    }

    let result: SaveResult = new SaveResult();
    result.success = successCount;
    result.failed = failedCount;
    return result;
  }

  /**
   * 删除密码
   */
  async deletePassword(website: string, username: string): Promise<boolean> {
    try {
      let pref: preferences.Preferences = await this.getPreferences();
      let targetKey: string = website + '_' + username;

      console.info('尝试删除 - targetKey:', targetKey);

      // 获取所有存储的 key
      let allEntries = await pref.getAll();
      let allKeys = Object.keys(allEntries);
      console.info('所有存储的keys:', JSON.stringify(allKeys));

      // 查找所有匹配的 key（精确匹配或以前缀匹配）
      let keysToDelete: string[] = [];
      for (let i = 0; i < allKeys.length; i++) {
        let key = allKeys[i];
        // 精确匹配 或 key 以 targetKey 开头
        if (key === targetKey || key.indexOf(targetKey) === 0) {
          keysToDelete.push(key);
        }
      }

      if (keysToDelete.length === 0) {
        console.warn('未找到要删除的key:', targetKey);
        return false;
      }

      // 删除所有匹配的 key
      for (let i = 0; i < keysToDelete.length; i++) {
        await pref.delete(keysToDelete[i]);
        console.info('删除成功:', keysToDelete[i]);
      }

      await pref.flush();
      return true;
    } catch (err) {
      let error = err as BusinessError;
      console.error('删除失败:', error.message);
      return false;
    }
  }

  /**
   * 清空所有密码
   */
  async clearAll(): Promise<boolean> {
    try {
      let preference: preferences.Preferences = await this.getPreferences();
      let allEntries: object = await preference.getAll();
      let keys: string[] = Object.keys(allEntries);
      for (let i: number = 0; i < keys.length; i++) {
        await preference.delete(keys[i]);
      }
      await preference.flush();
      return true;
    } catch (err) {
      let error = err as BusinessError;
      console.error('清空失败:', error.message);
      return false;
    }
  }

  /**
   * 获取密码数量
   */
  async getCount(): Promise<number> {
    try {
      let preference: preferences.Preferences = await this.getPreferences();
      let allEntries: object = await preference.getAll();
      let keys: string[] = Object.keys(allEntries);
      return keys.length;
    } catch (err) {
      let error = err as BusinessError;
      console.error('获取数量失败:', error.message);
      return 0;
    }
  }
}