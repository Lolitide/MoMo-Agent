/**
 * Resolve the short-lived receipt returned by image-generate.
 *
 * Ark image generation is synchronous, so this function does not poll Ark.
 * A valid receipt always represents an already completed image.
 */

'use strict';

const { readImageTaskToken, TaskTokenError } = require('./image-task-token');

const MAX_TASK_ID_LENGTH = 8192;

exports.handler = async (event, context, callback, logger) => {
  const result = getImageStatus(event, context, logger);
  return typeof callback === 'function' ? callback(result) : result;
};

function getImageStatus(event, context = {}, logger, dependencies = {}) {
  let input;
  try {
    input = parseEvent(event);
  } catch (error) {
    return failure(
      '',
      'INVALID_ARGUMENT',
      error instanceof Error ? error.message : '请求体必须是对象',
      false
    );
  }
  const taskId = typeof input.taskId === 'string' ? input.taskId.trim() : '';

  if (!taskId) {
    return failure('', 'INVALID_ARGUMENT', '缺少 taskId', false);
  }
  if (taskId.length > MAX_TASK_ID_LENGTH) {
    return failure('', 'INVALID_ARGUMENT', 'taskId 过长', false);
  }

  const taskSecret = readEnv(context, 'IMAGE_TASK_SECRET');
  if (!taskSecret || taskSecret.length < 32) {
    logger?.error('图片状态查询失败 [CONFIGURATION_ERROR]');
    return failure(taskId, 'CONFIGURATION_ERROR', '图片服务状态查询配置不完整', false);
  }

  try {
    const now = dependencies.now ? dependencies.now() : Date.now();
    const task = readImageTaskToken(taskId, taskSecret, now);
    return {
      success: true,
      taskId,
      status: 'success',
      progress: 100,
      imageUrl: task.imageUrl,
      taskExpiresAt: task.expiresAt
    };
  } catch (error) {
    const code = error instanceof TaskTokenError ? error.code : 'INTERNAL_ERROR';
    const message = error instanceof TaskTokenError ? error.message : '图片状态查询失败';
    logger?.error(`图片状态查询失败 [${code}]`);
    return failure(taskId, code, message, false);
  }
}

function parseEvent(event) {
  let value = event;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch (_) {
      throw new Error('请求必须是有效的 JSON 对象');
    }
  }

  if (value && typeof value === 'object' && !Array.isArray(value) && 'body' in value) {
    value = value.body;
    if (typeof value === 'string') {
      try {
        value = JSON.parse(value);
      } catch (_) {
        throw new Error('请求 body 必须是有效的 JSON 对象');
      }
    }
  }

  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('请求体必须是对象');
  }
  return value;
}

function failure(taskId, errorCode, error, retryable) {
  return {
    success: false,
    taskId,
    status: 'failed',
    errorCode,
    error,
    retryable
  };
}

function readEnv(context, name) {
  if (
    context &&
    context.env &&
    Object.prototype.hasOwnProperty.call(context.env, name)
  ) {
    const value = context.env[name];
    return typeof value === 'string' ? value.trim() : '';
  }
  const value = process.env[name];
  return typeof value === 'string' ? value.trim() : '';
}

exports.getImageStatus = getImageStatus;
exports._private = { parseEvent };
