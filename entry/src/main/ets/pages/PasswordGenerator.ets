import promptAction from '@ohos.promptAction';
import router from '@ohos.router';
import { PasswordStorage } from '../utils/PasswordStorage';
import { PasswordEntry } from '../utils/CsvParser';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import pasteboard from '@ohos.pasteboard';

class PasswordConfig {
  length: number = 16;
  useLowercase: boolean = true;
  useUppercase: boolean = true;
  useNumbers: boolean = true;
  useSymbols: boolean = true;
}

@Entry
@Component
struct PasswordGenerator {
  @State generatedPassword: string = '';
  @State passwordLength: number = 16;
  @State useLowercase: boolean = true;
  @State useUppercase: boolean = true;
  @State useNumbers: boolean = true;
  @State useSymbols: boolean = true;
  @State website: string = '';
  @State username: string = '';
  @State password: string = '';
  @State showPassword: boolean = false;
  @State editMode: boolean = false;
  @State editKey: string = '';
  @State originalNotes: string = '';

  private passwordStorage: PasswordStorage | null = null;

  aboutToAppear(): void {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.passwordStorage = new PasswordStorage(context);

    let params = router.getParams() as Record<string, string>;
    if (params && params['editKey']) {
      this.loadForEdit(params['editKey']);
    }
  }

  toggleLowercase(): void {
    this.useLowercase = !this.useLowercase;
    this.generatePassword();
  }

  toggleUppercase(): void {
    this.useUppercase = !this.useUppercase;
    this.generatePassword();
  }

  toggleNumbers(): void {
    this.useNumbers = !this.useNumbers;
    this.generatePassword();
  }

  toggleSymbols(): void {
    this.useSymbols = !this.useSymbols;
    this.generatePassword();
  }

  generatePassword(): void {
    let config: PasswordConfig = new PasswordConfig();
    config.length = this.passwordLength;
    config.useLowercase = this.useLowercase;
    config.useUppercase = this.useUppercase;
    config.useNumbers = this.useNumbers;
    config.useSymbols = this.useSymbols;

    this.generatedPassword = this.doGenerate(config);
  }

  private doGenerate(config: PasswordConfig): string {
    let charset: string = '';

    if (config.useLowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
    if (config.useUppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (config.useNumbers) charset += '0123456789';
    if (config.useSymbols) charset += '!@#$%^&*()_+-=[]{}|;:,.<>?';

    if (charset.length === 0) charset = 'abcdefghijklmnopqrstuvwxyz0123456789';

    let result: string = '';
    for (let i: number = 0; i < config.length; i++) {
      let randomIndex: number = Math.floor(Math.random() * charset.length);
      result += charset.charAt(randomIndex);
    }
    return result;
  }

  async copyToClipboard(): Promise<void> {
    if (this.generatedPassword.length === 0) {
      this.showToast('请先生成密码');
      return;
    }

    try {
      let pasteData: pasteboard.PasteData = pasteboard.createPlainTextData(this.generatedPassword);
      let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      this.showToast('密码已复制');
    } catch (err) {
      let error = err as BusinessError;
      console.error('复制失败:', error.message);
      this.showToast('复制失败');
    }
  }

  async loadForEdit(key: string): Promise<void> {
    if (!this.passwordStorage) return;

    let passwords = await this.passwordStorage.getAllPasswords();
    for (let i = 0; i < passwords.length; i++) {
      let item = passwords[i];
      let itemKey = item.website + '_' + item.username;
      if (itemKey === key) {
        this.website = item.website;
        this.username = item.username;
        this.password = item.password;
        this.originalNotes = item.notes;
        this.editMode = true;
        this.editKey = key;
        this.showToast('已加载，修改后点击保存');
        break;
      }
    }
  }

  async savePassword(): Promise<void> {
    if (this.website.length === 0) {
      this.showToast('请输入网站/应用名称');
      return;
    }
    if (this.username.length === 0) {
      this.showToast('请输入用户名/邮箱');
      return;
    }
    if (this.password.length === 0) {
      this.showToast('请输入密码');
      return;
    }

    if (this.editMode && this.passwordStorage) {
      let oldParts = this.editKey.split('_');
      if (oldParts.length >= 2) {
        await this.passwordStorage.deletePassword(oldParts[0], oldParts[1]);
      }
    }

    if (this.passwordStorage) {
      let entry: PasswordEntry = {
        website: this.website,
        username: this.username,
        password: this.password,
        url: '',
        notes: this.originalNotes,
        createdAt: new Date().toISOString()
      };
      let success = await this.passwordStorage.savePassword(entry);
      if (success) {
        this.showToast(this.editMode ? '更新成功' : '保存成功');
        this.clearForm();
        this.editMode = false;
        this.editKey = '';
        this.originalNotes = '';
      } else {
        this.showToast('保存失败');
      }
    }
  }

  clearForm(): void {
    this.website = '';
    this.username = '';
    this.password = '';
    this.originalNotes = '';
    this.editMode = false;
    this.editKey = '';
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

  goToList(): void {
    router.pushUrl({ url: 'pages/PasswordListPage' });
  }

  goToImport(): void {
    router.pushUrl({ url: 'pages/ImportPage' });
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Text(this.editMode ? '✏️ 编辑密码' : ' 密码生成器')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)

        Button('📦 导入')
          .fontSize(14)
          .height(36)
          .backgroundColor($r('app.color.color_info'))
          .fontColor(Color.White)
          .margin({ right: 8 })
          .onClick(() => {
            this.goToImport();
          })

        Button('📋 密码列表')
          .fontSize(14)
          .height(36)
          .backgroundColor($r('app.color.color_primary'))
          .fontColor(Color.White)
          .onClick(() => {
            this.goToList();
          })
      }
      .width('90%')
      .margin({ top: 20, bottom: 10 })

      // 编辑模式：显示编辑表单
      if (this.editMode) {
        // 网站输入
        TextInput({ placeholder: '网站/应用名称', text: this.website })
          .width('90%')
          .height(44)
          .backgroundColor($r('app.color.color_background_card'))
          .fontColor($r('app.color.color_text_primary'))
          .placeholderColor($r('app.color.color_text_tertiary'))
          .onChange((value: string) => {
            this.website = value;
          })
          .margin({ bottom: 15 })

        // 用户名输入
        TextInput({ placeholder: '用户名 / 邮箱', text: this.username })
          .width('90%')
          .height(44)
          .backgroundColor($r('app.color.color_background_card'))
          .fontColor($r('app.color.color_text_primary'))
          .placeholderColor($r('app.color.color_text_tertiary'))
          .onChange((value: string) => {
            this.username = value;
          })
          .margin({ bottom: 15 })

        // 密码输入
        Row() {
          TextInput({ placeholder: '密码', text: this.password })
            .type(this.showPassword ? InputType.Normal : InputType.Password)
            .layoutWeight(1)
            .height(44)
            .backgroundColor($r('app.color.color_background_card'))
            .fontColor($r('app.color.color_text_primary'))
            .placeholderColor($r('app.color.color_text_tertiary'))
            .onChange((value: string) => {
              this.password = value;
            })

        }
        .width('90%')
        .margin({ bottom: 20 })

        // 按钮组（编辑模式）
        Row() {
          Button('更新密码')
            .backgroundColor($r('app.color.color_warning'))
            .fontColor(Color.White)
            .onClick(() => {
              this.savePassword();
            })

          Button('取消')
            .backgroundColor($r('app.color.color_error'))
            .fontColor(Color.White)
            .onClick(() => {
              this.clearForm();
            })
        }
        .width('90%')
        .justifyContent(FlexAlign.SpaceEvenly)
        .margin({ bottom: 20 })
      } else {
        // 非编辑模式：只显示密码生成器
        // 高级选项
        Column() {
          Text('⚙️ 高级选项')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.color_text_primary'))
            .margin({ bottom: 10 })
            .alignSelf(ItemAlign.Start)

          // 密码长度滑块
          Row() {
            Text('密码长度: ' + this.passwordLength)
              .fontSize(14)
              .fontColor($r('app.color.color_text_secondary'))
              .layoutWeight(1)

            Slider({
              value: this.passwordLength,
              min: 6,
              max: 32,
              step: 1
            })
              .layoutWeight(2)
              .blockColor($r('app.color.color_primary'))
              .trackColor($r('app.color.color_border'))
              .selectedColor($r('app.color.color_primary'))
              .onChange((value: number) => {
                this.passwordLength = value;
                this.generatePassword();
              })
          }
          .width('100%')
          .margin({ bottom: 15 })

          Row() {
            Button('小写 abc')
              .fontSize(13)
              .backgroundColor(this.useLowercase ? $r('app.color.color_primary') : $r('app.color.color_background_card'))
              .fontColor(this.useLowercase ? Color.White : $r('app.color.color_text_secondary'))
              .height(36)
              .padding({ left: 16, right: 16 })
              .border({ width: this.useLowercase ? 0 : 1, color: $r('app.color.color_border') })
              .onClick(() => {
                this.toggleLowercase();
              })

            Button('大写 ABC')
              .fontSize(13)
              .backgroundColor(this.useUppercase ? $r('app.color.color_primary') : $r('app.color.color_background_card'))
              .fontColor(this.useUppercase ? Color.White : $r('app.color.color_text_secondary'))
              .height(36)
              .padding({ left: 16, right: 16 })
              .border({ width: this.useUppercase ? 0 : 1, color: $r('app.color.color_border') })
              .onClick(() => {
                this.toggleUppercase();
              })
              .margin({ left: 12 })
          }
          .width('100%')
          .margin({ bottom: 10 })

          Row() {
            Button('数字 123')
              .fontSize(13)
              .backgroundColor(this.useNumbers ? $r('app.color.color_primary') : $r('app.color.color_background_card'))
              .fontColor(this.useNumbers ? Color.White : $r('app.color.color_text_secondary'))
              .height(36)
              .padding({ left: 16, right: 16 })
              .border({ width: this.useNumbers ? 0 : 1, color: $r('app.color.color_border') })
              .onClick(() => {
                this.toggleNumbers();
              })

            Button('符号 !@#')
              .fontSize(13)
              .backgroundColor(this.useSymbols ? $r('app.color.color_primary') : $r('app.color.color_background_card'))
              .fontColor(this.useSymbols ? Color.White : $r('app.color.color_text_secondary'))
              .height(36)
              .padding({ left: 16, right: 16 })
              .border({ width: this.useSymbols ? 0 : 1, color: $r('app.color.color_border') })
              .onClick(() => {
                this.toggleSymbols();
              })
              .margin({ left: 12 })
          }
          .width('100%')
          .margin({ bottom: 10 })

          // 生成的密码显示
          Row() {
            Text('生成的密码: ')
              .fontSize(14)
              .fontColor($r('app.color.color_text_secondary'))

            Text(this.generatedPassword || '点击生成密码')
              .fontSize(14)
              .fontFamily('monospace')
              .fontColor(this.generatedPassword ? $r('app.color.color_primary') : $r('app.color.color_text_tertiary'))
              .layoutWeight(1)

            if (this.generatedPassword) {
              Button() {
                Text('📋')
                  .fontSize(24)
              }
              .padding({bottom: 10 })
                .backgroundColor($r('app.color.color_success'))
                .fontColor(Color.White)
                .onClick(() => {
                  this.copyToClipboard();
                })
            }
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .width('100%')
        .padding(16)
        .backgroundColor($r('app.color.color_background_card'))
        .borderRadius(12)
        .margin({ top: 10 })

        // 生成按钮
        Button('生成密码')
          .width('90%')
          .height(50)
          .fontSize(18)
          .backgroundColor($r('app.color.color_primary'))
          .fontColor(Color.White)
          .onClick(() => {
            this.generatePassword();
          })
          .margin({ top: 20, bottom: 20 })
      }

      // 使用说明
      Column() {
        Text('💡 使用说明')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .margin({ bottom: 8 })
          .alignSelf(ItemAlign.Start)

        Text('1. 点击"生成密码"生成随机强密码')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('2. 点击📋按钮自动复制密码')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('3. 在密码列表中点击"加载"可编辑已保存的密码')
          .fontSize(12)
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ bottom: 4 })
          .alignSelf(ItemAlign.Start)

        Text('4. 信用卡的支付密码在编辑模式下手动填写')
          .fontSize(12)
          .fontColor($r('app.color.color_warning'))
          .alignSelf(ItemAlign.Start)
      }
      .width('90%')
      .padding(16)
      .backgroundColor($r('app.color.color_background_card'))
      .borderRadius(12)
      .margin({ bottom: 30 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_background'))
    .justifyContent(FlexAlign.Start)
  }
}