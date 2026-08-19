import { describe, it, expect } from 'vitest';
import { HashUtil } from './hash.js';

describe('HashUtil (Security & Cryptography)', () => {
  it('should hash a password using Argon2id and verify correctly', async () => {
    const rawPassword = 'SuperSecretFitnessPassword123!';
    const hash = await HashUtil.hashPassword(rawPassword);

    expect(hash).toBeDefined();
    expect(hash.startsWith('$argon2id$')).toBe(true);

    const isMatch = await HashUtil.verifyPassword(hash, rawPassword);
    expect(isMatch).toBe(true);

    const isWrongMatch = await HashUtil.verifyPassword(hash, 'WrongPassword123!');
    expect(isWrongMatch).toBe(false);
  });

  it('should generate distinct cryptographically random tokens', () => {
    const token1 = HashUtil.generateRandomToken(40);
    const token2 = HashUtil.generateRandomToken(40);

    expect(token1).toHaveLength(80); // 40 bytes = 80 hex chars
    expect(token2).toHaveLength(80);
    expect(token1).not.toEqual(token2);
  });

  it('should deterministically produce SHA-256 hash for database token lookup', () => {
    const rawToken = 'test-token-12345';
    const hash1 = HashUtil.hashToken(rawToken);
    const hash2 = HashUtil.hashToken(rawToken);

    expect(hash1).toHaveLength(64); // SHA-256 is 64 hex chars
    expect(hash1).toEqual(hash2);
    expect(HashUtil.hashToken('other-token')).not.toEqual(hash1);
  });
});
