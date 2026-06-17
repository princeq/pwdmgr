import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@kit.BasicServicesKit';
import { PasswordEntry } from '../utils/CsvParser';

class DialogResult {
  index: number = 0;
}

@Component
export struct PasswordListItem {
  @ObjectLink item: PasswordEntry;
  @State isSelectionMode: boolean = false;
  @State isSelected: boolean = false;
  @State showPasswordId: string = '';
  onDelete?: () => void;
  onToggleSelect?: () => void;
  onLoadToEdit?: (item: PasswordEntry) => void;

  // 生命周期方法，用于调试
  aboutToAppear(): void {
    console.info('PasswordListItem aboutToAppear - isSelectionMode:', this.isSelectionMode);
    console.info('PasswordListItem aboutToAppear - isSelected:', this.isSelected);
  }

  getItemKey(): string {
    return this.item.website + '_' + this.item.username;
  }

  getPasswordDisplay(): string {
    if (this.showPasswordId === this.getItemKey()) {
      return this.item.password;
    }
    let passwordLength: number = this.item.password.length;
    let dotCount: number = passwordLength > 12 ? 12 : passwordLength;
    let dots: string = '';
    for (let i: number = 0; i < dotCount; i++) {
      dots = dots + '●';
    }
    return dots;
  }

  getTogglePasswordText(): string {
    return this.showPasswordId === this.getItemKey() ? '隐藏' : '显示';
  }

  toggleShowPassword(): void {
    if (this.showPasswordId === this.getItemKey()) {
      this.showPasswordId = '';
    } else {
      this.showPasswordId = this.getItemKey();
    }
  }

  async copyToClipboard(text: string, type: string): Promise<void> {
    try {
      let pasteData: pasteboard.PasteData = pasteboard.createPlainTextData(text);
      let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.setData(pasteData);
      this.showToast(`${type}已复制`);
    } catch (err) {
      let error = err as BusinessError;
      console.error('复制失败:', error.message);
      this.showToast('复制失败');
    }
  }

  showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 1500 });
  }

  getTimeString(): string {
    let timeStr: string = this.item.createdAt;
    if (timeStr.length > 16) {
      return timeStr.substring(0, 16);
    }
    return timeStr;
  }

  build() {
    Column() {
      // 调试显示当前模式
      Text(`模式: ${this.isSelectionMode ? '选择模式' : '普通模式'}`)
        .fontSize(10)
        .fontColor('#FF0000')
        .margin({ bottom: 5 })
        .visibility(Visibility.Visible)

      // ========== 标题行 ==========
      Row() {
        // 复选框区域
        Row() {
          if (this.isSelectionMode) {
            Text(this.isSelected ? '✅' : '⬜')
              .fontSize(24)
              .fontColor(this.isSelected ? '#007DFF' : '#666666')
          } else {
            Text('  ')
              .fontSize(24)
          }
        }
        .width(50)
        .height(50)
        .justifyContent(FlexAlign.Center)
        .border({ width: 1, color: '#FF0000' })  // 添加红色边框便于调试
        .onClick(() => {
          console.info('复选框被点击 - isSelectionMode:', this.isSelectionMode);
          if (this.isSelectionMode && this.onToggleSelect) {
            this.onToggleSelect();
          }
        })

        Text(this.item.website)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)

        if (!this.isSelectionMode) {
          Row() {
            Button('加载')
              .fontSize(12)
              .height(32)
              .backgroundColor('#007DFF')
              .onClick(() => {
                if (this.onLoadToEdit) {
                  this.onLoadToEdit(this.item);
                }
              })

            Button('删除')
              .fontSize(12)
              .height(32)
              .backgroundColor('#DC3545')
              .margin({ left: 8 })
              .onClick(() => {
                if (this.onDelete) {
                  this.onDelete();
                }
              })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 10 })

      // ... 其余行保持不变 ...

      // 用户名行
      Row() {
        Text('账号：')
          .fontSize(13)
          .fontColor('#666666')
          .width(40)

        Text(this.item.username)
          .fontSize(13)
          .fontColor('#333333')
          .layoutWeight(1)
          .wordBreak(WordBreak.BREAK_ALL)

        Button('复制')
          .fontSize(11)
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#6C757D')
          .onClick(() => {
            this.copyToClipboard(this.item.username, '账号');
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 密码行
      Row() {
        Text('密码：')
          .fontSize(13)
          .fontColor('#666666')
          .width(40)

        Text(this.getPasswordDisplay())
          .fontSize(13)
          .fontFamily('monospace')
          .fontColor('#333333')
          .layoutWeight(1)

        Button(this.getTogglePasswordText())
          .fontSize(11)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor('#28A745')
          .onClick(() => {
            this.toggleShowPassword();
          })

        Button('复制')
          .fontSize(11)
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#6C757D')
          .margin({ left: 6 })
          .onClick(() => {
            this.copyToClipboard(this.item.password, '密码');
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 网址行
      if (this.item.url && this.item.url.length > 0) {
        Row() {
          Text('网址：')
            .fontSize(12)
            .fontColor('#666666')
            .width(40)

          Text(this.item.url)
            .fontSize(12)
            .fontColor('#888888')
            .layoutWeight(1)
            .wordBreak(WordBreak.BREAK_ALL)
            .maxLines(2)

          Button('复制')
            .fontSize(11)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#6C757D')
            .onClick(() => {
              this.copyToClipboard(this.item.url, '网址');
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      // 备注行
      if (this.item.notes && this.item.notes.length > 0) {
        Row() {
          Text('备注：')
            .fontSize(12)
            .fontColor('#666666')
            .width(40)

          Text(this.item.notes)
            .fontSize(12)
            .fontColor('#888888')
            .layoutWeight(1)
            .wordBreak(WordBreak.BREAK_ALL)
            .maxLines(3)

          Button('复制')
            .fontSize(11)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#6C757D')
            .onClick(() => {
              this.copyToClipboard(this.item.notes, '备注');
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      // 时间行
      Row() {
        Text('时间：')
          .fontSize(11)
          .fontColor('#999999')
          .width(40)

        Text(this.getTimeString())
          .fontSize(11)
          .fontColor('#999999')
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isSelected ? '#E8F4FD' : '#f8f9fa')
    .borderRadius(12)
    .margin({ bottom: 10 })
  }
}