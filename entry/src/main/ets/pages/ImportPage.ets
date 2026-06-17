import filePicker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { BusinessError } from '@kit.BasicServicesKit';
import { CsvParser, PasswordEntry } from '../utils/CsvParser';
import { PasswordStorage } from '../utils/PasswordStorage';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';

// ==================== 1Password JSON 数据类型接口 ====================
interface OnePasswordUrl {
  url: string;
  label?: string;
}

interface OnePasswordOverview {
  title: string;
  url: string;
  urls?: OnePasswordUrl[];
}

interface OnePasswordLoginField {
  value: string;
  designation?: string;
  name?: string;
  type?: string;
}

// 字段值接口
interface SectionFieldValue {
  string?: string;
  concealed?: string;
  menu?: string;
  url?: string;
  date?: number | null;
  monthYear?: number | null;
  creditCardNumber?: string;
  creditCardType?: string;
  phone?: string;
  address?: object;
}

// Section 中的字段接口
interface SectionField {
  id: string;
  title: string;
  value: SectionFieldValue;
  guarded?: boolean;
  multiline?: boolean;
  dontGenerate?: boolean;
  clipboardFilter?: string;
}

// Section 接口
interface DetailsSection {
  title: string;
  name?: string;
  fields: SectionField[];
}

// Details 接口
interface OnePasswordDetails {
  loginFields?: OnePasswordLoginField[];
  notesPlain?: string;
  password?: string;
  sections?: DetailsSection[];
}

interface OnePasswordItem {
  uuid: string;
  title?: string;
  createdAt?: number;
  updatedAt?: number;
  categoryUuid?: string;
  overview?: OnePasswordOverview;
  details?: OnePasswordDetails;
}

interface VaultAttrs {
  uuid: string;
  name: string;
}

interface OnePasswordVault {
  attrs?: VaultAttrs;
  items: OnePasswordItem[];
}

interface AccountAttrs {
  accountName: string;
  email: string;
}

interface OnePasswordAccount {
  attrs?: AccountAttrs;
  vaults: OnePasswordVault[];
}

interface OnePasswordData {
  accounts: OnePasswordAccount[];
}

// ==================== 1PUX 相关类型（用于旧的 CSV/1PUX 格式）====================
interface OnePuxField {
  id: string;
  type: string;
  value: string;
  label?: string;
  section?: string;
  purpose?: string;
}

interface OnePuxUrl {
  label: string;
  primary: boolean;
  href: string;
}

interface OnePuxItem {
  uuid: string;
  title: string;
  category: string;
  createdAt: string;
  updatedAt: string;
  fields: OnePuxField[];
  urls?: OnePuxUrl[];
  notes?: string;
}

@Entry
@Component
struct ImportPage {
  @State importStatus: string = '等待导入';
  @State isLoading: boolean = false;
  private passwordStorage: PasswordStorage | null = null;

  aboutToAppear(): void {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.passwordStorage = new PasswordStorage(context);
  }

  async selectCsvFile(): Promise<string> {
    try {
      let documentPicker: filePicker.DocumentViewPicker = new filePicker.DocumentViewPicker();
      let selectResult: Array<string> = await documentPicker.select({
        maxSelectNumber: 1,
        fileSuffixFilters: ['csv']
      });

      if (selectResult && selectResult.length > 0) {
        return selectResult[0];
      }
      return '';
    } catch (err) {
      let error = err as BusinessError;
      console.error('选择文件失败:', error.message);
      return '';
    }
  }

  async selectAnyFile(): Promise<string> {
    try {
      let documentPicker: filePicker.DocumentViewPicker = new filePicker.DocumentViewPicker();
      let selectResult: Array<string> = await documentPicker.select({
        maxSelectNumber: 1
      });

      if (selectResult && selectResult.length > 0) {
        return selectResult[0];
      }
      return '';
    } catch (err) {
      let error = err as BusinessError;
      console.error('选择文件失败:', error.message);
      return '';
    }
  }

  async readFileContent(uri: string): Promise<string> {
    try {
      let file = await fs.open(uri, fs.OpenMode.READ_ONLY);
      let stat = await fs.stat(file.fd);
      let buffer = new ArrayBuffer(stat.size);
      await fs.read(file.fd, buffer);
      await fs.close(file);

      let uint8Array = new Uint8Array(buffer);
      let textDecoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
      let content = textDecoder.decodeToString(uint8Array);
      return content;
    } catch (err) {
      let error = err as BusinessError;
      console.error('读取文件失败:', error.message);
      return '';
    }
  }

  async importCsvFile(): Promise<void> {
    this.isLoading = true;
    this.importStatus = '正在选择文件...';

    try {
      let uri = await this.selectCsvFile();

      if (!uri) {
        this.importStatus = '未选择文件';
        return;
      }

      this.importStatus = '正在读取文件...';
      let content = await this.readFileContent(uri);

      if (!content) {
        this.importStatus = '文件读取失败';
        return;
      }

      this.importStatus = '正在解析CSV...';
      let entries = CsvParser.parseCsvContent(content);

      if (entries.length === 0) {
        this.importStatus = '未找到有效的密码数据';
        return;
      }

      this.importStatus = `解析到 ${entries.length} 条记录，正在保存...`;

      if (this.passwordStorage) {
        let result = await this.passwordStorage.savePasswords(entries);
        this.importStatus = `导入完成！成功 ${result.success} 条，失败 ${result.failed} 条`;
        this.showToast(`成功导入 ${result.success} 条密码`);
      }

    } catch (err) {
      let error = err as BusinessError;
      console.error('导入失败:', error.message);
      this.importStatus = '导入失败: ' + error.message;
    } finally {
      this.isLoading = false;
    }
  }

  async importJsonFile(): Promise<void> {
    this.isLoading = true;
    this.importStatus = '正在选择文件...';

    try {
      let uri = await this.selectAnyFile();

      if (!uri) {
        this.importStatus = '未选择文件';
        return;
      }

      this.importStatus = '正在读取文件...';
      let content = await this.readFileContent(uri);

      if (!content) {
        this.importStatus = '文件读取失败';
        return;
      }

      console.info('文件长度:', content.length);

      this.importStatus = '正在解析JSON...';
      let entries = this.parseJsonContent(content);

      console.info('解析出的条目数:', entries.length);

      if (entries.length === 0) {
        this.importStatus = '未找到有效的密码数据';
        return;
      }

      this.importStatus = `解析到 ${entries.length} 条记录，正在保存...`;

      if (this.passwordStorage) {
        let result = await this.passwordStorage.savePasswords(entries);
        let duplicateCount = entries.length - result.success;
        this.importStatus = `导入完成！成功 ${result.success} 条，失败 ${result.failed} 条，重复/跳过 ${duplicateCount} 条`;
        this.showToast(`成功导入 ${result.success} 条密码${duplicateCount > 0 ? `，跳过 ${duplicateCount} 条重复` : ''}`);
      }

    } catch (err) {
      let error = err as BusinessError;
      console.error('导入失败:', error.message);
      this.importStatus = '导入失败: ' + error.message;
    } finally {
      this.isLoading = false;
    }
  }

  parseJsonContent(content: string): PasswordEntry[] {
    let entries: PasswordEntry[] = [];

    try {
      let data: OnePasswordData = JSON.parse(content) as OnePasswordData;

      // 用于检测重复的 Set
      let keySet: Set<string> = new Set();
      let duplicateCount: number = 0;
      let totalParsedCount: number = 0;

      // 遍历 accounts
      if (data.accounts && Array.isArray(data.accounts)) {
        for (let i: number = 0; i < data.accounts.length; i++) {
          let account: OnePasswordAccount = data.accounts[i];

          // 遍历 vaults
          if (account.vaults && Array.isArray(account.vaults)) {
            for (let j: number = 0; j < account.vaults.length; j++) {
              let vault: OnePasswordVault = account.vaults[j];

              // 遍历 items
              if (vault.items && Array.isArray(vault.items)) {
                console.info('找到 items 数量:', vault.items.length);
                totalParsedCount += vault.items.length;

                for (let k: number = 0; k < vault.items.length; k++) {
                  let item: OnePasswordItem = vault.items[k];
                  let entry: PasswordEntry | null = this.convertItemToPasswordEntry(item);
                  if (entry) {
                    let key: string = entry.website + '_' + entry.username;
                    if (keySet.has(key)) {
                      duplicateCount++;
                      console.info('重复条目:', entry.website, entry.username);
                    } else {
                      keySet.add(key);
                      entries.push(entry);
                    }
                  }
                }
              }
            }
          }
        }
      }

      console.info('总解析数:', totalParsedCount);
      console.info('重复数:', duplicateCount);
      console.info('有效数:', entries.length);
      console.info('解析到的密码数量:', entries.length);

    } catch (err) {
      let error = err as BusinessError;
      console.error('JSON解析失败:', error.message);
    }

    return entries;
  }

  // 转换 1Password 项目为 PasswordEntry
  convertItemToPasswordEntry(item: OnePasswordItem): PasswordEntry | null {
    if (!item) return null;

    let title: string = '';
    let username: string = '';
    let password: string = '';
    let url: string = '';
    let notes: string = '';

    // 从 overview 获取标题和 URL
    if (item.overview) {
      title = item.overview.title || '';
      url = item.overview.url || '';

      if (item.overview.urls && Array.isArray(item.overview.urls) && item.overview.urls.length > 0) {
        if (!url) {
          url = item.overview.urls[0].url || '';
        }
      }
    }

    let categoryUuid: string = item.categoryUuid || '';

    if (item.details) {
      // 从 loginFields 中提取用户名和密码
      if (item.details.loginFields && Array.isArray(item.details.loginFields)) {
        for (let j: number = 0; j < item.details.loginFields.length; j++) {
          let field: OnePasswordLoginField = item.details.loginFields[j];
          if (field.designation === 'username') {
            username = field.value || '';
          }
          if (field.designation === 'password') {
            password = field.value || '';
          }
        }
      }

      // 如果 loginFields 中没有密码，尝试直接获取 details.password
      if (!password && item.details.password) {
        password = item.details.password;
      }

      // 信用卡类型 (002)
      if (categoryUuid === '002' && item.details.sections && Array.isArray(item.details.sections)) {
        let sections: DetailsSection[] = item.details.sections;
        let cardNumber: string = '';
        let cardholder: string = '';
        let expiry: string = '';
        let cvv: string = '';
        let bank: string = '';
        let extraPasswords: string[] = [];
        let mainPassword: string = '';  // 主密码（支付密码）

        for (let s: number = 0; s < sections.length; s++) {
          let section: DetailsSection = sections[s];
          if (section.fields && Array.isArray(section.fields)) {
            for (let f: number = 0; f < section.fields.length; f++) {
              let field: SectionField = section.fields[f];
              let fieldId: string = field.id || '';
              let fieldTitle: string = field.title || '';

              if (fieldId === 'ccnum' && field.value.creditCardNumber) {
                cardNumber = field.value.creditCardNumber;
              }
              if (fieldId === 'cardholder' && field.value.string) {
                cardholder = field.value.string;
              }
              if (fieldId === 'expiry' && field.value.monthYear) {
                let year: number = Math.floor(field.value.monthYear / 100);
                let month: number = field.value.monthYear % 100;
                expiry = `${month}/${year}`;
              }
              if (fieldId === 'cvv' && field.value.concealed) {
                cvv = field.value.concealed;
              }
              if (fieldId === 'bank' && field.value.string) {
                bank = field.value.string;
              }
              // 收集所有密码字段
              if (fieldTitle === '密码' && field.value.concealed) {
                extraPasswords.push(field.value.concealed);
              }
            }
          }
        }

        if (cardNumber) {
          // 用户名显示完整卡号
          username = cardNumber;

          // 构建备注信息
          let notesBuilder: string = '';
          if (cvv) {
            notesBuilder = notesBuilder + `CVV: ${cvv}\n`;
          }
          if (expiry) {
            notesBuilder = notesBuilder + `有效期: ${expiry}\n`;
          }
          if (cardholder) {
            notesBuilder = notesBuilder + `持卡人: ${cardholder}\n`;
          }
          if (bank) {
            notesBuilder = notesBuilder + `发卡行: ${bank}\n`;
          }

          // 处理密码：取第一个作为主密码，其余的放入其他密码
          if (extraPasswords.length > 0) {
            // 第一个作为主密码
            mainPassword = extraPasswords[0];

            // 其余的作为其他密码
            if (extraPasswords.length > 1) {
              let remaining: string[] = [];
              for (let i: number = 1; i < extraPasswords.length; i++) {
                remaining.push(extraPasswords[i]);
              }
              notesBuilder = notesBuilder + `其他密码: ${remaining.join(', ')}\n`;
            }
          }

          notes = notesBuilder;
          password = mainPassword || '无密码';

          if (!title) {
            let last4: string = cardNumber.substring(cardNumber.length - 4);
            title = `信用卡 ${last4}`;
          }
        }
      }

      // 无线网络类型 (109) - 从 sections 中提取密码
      if (categoryUuid === '109' && item.details.sections && Array.isArray(item.details.sections)) {
        let sections: DetailsSection[] = item.details.sections;
        for (let s: number = 0; s < sections.length; s++) {
          let section: DetailsSection = sections[s];
          if (section.fields && Array.isArray(section.fields)) {
            for (let f: number = 0; f < section.fields.length; f++) {
              let field: SectionField = section.fields[f];
              let fieldId: string = field.id || '';
              let fieldTitle: string = field.title || '';

              if (fieldId === 'password' || fieldTitle === '基站密码' || fieldTitle === '无线网络密码') {
                if (field.value.concealed) {
                  password = field.value.concealed;
                } else if (field.value.string) {
                  password = field.value.string;
                }
              }
              if (fieldId === 'name' || fieldTitle === '基站名称' || fieldTitle === '网络名称') {
                if (field.value.string) {
                  username = field.value.string;
                }
              }
              if (fieldTitle === '无线安全' && field.value.menu) {
                notes = '安全类型: ' + field.value.menu + (notes ? '\n' + notes : '');
              }
              if (fieldTitle === '服务器 / IP 地址' && field.value.string) {
                notes = 'IP地址: ' + field.value.string + (notes ? '\n' + notes : '');
              }
            }
          }
        }
      }

      if (item.details.notesPlain) {
        notes = item.details.notesPlain;
      }
    }

    // 安全备注类型 (003) 或 密码类型 (005)
    if (categoryUuid === '003' || categoryUuid === '005') {
      if (notes) {
        let isKeyRelated: boolean = title.indexOf('密钥') !== -1 ||
          title.indexOf('恢复') !== -1 ||
          title.indexOf('key') !== -1 ||
          title.indexOf('密码') !== -1;

        if (isKeyRelated || !password) {
          let lines: string[] = notes.split('\n');
          if (lines.length > 0 && lines[0].trim().length > 0) {
            password = lines[0].trim();
            if (lines.length > 1) {
              let remaining: string = '';
              for (let i: number = 1; i < lines.length; i++) {
                remaining = remaining + lines[i] + '\n';
              }
              notes = remaining.trim();
            } else {
              notes = '';
            }
          } else {
            password = notes;
            notes = '';
          }
        }
      }

      if (!username) {
        if (categoryUuid === '003') {
          username = '安全备注';
        } else {
          // 使用 uuid 的后8位作为唯一标识
          let shortUuid: string = item.uuid;
          if (shortUuid.length > 8) {
            shortUuid = shortUuid.substring(shortUuid.length - 8);
          }
          username = '密码条目_' + shortUuid;
        }
      }
    }

    // 无线网络类型 (109)
    if (categoryUuid === '109') {
      if (!username) username = 'WiFi';
      if (!password) password = '无密码';
    }

    // 如果没有标题，跳过
    if (!title) {
      return null;
    }

    let isMemo: boolean = title.indexOf('备忘录') !== -1 || title.indexOf('笔记') !== -1;
    if (isMemo && !password) {
      password = '查看备注';
      if (!username) username = '笔记';
    }

    if (!username && title) {
      username = '无账号';
    }

    if (!password && title) {
      password = '无密码';
    }

    let createdAt: string = '';
    if (item.createdAt) {
      let date: Date = new Date(item.createdAt * 1000);
      createdAt = date.toISOString();
    } else {
      createdAt = new Date().toISOString();
    }

    let entry: PasswordEntry = {
      website: title,
      username: username,
      password: password,
      url: url || '',
      notes: notes || '',
      createdAt: createdAt
    };

    return entry;
  }

  // 转换 1PUX 项目为 PasswordEntry
  convertOnePuxItemToEntry(item: OnePuxItem): PasswordEntry | null {
    if (!item) return null;

    let title: string = item.title || '未命名';
    let username: string = '';
    let password: string = '';
    let url: string = '';
    let notes: string = '';

    if (item.fields && Array.isArray(item.fields)) {
      for (let i: number = 0; i < item.fields.length; i++) {
        let field: OnePuxField = item.fields[i];
        if (field.purpose === 'USERNAME' || field.type === 'EMAIL') {
          username = field.value || '';
        }
        if (field.purpose === 'PASSWORD' || field.type === 'CONCEALED') {
          password = field.value || '';
        }
        if (field.label === 'notes' || field.section === 'notes') {
          notes = field.value || '';
        }
        if (field.type === 'URL' || field.label === 'url') {
          url = field.value || '';
        }
      }
    }

    if (item.urls && Array.isArray(item.urls) && item.urls.length > 0) {
      for (let i: number = 0; i < item.urls.length; i++) {
        let urlItem: OnePuxUrl = item.urls[i];
        if (urlItem.primary) {
          url = urlItem.href;
          break;
        }
      }
      if (!url && item.urls.length > 0) {
        url = item.urls[0].href;
      }
    }

    let category: string = item.category || '';

    if (category === 'CREDIT_CARD') {
      username = username || '信用卡';
      password = password || '查看备注获取卡号';
      notes = this.extractCreditCardInfo(item.fields) + '\n' + notes;
    } else if (category === 'SECURE_NOTE') {
      username = username || '安全备注';
      password = password || '查看备注获取内容';
    } else if (category === 'WIRELESS_ROUTER' || category === 'WIFI_PASSWORD') {
      for (let i: number = 0; i < item.fields.length; i++) {
        let field: OnePuxField = item.fields[i];
        if (field.label === 'ssid') {
          username = field.value || '';
        }
        if (field.label === 'password') {
          password = field.value || '';
        }
      }
      if (!username) username = 'WiFi';
    }

    if (!username && !password) {
      if (notes || title) {
        username = '无账号';
        password = '无密码';
      } else {
        return null;
      }
    }

    let entry: PasswordEntry = {
      website: title,
      username: username || '',
      password: password || '',
      url: url || '',
      notes: notes || '',
      createdAt: new Date().toISOString()
    };

    return entry;
  }

  extractCreditCardInfo(fields: OnePuxField[]): string {
    let info: string = '';
    if (!fields) return info;

    for (let i: number = 0; i < fields.length; i++) {
      let field: OnePuxField = fields[i];
      if (field.label === 'cardholder') {
        info = info + '\n持卡人: ' + field.value;
      }
      if (field.label === 'bank') {
        info = info + '\n银行: ' + field.value;
      }
      if (field.label === 'card number') {
        info = info + '\n卡号: ' + field.value;
      }
      if (field.label === 'expiry') {
        info = info + '\n有效期: ' + field.value;
      }
      if (field.label === 'cvv') {
        info = info + '\nCVV: ' + field.value;
      }
    }
    return info;
  }

  showToast(message: string): void {
    try {
      promptAction.showToast({
        message: message,
        duration: 2000
      });
    } catch (err) {
      console.error('显示Toast失败:', err);
    }
  }

  build() {
    Column() {
      Text('📦 密码导入')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.color_text_primary'))
        .margin({ top: 30, bottom: 20 })

      Text('从1Password导入密码数据')
        .fontSize(14)
        .fontColor($r('app.color.color_text_secondary'))
        .margin({ bottom: 30 })

      Row() {
        Button(this.isLoading ? '导入中...' : '📄 选择 CSV 文件')
          .layoutWeight(1)
          .height(50)
          .fontSize(14)
          .backgroundColor($r('app.color.color_info'))
          .enabled(!this.isLoading)
          .onClick(() => {
            this.importCsvFile();
          })
          .margin({ right: 8 })

        Button(this.isLoading ? '导入中...' : '📦 选择 1PUX 文件')
          .layoutWeight(1)
          .height(50)
          .fontSize(14)
          .backgroundColor($r('app.color.color_primary'))
          .enabled(!this.isLoading)
          .onClick(() => {
            this.importJsonFile();
          })
      }
      .width('90%')
      .margin({ bottom: 20 })

      Text(this.importStatus)
        .fontSize(14)
        .fontColor(this.importStatus.includes('成功') ? $r('app.color.color_success') : $r('app.color.color_text_secondary'))
        .textAlign(TextAlign.Center)
        .width('90%')
        .margin({ bottom: 20 })

      Column() {
        Text('💡 使用说明')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ bottom: 10 })
          .alignSelf(ItemAlign.Start)

        Text('1. 从1Password导出CSV文件')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ bottom: 6 })
          .alignSelf(ItemAlign.Start)

        Text('2. 或将.1pux改名为.zip后解压得到export.data')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ bottom: 6 })
          .alignSelf(ItemAlign.Start)

        Text('3. 点击上方按钮选择文件')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ bottom: 6 })
          .alignSelf(ItemAlign.Start)

        Text('4. 等待自动导入完成')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .alignSelf(ItemAlign.Start)
      }
      .width('85%')
      .padding(16)
      .backgroundColor($r('app.color.color_background_card'))
      .borderRadius(12)
      .margin({ top: 20 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_background'))
  }
}