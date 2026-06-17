import filePicker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { BusinessError } from '@kit.BasicServicesKit';

export class FilePicker {

  // 原有方法：只选 CSV
  static async selectCsvFile(): Promise<string> {
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

  // ✅ 新增：选择任意文件（不限制后缀）
  static async selectAnyFile(): Promise<string> {
    try {
      let documentPicker: filePicker.DocumentViewPicker = new filePicker.DocumentViewPicker();
      let selectResult: Array<string> = await documentPicker.select({
        maxSelectNumber: 1
        // 不设置 fileSuffixFilters，允许所有文件类型
      });

      if (selectResult && selectResult.length > 0) {
        console.info('选择的文件URI:', selectResult[0]);
        return selectResult[0];
      }
      return '';
    } catch (err) {
      let error = err as BusinessError;
      console.error('选择文件失败:', error.message);
      return '';
    }
  }

  // 读取文件内容
  static async readFileContent(uri: string): Promise<string> {
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
}