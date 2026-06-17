import { PasswordStorage } from '../utils/PasswordStorage';
import { PasswordEntry } from '../utils/CsvParser';
import { common } from '@kit.AbilityKit';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import { BusinessError } from '@kit.BasicServicesKit';
import router from '@ohos.router';

class DialogButton {
  text: string = '';
  color: string = '';
}

class DialogResult {
  index: number = 0;
}

@Entry
@Component
struct PasswordListPage {
  @State passwords: PasswordEntry[] = [];
  @State filteredPasswords: PasswordEntry[] = [];
  @State isLoading: boolean = true;
  @State showPasswordId: string = '';
  @State isSelectionMode: boolean = false;
  @State selectedItems: string[] = [];
  @State searchText: string = '';
  private passwordStorage: PasswordStorage | null = null;

  loadToEdit(item: PasswordEntry): void {
    let key: string = this.getItemKey(item);
    router.pushUrl({
      url: 'pages/PasswordGenerator',
      params: { editKey: key }
    }).catch((err: Error) => {
      console.error('跳转失败:', err.message);
      this.showToast('跳转失败');
    });
  }

  aboutToAppear(): void {
    let context: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.passwordStorage = new PasswordStorage(context);
    this.loadPasswords();
  }

  async loadPasswords(): Promise<void> {
    this.isLoading = true;
    if (this.passwordStorage) {
      this.passwords = await this.passwordStorage.getAllPasswords();
      this.filterPasswords();
    }
    this.isLoading = false;
  }

  filterPasswords(): void {
    if (!this.searchText || this.searchText.trim() === '') {
      let newList: PasswordEntry[] = [];
      for (let i: number = 0; i < this.passwords.length; i++) {
        newList.push(this.passwords[i]);
      }
      this.filteredPasswords = newList;
    } else {
      let searchLower: string = this.searchText.toLowerCase();
      let filtered: PasswordEntry[] = [];
      for (let i: number = 0; i < this.passwords.length; i++) {
        let item: PasswordEntry = this.passwords[i];
        let websiteMatch: boolean = item.website.toLowerCase().indexOf(searchLower) !== -1;
        let usernameMatch: boolean = item.username.toLowerCase().indexOf(searchLower) !== -1;
        let urlMatch: boolean = false;
        if (item.url) {
          urlMatch = item.url.toLowerCase().indexOf(searchLower) !== -1;
        }
        if (websiteMatch || usernameMatch || urlMatch) {
          filtered.push(item);
        }
      }
      this.filteredPasswords = filtered;
    }
  }

  onSearchChange(value: string): void {
    this.searchText = value;
    this.filterPasswords();
  }

  toggleSelectionMode(): void {
    this.isSelectionMode = !this.isSelectionMode;
    if (!this.isSelectionMode) {
      this.selectedItems = [];
    }
  }

  getItemKey(item: PasswordEntry): string {
    return item.website + '_' + item.username;
  }

  toggleSelectItem(item: PasswordEntry): void {
    let key: string = this.getItemKey(item);
    let index: number = this.selectedItems.indexOf(key);
    if (index !== -1) {
      this.selectedItems.splice(index, 1);
    } else {
      this.selectedItems.push(key);
    }
  }

  isSelected(item: PasswordEntry): boolean {
    let key: string = this.getItemKey(item);
    return this.selectedItems.indexOf(key) !== -1;
  }

  selectAll(): void {
    if (this.selectedItems.length === this.filteredPasswords.length) {
      this.selectedItems = [];
    } else {
      let newSelected: string[] = [];
      for (let i: number = 0; i < this.filteredPasswords.length; i++) {
        let item: PasswordEntry = this.filteredPasswords[i];
        newSelected.push(this.getItemKey(item));
      }
      this.selectedItems = newSelected;
    }
  }

  async batchDelete(): Promise<void> {
    if (this.selectedItems.length === 0) {
      this.showToast('请先选择要删除的项目');
      return;
    }

    let cancelButton: DialogButton = new DialogButton();
    cancelButton.text = '取消';
    cancelButton.color = '#999999';

    let confirmButton: DialogButton = new DialogButton();
    confirmButton.text = '确认删除';
    confirmButton.color = '#DC3545';

    let buttons: DialogButton[] = [cancelButton, confirmButton];

    promptAction.showDialog({
      title: '确认删除',
      message: `确定要删除选中的 ${this.selectedItems.length} 条密码吗？此操作不可恢复。`,
      buttons: buttons
    }).then((result: DialogResult) => {
      if (result.index === 1 && this.passwordStorage) {
        this.doBatchDelete();
      }
    });
  }

  async doBatchDelete(): Promise<void> {
    if (!this.passwordStorage) return;

    let successCount: number = 0;
    let failCount: number = 0;

    let itemsToDelete: PasswordEntry[] = [];
    for (let i: number = 0; i < this.filteredPasswords.length; i++) {
      let item: PasswordEntry = this.filteredPasswords[i];
      let key: string = this.getItemKey(item);
      if (this.selectedItems.indexOf(key) !== -1) {
        itemsToDelete.push(item);
      }
    }

    for (let i: number = 0; i < itemsToDelete.length; i++) {
      let item: PasswordEntry = itemsToDelete[i];
      let success: boolean = await this.passwordStorage.deletePassword(item.website, item.username);
      if (success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    await this.loadPasswords();
    this.isSelectionMode = false;
    this.selectedItems = [];
    this.showToast(`删除完成：成功 ${successCount} 条，失败 ${failCount} 条`);
  }

  async deletePassword(entry: PasswordEntry): Promise<void> {
    let cancelButton: DialogButton = new DialogButton();
    cancelButton.text = '取消';
    cancelButton.color = '#999999';

    let confirmButton: DialogButton = new DialogButton();
    confirmButton.text = '删除';
    confirmButton.color = '#DC3545';

    let buttons: DialogButton[] = [cancelButton, confirmButton];

    promptAction.showDialog({
      title: '确认删除',
      message: `确定要删除 "${entry.website}" 的密码吗？`,
      buttons: buttons
    }).then((result: DialogResult) => {
      if (result.index === 1 && this.passwordStorage) {
        this.doDeletePassword(entry);
      }
    });
  }

  async doDeletePassword(entry: PasswordEntry): Promise<void> {
    if (!this.passwordStorage) return;

    let success: boolean = await this.passwordStorage.deletePassword(entry.website, entry.username);
    if (success) {
      await this.loadPasswords();
      this.showToast('删除成功');
    } else {
      this.showToast('删除失败');
    }
  }

  toggleShowPassword(entry: PasswordEntry): void {
    let id: string = this.getItemKey(entry);
    if (this.showPasswordId === id) {
      this.showPasswordId = '';
    } else {
      this.showPasswordId = id;
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

  getPasswordDisplay(entry: PasswordEntry): string {
    let id: string = this.getItemKey(entry);
    if (this.showPasswordId === id) {
      return entry.password;
    }
    let passwordLength: number = entry.password.length;
    let dotCount: number = passwordLength > 12 ? 12 : passwordLength;
    let dots: string = '';
    for (let i: number = 0; i < dotCount; i++) {
      dots = dots + '●';
    }
    return dots;
  }

  getTogglePasswordText(entry: PasswordEntry): string {
    return this.showPasswordId === this.getItemKey(entry) ? '隐藏' : '显示';
  }

  getTimeString(entry: PasswordEntry): string {
    let timeStr: string = entry.createdAt;
    if (timeStr.length > 16) {
      return timeStr.substring(0, 16);
    }
    return timeStr;
  }

  showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 1500 });
  }

  // ========== UI 构建 ==========

  build() {
    Column() {
      // 标题栏
      Row() {
        if (this.isSelectionMode) {
          Text(`已选择 ${this.selectedItems.length} 项`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_primary'))
            .layoutWeight(1)

          Button('全选')
            .fontSize(14)
            .height(36)
            .backgroundColor($r('app.color.color_info'))
            .fontColor(Color.White)
            .margin({ right: 8 })
            .onClick(() => {
              this.selectAll();
            })

          Button('删除')
            .fontSize(14)
            .height(36)
            .backgroundColor($r('app.color.color_error'))
            .fontColor(Color.White)
            .margin({ right: 8 })
            .onClick(() => {
              this.batchDelete();
            })

          Button('取消')
            .fontSize(14)
            .height(36)
            .backgroundColor($r('app.color.color_text_tertiary'))
            .fontColor(Color.White)
            .onClick(() => {
              this.toggleSelectionMode();
            })
        } else {
          Text('📋 密码列表')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.color_text_primary'))
            .layoutWeight(1)

          Button('选择')
            .fontSize(14)
            .height(36)
            .backgroundColor($r('app.color.color_info'))
            .fontColor(Color.White)
            .margin({ right: 8 })
            .onClick(() => {
              this.toggleSelectionMode();
            })

          Button('刷新')
            .fontSize(14)
            .height(36)
            .backgroundColor($r('app.color.color_primary'))
            .fontColor(Color.White)
            .onClick(() => {
              this.loadPasswords();
            })
        }
      }
      .width('90%')
      .margin({ top: 20, bottom: 10 })

      // 搜索框
      if (!this.isSelectionMode) {
        TextInput({ placeholder: '🔍 搜索网站、账号或网址', text: this.searchText })
          .width('90%')
          .height(44)
          .backgroundColor($r('app.color.color_background_card'))
          .fontColor($r('app.color.color_text_primary'))
          .placeholderColor($r('app.color.color_text_tertiary'))
          .borderRadius(22)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.onSearchChange(value);
          })
          .margin({ bottom: 10 })
      }

      if (this.isLoading) {
        Text('加载中...')
          .fontColor($r('app.color.color_text_secondary'))
          .margin({ top: 50 })
      } else if (this.filteredPasswords.length === 0) {
        Column() {
          Text('📭')
            .fontSize(60)
            .margin({ top: 100, bottom: 20 })
          Text(this.searchText ? '没有找到匹配的密码' : '暂无密码')
            .fontSize(16)
            .fontColor($r('app.color.color_text_secondary'))
          if (this.searchText) {
            Text('试试其他关键词')
              .fontSize(14)
              .fontColor($r('app.color.color_text_tertiary'))
              .margin({ top: 10 })
          } else {
            Text('请先导入CSV文件')
              .fontSize(14)
              .fontColor($r('app.color.color_text_tertiary'))
              .margin({ top: 10 })
          }
        }
        .width('100%')
      } else {
        Row() {
          Text(`共 ${this.filteredPasswords.length} 条密码`)
            .fontSize(14)
            .fontColor($r('app.color.color_text_secondary'))

          Blank()

          if (this.searchText) {
            Text(`搜索: ${this.searchText}`)
              .fontSize(12)
              .fontColor($r('app.color.color_primary'))
          }
        }
        .width('90%')
        .margin({ bottom: 10 })

        List() {
          ForEach(this.filteredPasswords, (item: PasswordEntry) => {
            ListItem() {
              this.buildListItem(item)
            }
          })
        }
        .width('90%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.color_background'))
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  buildListItem(item: PasswordEntry) {
    Column() {
      // 标题行
      Row() {
        // 复选框区域
        Row() {
          if (this.isSelectionMode) {
            Text(this.isSelected(item) ? '✅' : '⬜')
              .fontSize(20)
              .fontColor(this.isSelected(item) ? $r('app.color.color_primary') : $r('app.color.color_text_tertiary'))
          } else {
            Text('  ')
              .fontSize(20)
          }
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          if (this.isSelectionMode) {
            this.toggleSelectItem(item);
          }
        })

        Text(item.website)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)

        if (!this.isSelectionMode) {
          Row() {
            Button('加载')
              .fontSize(12)
              .height(32)
              .backgroundColor($r('app.color.color_primary'))
              .fontColor(Color.White)
              .onClick(() => {
                this.loadToEdit(item);
              })

            Button('删除')
              .fontSize(12)
              .height(32)
              .backgroundColor($r('app.color.color_error'))
              .fontColor(Color.White)
              .margin({ left: 8 })
              .onClick(() => {
                this.deletePassword(item);
              })
          }
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: 10 })

      // 用户名行
      Row() {
        Text('账号：')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .width(40)

        Text(item.username)
          .fontSize(13)
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)
          .wordBreak(WordBreak.BREAK_ALL)

        Button('复制')
          .fontSize(11)
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.color_info'))
          .fontColor(Color.White)
          .onClick(() => {
            this.copyToClipboard(item.username, '账号');
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 密码行
      Row() {
        Text('密码：')
          .fontSize(13)
          .fontColor($r('app.color.color_text_secondary'))
          .width(40)

        Text(this.getPasswordDisplay(item))
          .fontSize(13)
          .fontFamily('monospace')
          .fontColor($r('app.color.color_text_primary'))
          .layoutWeight(1)

        Button(this.getTogglePasswordText(item))
          .fontSize(11)
          .height(28)
          .padding({ left: 10, right: 10 })
          .backgroundColor($r('app.color.color_success'))
          .fontColor(Color.White)
          .onClick(() => {
            this.toggleShowPassword(item);
          })

        Button('复制')
          .fontSize(11)
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor($r('app.color.color_info'))
          .fontColor(Color.White)
          .margin({ left: 6 })
          .onClick(() => {
            this.copyToClipboard(item.password, '密码');
          })
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 网址行
      if (item.url && item.url.length > 0) {
        Row() {
          Text('网址：')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .width(40)

          Text(item.url)
            .fontSize(12)
            .fontColor($r('app.color.color_text_tertiary'))
            .layoutWeight(1)
            .wordBreak(WordBreak.BREAK_ALL)
            .maxLines(2)

          Button('复制')
            .fontSize(11)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.color_info'))
            .fontColor(Color.White)
            .onClick(() => {
              this.copyToClipboard(item.url, '网址');
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      // 备注行
      if (item.notes && item.notes.length > 0) {
        Row() {
          Text('备注：')
            .fontSize(12)
            .fontColor($r('app.color.color_text_secondary'))
            .width(40)

          Text(item.notes)
            .fontSize(12)
            .fontColor($r('app.color.color_text_tertiary'))
            .layoutWeight(1)
            .wordBreak(WordBreak.BREAK_ALL)
            .maxLines(3)

          Button('复制')
            .fontSize(11)
            .height(28)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.color_info'))
            .fontColor(Color.White)
            .onClick(() => {
              this.copyToClipboard(item.notes, '备注');
            })
        }
        .width('100%')
        .margin({ bottom: 6 })
      }

      // 时间行
      Row() {
        Text('时间：')
          .fontSize(11)
          .fontColor($r('app.color.color_text_tertiary'))
          .width(40)

        Text(this.getTimeString(item))
          .fontSize(11)
          .fontColor($r('app.color.color_text_tertiary'))
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.isSelected(item) ? $r('app.color.color_selected_bg') : $r('app.color.color_background_card'))
    .borderRadius(12)
    .margin({ bottom: 10 })
  }
}