import argon2 from 'argon2';
import crypto from 'crypto';

export class HashUtil {
  /**
   * Hashes a plain password using Argon2id with memory/time cost parameters.
   */
  static async hashPassword(password: string): Promise<string> {
    return argon2.hash(password, {
      type: argon2.argon2id,
      memoryCost: 2 ** 16, // 64 MB
      timeCost: 3,
      parallelism: 1,
    });
  }

  /**
   * Verifies a plain password against an Argon2id hash.
   */
  static async verifyPassword(hash: string, plain: string): Promise<boolean> {
    try {
      return await argon2.verify(hash, plain);
    } catch {
      return false;
    }
  }

  /**
   * Generates a cryptographically random raw token string.
   */
  static generateRandomToken(bytes = 40): string {
    return crypto.randomBytes(bytes).toString('hex');
  }

  /**
   * Hashes a raw token using SHA-256 for secure database lookup.
   */
  static hashToken(token: string): string {
    return crypto.createHash('sha256').update(token).digest('hex');
  }
}
