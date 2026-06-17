import { BusinessError } from '@kit.BasicServicesKit';

// 密码条目接口
export interface PasswordEntry {
  website: string;      // 网站/应用名称
  username: string;     // 用户名
  password: string;     // 密码
  url: string;          // 网址
  notes: string;        // 备注
  createdAt: string;    // 创建时间
}

export class CsvParser {

  /**
   * 解析CSV内容为PasswordEntry数组
   * 支持1Password的标准CSV格式
   */
  static parseCsvContent(content: string): PasswordEntry[] {
    let lines: string[] = content.split(/\r?\n/);
    if (lines.length < 2) {
      return [];
    }

    // 解析表头
    let headers: string[] = CsvParser.parseCsvLine(lines[0]);
    let result: PasswordEntry[] = [];

    // 查找各列索引
    let titleIndex: number = CsvParser.findHeaderIndex(headers, ['title', 'name', 'website', '站点', '名称']);
    let usernameIndex: number = CsvParser.findHeaderIndex(headers, ['username', 'user', 'email', '用户名', '账号']);
    let passwordIndex: number = CsvParser.findHeaderIndex(headers, ['password', 'pwd', '密码']);
    let urlIndex: number = CsvParser.findHeaderIndex(headers, ['url', 'website', '地址', '网址']);
    let notesIndex: number = CsvParser.findHeaderIndex(headers, ['notes', 'note', '备注', '说明']);

    // 解析数据行
    for (let i: number = 1; i < lines.length; i++) {
      let line: string = lines[i].trim();
      if (line === '') {
        continue;
      }

      let fields: string[] = CsvParser.parseCsvLine(line);

      let entry: PasswordEntry = {
        website: (titleIndex >= 0 && titleIndex < fields.length) ? CsvParser.cleanField(fields[titleIndex]) : '',
        username: (usernameIndex >= 0 && usernameIndex < fields.length) ? CsvParser.cleanField(fields[usernameIndex]) : '',
        password: (passwordIndex >= 0 && passwordIndex < fields.length) ? CsvParser.cleanField(fields[passwordIndex]) : '',
        url: (urlIndex >= 0 && urlIndex < fields.length) ? CsvParser.cleanField(fields[urlIndex]) : '',
        notes: (notesIndex >= 0 && notesIndex < fields.length) ? CsvParser.cleanField(fields[notesIndex]) : '',
        createdAt: new Date().toISOString()
      };

      // 跳过无效条目（没有网站名或没有密码）
      if (entry.website && entry.password) {
        result.push(entry);
      }
    }

    return result;
  }

  /**
   * 解析CSV单行（支持引号内的逗号）
   */
  static parseCsvLine(line: string): string[] {
    let result: string[] = [];
    let current: string = '';
    let inQuotes: boolean = false;

    for (let i: number = 0; i < line.length; i++) {
      let char: string = line[i];

      if (char === '"') {
        // 处理转义引号
        if (inQuotes && i + 1 < line.length && line[i + 1] === '"') {
          current += '"';
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char === ',' && !inQuotes) {
        result.push(current);
        current = '';
      } else {
        current += char;
      }
    }
    result.push(current);

    return result;
  }

  /**
   * 查找表头索引
   */
  static findHeaderIndex(headers: string[], possibleNames: string[]): number {
    for (let i: number = 0; i < headers.length; i++) {
      let header: string = headers[i].toLowerCase().replace(/"/g, '').trim();
      for (let j: number = 0; j < possibleNames.length; j++) {
        let name: string = possibleNames[j];
        if (header === name.toLowerCase() || header.includes(name.toLowerCase())) {
          return i;
        }
      }
    }
    return -1;
  }

  /**
   * 清理字段内容（去除首尾引号和空格）
   */
  static cleanField(field: string): string {
    if (!field) {
      return '';
    }
    let cleaned: string = field.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    }
    return cleaned.replace(/""/g, '"');
  }
}