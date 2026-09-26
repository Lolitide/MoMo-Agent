/**
 * Stateless encrypted receipt shared by image-generate and image-get-status.
 * The receipt is a bearer credential: possession is required to recover the
 * short-lived Ark image URL, while the URL is not exposed in taskId plaintext.
 */

'use strict';

const crypto = require('crypto');

const TOKEN_PREFIX = 'img1';
const IV_BYTES = 12;
const MAX_TOKEN_LENGTH = 8192;

class TaskTokenError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'TaskTokenError';
    this.code = code;
  }
}

function createImageTaskToken(payload, secret) {
  validateSecret(secret);
  if (!payload || typeof payload.imageUrl !== 'string' || !Number.isSafeInteger(payload.expiresAt)) {
    throw new TaskTokenError('INVALID_TASK', '图片任务内容无效');
  }

  const iv = crypto.randomBytes(IV_BYTES);
  const key = crypto.createHash('sha256').update(secret, 'utf8').digest();
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  cipher.setAAD(Buffer.from(TOKEN_PREFIX, 'utf8'));

  const plaintext = Buffer.from(JSON.stringify({
    v: 1,
    imageUrl: payload.imageUrl,
    expiresAt: payload.expiresAt
  }), 'utf8');
  const ciphertext = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();

  const token = [
    TOKEN_PREFIX,
    toBase64Url(iv),
    toBase64Url(ciphertext),
    toBase64Url(tag)
  ].join('.');
  if (token.length > MAX_TOKEN_LENGTH) {
    throw new TaskTokenError('INVALID_TASK', '图片任务内容过长');
  }
  return token;
}

function readImageTaskToken(token, secret, now = Date.now()) {
  validateSecret(secret);
  if (typeof token !== 'string' || token.length === 0 || token.length > MAX_TOKEN_LENGTH) {
    throw new TaskTokenError('INVALID_TASK_ID', 'taskId 无效');
  }

  const parts = token.split('.');
  if (parts.length !== 4 || parts[0] !== TOKEN_PREFIX) {
    throw new TaskTokenError('INVALID_TASK_ID', 'taskId 无效');
  }

  try {
    const iv = fromBase64Url(parts[1]);
    const ciphertext = fromBase64Url(parts[2]);
    const tag = fromBase64Url(parts[3]);
    if (iv.length !== IV_BYTES || tag.length !== 16 || ciphertext.length === 0) {
      throw new Error('invalid token lengths');
    }

    const key = crypto.createHash('sha256').update(secret, 'utf8').digest();
    const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAAD(Buffer.from(TOKEN_PREFIX, 'utf8'));
    decipher.setAuthTag(tag);
    const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]);
    const payload = JSON.parse(plaintext.toString('utf8'));

    if (
      payload.v !== 1 ||
      typeof payload.imageUrl !== 'string' ||
      !Number.isSafeInteger(payload.expiresAt)
    ) {
      throw new Error('invalid payload');
    }
    if (now >= payload.expiresAt) {
      throw new TaskTokenError('TASK_EXPIRED', '图片任务已过期，请重新生成');
    }
    return payload;
  } catch (error) {
    if (error instanceof TaskTokenError) {
      throw error;
    }
    throw new TaskTokenError('INVALID_TASK_ID', 'taskId 无效或已被篡改');
  }
}

function validateSecret(secret) {
  if (typeof secret !== 'string' || secret.length < 32) {
    throw new TaskTokenError('CONFIGURATION_ERROR', 'IMAGE_TASK_SECRET 配置无效');
  }
}

function toBase64Url(buffer) {
  return buffer.toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function fromBase64Url(value) {
  if (typeof value !== 'string' || !/^[A-Za-z0-9_-]+$/.test(value)) {
    throw new Error('invalid base64url');
  }
  const padding = '='.repeat((4 - value.length % 4) % 4);
  const decoded = Buffer.from(
    value.replace(/-/g, '+').replace(/_/g, '/') + padding,
    'base64'
  );
  if (toBase64Url(decoded) !== value) {
    throw new Error('non-canonical base64url');
  }
  return decoded;
}

exports.createImageTaskToken = createImageTaskToken;
exports.readImageTaskToken = readImageTaskToken;
exports.TaskTokenError = TaskTokenError;
