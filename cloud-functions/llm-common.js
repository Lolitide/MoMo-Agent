'use strict';

const https = require('https');

const DEEPSEEK_HOST = 'api.deepseek.com';
const DEEPSEEK_PATH = '/chat/completions';
const DEFAULT_MODEL = 'deepseek-flash';
const DEFAULT_TIMEOUT_MS = 45000;
const MAX_TIMEOUT_MS = 55000;
const MAX_RESPONSE_BYTES = 1024 * 1024;

class FunctionError extends Error {
  constructor(code, message, retryable = false, details = undefined) {
    super(message);
    this.name = 'FunctionError';
    this.code = code;
    this.retryable = retryable;
    this.details = details;
  }
}

function parseEvent(event) {
  let value = event;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch (_) {
      throw new FunctionError('INVALID_ARGUMENT', '请求必须是有效的 JSON 对象');
    }
  }

  if (value && typeof value === 'object' && !Array.isArray(value) && 'body' in value) {
    value = value.body;
    if (typeof value === 'string') {
      try {
        value = JSON.parse(value);
      } catch (_) {
        throw new FunctionError('INVALID_ARGUMENT', '请求 body 必须是有效的 JSON 对象');
      }
    }
  }

  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new FunctionError('INVALID_ARGUMENT', '请求必须是 JSON 对象');
  }
  return value;
}

function requireString(value, field, options = {}) {
  const min = options.min === undefined ? 1 : options.min;
  const max = options.max === undefined ? 4000 : options.max;
  if (typeof value !== 'string') {
    throw new FunctionError('INVALID_ARGUMENT', `${field} 必须是字符串`);
  }
  const normalized = value.trim();
  if (normalized.length < min || normalized.length > max) {
    throw new FunctionError('INVALID_ARGUMENT', `${field} 长度必须在 ${min}-${max} 个字符之间`);
  }
  return normalized;
}

function optionalString(value, field, options = {}) {
  if (value === undefined || value === null || value === '') {
    return options.defaultValue === undefined ? '' : options.defaultValue;
  }
  return requireString(value, field, options);
}

function requireUserId(value) {
  // userId is only an untrusted correlation field. It is never proof of
  // identity or authorization for these stateless generation functions.
  return requireString(value, 'userId', { min: 1, max: 256 });
}

function stringArray(value, field, options = {}) {
  const required = options.required === true;
  const minItems = options.minItems === undefined ? (required ? 1 : 0) : options.minItems;
  const maxItems = options.maxItems === undefined ? 50 : options.maxItems;
  const maxItemLength = options.maxItemLength === undefined ? 500 : options.maxItemLength;
  const maxTotalLength = options.maxTotalLength === undefined ? 8000 : options.maxTotalLength;

  if (value === undefined || value === null) {
    if (!required && minItems === 0) return [];
    throw new FunctionError('INVALID_ARGUMENT', `${field} 是必填数组`);
  }
  if (!Array.isArray(value) || value.length < minItems || value.length > maxItems) {
    throw new FunctionError('INVALID_ARGUMENT', `${field} 必须包含 ${minItems}-${maxItems} 项`);
  }

  let totalLength = 0;
  const result = value.map((item, index) => {
    const normalized = requireString(item, `${field}[${index}]`, { min: 1, max: maxItemLength });
    totalLength += normalized.length;
    return normalized;
  });
  if (totalLength > maxTotalLength) {
    throw new FunctionError('INVALID_ARGUMENT', `${field} 总长度不能超过 ${maxTotalLength} 个字符`);
  }
  return result;
}

function chatContext(value) {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value) || value.length > 20) {
    throw new FunctionError('INVALID_ARGUMENT', 'context 必须是最多 20 项的数组');
  }

  let totalLength = 0;
  const result = value.map((item, index) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) {
      throw new FunctionError('INVALID_ARGUMENT', `context[${index}] 必须是对象`);
    }
    if (item.role !== 'user' && item.role !== 'assistant') {
      throw new FunctionError('INVALID_ARGUMENT', `context[${index}].role 只允许 user 或 assistant`);
    }
    const content = requireString(item.content, `context[${index}].content`, { min: 1, max: 2000 });
    totalLength += content.length;
    return { role: item.role, content };
  });

  if (totalLength > 12000) {
    throw new FunctionError('INVALID_ARGUMENT', 'context 总长度不能超过 12000 个字符');
  }
  return result;
}

function readEnv(context, name) {
  if (context && context.env && typeof context.env[name] === 'string') {
    return context.env[name].trim();
  }
  return typeof process.env[name] === 'string' ? process.env[name].trim() : '';
}

function getDeepSeekConfig(context) {
  const apiKey = readEnv(context, 'DEEPSEEK_API_KEY');
  if (!apiKey) {
    throw new FunctionError('CONFIGURATION_ERROR', 'LLM 服务尚未配置', false);
  }

  const model = readEnv(context, 'DEEPSEEK_MODEL') || DEFAULT_MODEL;
  const rawTimeout = readEnv(context, 'DEEPSEEK_TIMEOUT_MS');
  const parsedTimeout = rawTimeout ? Number(rawTimeout) : DEFAULT_TIMEOUT_MS;
  if (!Number.isInteger(parsedTimeout) || parsedTimeout < 1000 || parsedTimeout > MAX_TIMEOUT_MS) {
    throw new FunctionError(
      'CONFIGURATION_ERROR',
      `DEEPSEEK_TIMEOUT_MS 必须是 1000-${MAX_TIMEOUT_MS} 之间的整数`,
      false
    );
  }

  return { apiKey, model, timeoutMs: parsedTimeout };
}

function mapUpstreamStatus(statusCode) {
  if (statusCode === 401) return new FunctionError('UPSTREAM_AUTH_ERROR', 'LLM 服务认证失败', false, { statusCode });
  if (statusCode === 402) return new FunctionError('UPSTREAM_PAYMENT_REQUIRED', 'LLM 服务额度不足', false, { statusCode });
  if (statusCode === 429) return new FunctionError('UPSTREAM_RATE_LIMITED', 'LLM 服务繁忙，请稍后重试', true, { statusCode });
  if (statusCode === 408 || statusCode === 504) return new FunctionError('UPSTREAM_TIMEOUT', 'LLM 服务响应超时', true, { statusCode });
  if (statusCode >= 500) return new FunctionError('UPSTREAM_UNAVAILABLE', 'LLM 服务暂时不可用', true, { statusCode });
  return new FunctionError('UPSTREAM_REJECTED', 'LLM 服务拒绝了请求', false, { statusCode });
}

function normalizeUsage(usage) {
  if (!usage || typeof usage !== 'object') return undefined;
  const promptTokens = Number(usage.prompt_tokens);
  const completionTokens = Number(usage.completion_tokens);
  const totalTokens = Number(usage.total_tokens);
  if (![promptTokens, completionTokens, totalTokens].every(Number.isFinite)) return undefined;
  return { promptTokens, completionTokens, totalTokens };
}

function validateCompletionPayload(payload) {
  const choice = payload && Array.isArray(payload.choices) ? payload.choices[0] : undefined;
  const finishReason = choice && choice.finish_reason;
  if (finishReason === 'length') {
    throw new FunctionError('UPSTREAM_TRUNCATED', 'LLM 输出被截断，请重试', true);
  }
  if (finishReason === 'content_filter') {
    throw new FunctionError('UPSTREAM_CONTENT_FILTERED', 'LLM 未能生成该内容', false);
  }
  if (finishReason === 'insufficient_system_resource' || finishReason === 'aborted') {
    throw new FunctionError('UPSTREAM_UNAVAILABLE', 'LLM 服务暂时不可用', true);
  }

  const content = choice && choice.message && choice.message.content;
  if (typeof content !== 'string' || content.trim() === '') {
    throw new FunctionError('UPSTREAM_INVALID_RESPONSE', 'LLM 服务返回了无效响应', true);
  }
  return { content: content.trim(), usage: normalizeUsage(payload.usage) };
}

function callDeepSeek(messages, config, options = {}) {
  const requestImpl = options.requestImpl || https.request;
  const body = {
    model: config.model,
    messages,
    thinking: { type: 'disabled' },
    stream: false,
    max_tokens: options.maxTokens || 800,
    temperature: options.temperature === undefined ? 0.7 : options.temperature
  };
  if (options.jsonOutput) body.response_format = { type: 'json_object' };
  const postData = JSON.stringify(body);

  return new Promise((resolve, reject) => {
    let settled = false;
    const settle = (fn, value) => {
      if (settled) return;
      settled = true;
      fn(value);
    };

    const request = requestImpl({
      hostname: DEEPSEEK_HOST,
      path: DEEPSEEK_PATH,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${config.apiKey}`,
        'Content-Length': Buffer.byteLength(postData)
      }
    }, (response) => {
      let responseBody = '';
      let responseBytes = 0;

      response.on('data', (chunk) => {
        responseBytes += Buffer.byteLength(chunk);
        if (responseBytes > MAX_RESPONSE_BYTES) {
          request.destroy();
          settle(reject, new FunctionError('UPSTREAM_INVALID_RESPONSE', 'LLM 服务响应过大', true));
          return;
        }
        responseBody += chunk;
      });

      response.on('end', () => {
        if (settled) return;
        if (response.statusCode < 200 || response.statusCode >= 300) {
          settle(reject, mapUpstreamStatus(response.statusCode || 500));
          return;
        }
        try {
          const payload = JSON.parse(responseBody.trim());
          settle(resolve, validateCompletionPayload(payload));
        } catch (error) {
          if (error instanceof FunctionError) {
            settle(reject, error);
          } else {
            settle(reject, new FunctionError('UPSTREAM_INVALID_RESPONSE', 'LLM 服务返回了无法解析的响应', true));
          }
        }
      });
      response.on('error', () => {
        settle(reject, new FunctionError('UPSTREAM_UNAVAILABLE', 'LLM 服务暂时不可用', true));
      });
    });

    request.setTimeout(config.timeoutMs, () => {
      request.destroy();
      settle(reject, new FunctionError('UPSTREAM_TIMEOUT', 'LLM 服务响应超时', true));
    });
    request.on('error', (error) => {
      if (settled) return;
      const code = error && error.code === 'ETIMEDOUT' ? 'UPSTREAM_TIMEOUT' : 'UPSTREAM_UNAVAILABLE';
      const message = code === 'UPSTREAM_TIMEOUT' ? 'LLM 服务响应超时' : 'LLM 服务暂时不可用';
      settle(reject, new FunctionError(code, message, true));
    });
    request.write(postData);
    request.end();
  });
}

function parseJsonObject(content) {
  const stripped = content.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/i, '').trim();
  let parsed;
  try {
    parsed = JSON.parse(stripped);
  } catch (_) {
    throw new FunctionError('UPSTREAM_INVALID_RESPONSE', 'LLM 服务返回的 JSON 无法解析', true);
  }
  if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
    throw new FunctionError('UPSTREAM_INVALID_RESPONSE', 'LLM 服务返回的 JSON 结构无效', true);
  }
  return parsed;
}

function errorResponse(error, logger, operation) {
  const normalized = error instanceof FunctionError
    ? error
    : new FunctionError('INTERNAL_ERROR', '云函数内部错误', false);
  const status = normalized.details && normalized.details.statusCode
    ? ` status=${normalized.details.statusCode}`
    : '';
  if (logger && typeof logger.error === 'function') {
    logger.error(`${operation} failed: code=${normalized.code}${status}`);
  }
  return {
    success: false,
    error: {
      code: normalized.code,
      message: normalized.message,
      retryable: normalized.retryable
    }
  };
}

function respond(callback, result) {
  return typeof callback === 'function' ? callback(result) : result;
}

module.exports = {
  FunctionError,
  callDeepSeek,
  chatContext,
  errorResponse,
  getDeepSeekConfig,
  optionalString,
  parseEvent,
  parseJsonObject,
  requireString,
  requireUserId,
  respond,
  stringArray
};
