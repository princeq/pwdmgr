import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 密码配置类
 */
export class SecurePasswordConfig {
  length: number = 16;
  useLowercase: boolean = true;
  useUppercase: boolean = true;
  useNumbers: boolean = true;
  useSymbols: boolean = true;
}

/**
 * 强度检查结果类
 */
export class StrengthResult {
  score: number = 0;
  strength: string = '';
  suggestions: string[] = [];
}

/**
 * 安全密码生成器
 * 使用系统级密码学安全随机数生成器
 */
export class SecurePasswordGenerator {

  /**
   * 根据配置生成安全密码
   * @param config 密码配置
   * @returns 生成的密码
   */
  static async generatePassword(config: SecurePasswordConfig): Promise<string> {
    // 构建字符集
    let charset: string = '';
    if (config.useLowercase) charset += 'abcdefghijklmnopqrstuvwxyz';
    if (config.useUppercase) charset += 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (config.useNumbers) charset += '0123456789';
    if (config.useSymbols) charset += '!@#$%^&*()_+-=[]{}|;:,.<>?';

    // 确保至少有一种字符类型
    if (charset.length === 0) {
      charset = 'abcdefghijklmnopqrstuvwxyz0123456789';
    }

    // 生成安全随机数
    let randomBytes: Uint8Array = await SecurePasswordGenerator.getSecureRandomBytes(config.length);

    // 使用随机数生成密码
    let result: string = '';
    for (let i: number = 0; i < config.length; i++) {
      let randomIndex: number = randomBytes[i] % charset.length;
      result += charset.charAt(randomIndex);
    }

    return result;
  }

  /**
   * 获取密码学安全的随机字节数组
   * @param length 需要生成的字节数
   * @returns 随机字节数组
   */
  private static async getSecureRandomBytes(length: number): Promise<Uint8Array> {
    try {
      // 1. 创建随机数生成器实例
      let rand: cryptoFramework.Random = cryptoFramework.createRandom();

      // 2. 生成指定长度的安全随机数
      let randOutput: cryptoFramework.DataBlob = await rand.generateRandom(length);

      return randOutput.data;
    } catch (error) {
      let e: BusinessError = error as BusinessError;
      console.error(`安全随机数生成失败: ${e.code}, ${e.message}`);
      // 降级方案：使用伪随机数（不应在生产环境使用）
      return SecurePasswordGenerator.fallbackRandomBytes(length);
    }
  }

  /**
   * 降级方案：使用伪随机数（仅在安全随机数失败时使用）
   */
  private static fallbackRandomBytes(length: number): Uint8Array {
    let bytes = new Uint8Array(length);
    for (let i: number = 0; i < length; i++) {
      bytes[i] = Math.floor(Math.random() * 256);
    }
    return bytes;
  }

  /**
   * 按强度生成密码
   * @param strength weak | medium | strong | veryStrong
   */
  static async generateByStrength(strength: string): Promise<string> {
    let config: SecurePasswordConfig = new SecurePasswordConfig();

    if (strength === 'weak') {
      config.length = 8;
      config.useLowercase = true;
      config.useUppercase = false;
      config.useNumbers = true;
      config.useSymbols = false;
    } else if (strength === 'medium') {
      config.length = 12;
      config.useLowercase = true;
      config.useUppercase = true;
      config.useNumbers = true;
      config.useSymbols = false;
    } else if (strength === 'strong') {
      config.length = 16;
      config.useLowercase = true;
      config.useUppercase = true;
      config.useNumbers = true;
      config.useSymbols = true;
    } else if (strength === 'veryStrong') {
      config.length = 24;
      config.useLowercase = true;
      config.useUppercase = true;
      config.useNumbers = true;
      config.useSymbols = true;
    } else {
      config.length = 16;
      config.useLowercase = true;
      config.useUppercase = true;
      config.useNumbers = true;
      config.useSymbols = true;
    }

    return await SecurePasswordGenerator.generatePassword(config);
  }

  /**
   * 验证密码强度
   * @param password 待验证的密码
   * @returns 强度评分和描述
   */
  static checkStrength(password: string): StrengthResult {
    let score: number = 0;
    let suggestions: string[] = [];

    // 长度评分
    if (password.length >= 8) score += 20;
    if (password.length >= 12) score += 15;
    if (password.length >= 16) score += 15;
    if (password.length < 8) suggestions.push('密码长度至少8位');

    // 字符类型评分
    let hasLower: boolean = /[a-z]/.test(password);
    let hasUpper: boolean = /[A-Z]/.test(password);
    let hasNumber: boolean = /\d/.test(password);
    let hasSymbol: boolean = /[^a-zA-Z0-9]/.test(password);

    if (hasLower) score += 10;
    if (hasUpper) score += 15;
    if (hasNumber) score += 15;
    if (hasSymbol) score += 25;

    if (!hasUpper) suggestions.push('包含大写字母');
    if (!hasNumber) suggestions.push('包含数字');
    if (!hasSymbol) suggestions.push('包含特殊符号');

    // 确定强度等级
    let strength: string;
    if (score < 30) strength = '极弱';
    else if (score < 50) strength = '弱';
    else if (score < 70) strength = '中等';
    else if (score < 85) strength = '强';
    else strength = '极强';

    let result: StrengthResult = new StrengthResult();
    result.score = Math.min(100, score);
    result.strength = strength;
    result.suggestions = suggestions;
    return result;
  }
}