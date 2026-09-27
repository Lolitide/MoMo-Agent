/**
 * Generate one image through Volcengine Ark Seedream.
 *
 * Ark's /api/v3/images/generations endpoint is synchronous in its default
 * non-streaming mode: a successful response contains the final image URL. The
 * client currently follows every generation call with image-get-status, so we
 * return an encrypted, short-lived receipt as taskId instead of inventing an
 * upstream asynchronous task.
 */

'use strict';

const https = require('https');
const net = require('net');
const fs = require('fs');
const path = require('path');
const { createImageTaskToken } = require('./image-task-token');

let characterConfig = null;

function loadCharacterConfig() {
  if (characterConfig) {
    return characterConfig;
  }
  try {
    const configPath = path.join(__dirname, 'character-config.json');
    const configData = fs.readFileSync(configPath, 'utf8');
    characterConfig = JSON.parse(configData);
    return characterConfig;
  } catch (error) {
    return null;
  }
}

const ARK_API_HOST = 'ark.cn-beijing.volces.com';
const ARK_API_PATH = '/api/v3/images/generations';
// Keep this below the client's current 60-second cloud-function timeout so the
// caller receives a structured failure instead of disconnecting first.
const DEFAULT_TIMEOUT_MS = 50000;
const MAX_RESPONSE_BYTES = 1024 * 1024;
const MAX_IMAGE_URL_LENGTH = 4096;
const MAX_PROMPT_LENGTH = 2000;
const MAX_USER_ID_LENGTH = 128;
const MAX_REFERENCE_IMAGE_COUNT = 2;
const MAX_REFERENCE_IMAGE_BYTES = 5 * 1024 * 1024;

class ImageFunctionError extends Error {
  constructor(code, message, retryable = false) {
    super(message);
    this.name = 'ImageFunctionError';
    this.code = code;
    this.retryable = retryable;
  }
}

exports.handler = async (event, context, callback, logger) => {
  const result = await generateImage(event, context, logger);
  return typeof callback === 'function' ? callback(result) : result;
};

async function generateImage(event, context = {}, logger, dependencies = {}) {
  try {
    const input = validateInput(event);
    const apiKey = readEnv(context, 'ARK_API_KEY');
    const model = readEnv(context, 'ARK_IMAGE_MODEL');
    const taskSecret = readEnv(context, 'IMAGE_TASK_SECRET');
    const allowedHostSuffixes = parseAllowedHostSuffixes(
      readEnv(context, 'ARK_IMAGE_URL_HOST_SUFFIXES')
    );

    if (!apiKey) {
      throw new ImageFunctionError(
        'CONFIGURATION_ERROR',
        '图片服务未配置 ARK_API_KEY',
        false
      );
    }
    if (!model) {
      throw new ImageFunctionError(
        'CONFIGURATION_ERROR',
        '图片服务未配置 ARK_IMAGE_MODEL',
        false
      );
    }
    if (!taskSecret || taskSecret.length < 32) {
      throw new ImageFunctionError(
        'CONFIGURATION_ERROR',
        '图片服务未配置至少 32 字符的 IMAGE_TASK_SECRET',
        false
      );
    }
    if (allowedHostSuffixes.length === 0) {
      throw new ImageFunctionError(
        'CONFIGURATION_ERROR',
        '图片服务未配置 ARK_IMAGE_URL_HOST_SUFFIXES',
        false
      );
    }

    logger?.info('图片生成请求已通过输入与服务配置校验');

    const timeoutMs = parseBoundedInteger(
      readEnv(context, 'ARK_IMAGE_TIMEOUT_MS'),
      DEFAULT_TIMEOUT_MS,
      5000,
      55000
    );

    // 构建 API 请求参数
    const apiParams = {
      model,
      prompt: enhancePrompt(input.prompt, input.style, input.useCharacterReference),
      size: parseSize(input.size),
      response_format: 'url',
      watermark: false
    };

    const config = dependencies.characterConfig || loadCharacterConfig();
    const referenceImages = buildReferenceImageInputs(config, input.useCharacterReference, __dirname);
    if (input.useCharacterReference && referenceImages.length === 0) {
      throw new ImageFunctionError(
        'CONFIGURATION_ERROR',
        '已启用图生图，但未配置主角图或参考图 URL',
        false
      );
    }
    if (referenceImages.length > 0) {
      // Seedream 图生图使用 image 字段；多图输入时传 URL 数组。
      apiParams.image = referenceImages.length === 1 ? referenceImages[0] : referenceImages;
      logger?.info(`使用 ${referenceImages.length} 张内置参考图生成图片`);
    }

    const callApi = dependencies.callArkImageAPI || callArkImageAPI;
    const upstream = await callApi(apiParams, apiKey, timeoutMs);

    const imageUrl = extractAndValidateImageUrl(upstream, allowedHostSuffixes);
    const now = dependencies.now || Date.now;
    const taskTtlMs = parseBoundedInteger(
      readEnv(context, 'IMAGE_TASK_TTL_MS'),
      15 * 60 * 1000,
      60 * 1000,
      23 * 60 * 60 * 1000
    );
    const expiresAt = now() + taskTtlMs;
    const taskId = createImageTaskToken({ imageUrl, expiresAt }, taskSecret);

    return {
      success: true,
      taskId,
      status: 'success',
      imageUrl,
      taskExpiresAt: expiresAt
    };
  } catch (error) {
    const safeError = normalizeError(error);
    logger?.error(`图片生成失败 [${safeError.code}]`);
    return {
      success: false,
      status: 'failed',
      errorCode: safeError.code,
      error: safeError.message,
      retryable: safeError.retryable
    };
  }
}

function validateInput(event) {
  const input = parseEvent(event);

  const userId = normalizeString(input.userId);
  const prompt = normalizeString(input.prompt);
  const style = normalizeString(input.style) || 'anime';
  const size = normalizeString(input.size) || '1024x1024';
  const useCharacterReference = input.useCharacterReference === true;

  if (!userId) {
    throw new ImageFunctionError('INVALID_ARGUMENT', '缺少 userId');
  }
  if (userId.length > MAX_USER_ID_LENGTH) {
    throw new ImageFunctionError('INVALID_ARGUMENT', 'userId 过长');
  }
  if (!prompt) {
    throw new ImageFunctionError('INVALID_ARGUMENT', '缺少 prompt');
  }
  if (prompt.length > MAX_PROMPT_LENGTH) {
    throw new ImageFunctionError(
      'INVALID_ARGUMENT',
      `prompt 不能超过 ${MAX_PROMPT_LENGTH} 个字符`
    );
  }

  return { userId, prompt, style, size, useCharacterReference };
}

/**
 * Resolve the built-in reference images. The legacy referenceImageUrl remains
 * supported as the scene/style reference; protagonistImageUrl is the fixed
 * character appearance reference.
 */
function buildReferenceImageInputs(config, enabled, assetRoot = __dirname) {
  if (!enabled || !config || !config.character) {
    return [];
  }

  const candidates = [
    { url: config.character.protagonistImageUrl, file: config.character.protagonistImageFile },
    { url: config.character.referenceImageUrl, file: config.character.referenceImageFile }
  ];
  const result = [];
  for (const candidate of candidates) {
    if (result.length >= MAX_REFERENCE_IMAGE_COUNT || !candidate) {
      continue;
    }
    if (typeof candidate.url === 'string') {
      const url = candidate.url.trim();
      if (url && url.length <= MAX_IMAGE_URL_LENGTH && isReferenceImageUrl(url) && !result.includes(url)) {
        result.push(url);
        continue;
      }
    }
    if (typeof candidate.file === 'string') {
      const dataUrl = readReferenceImageAsset(candidate.file, assetRoot);
      if (dataUrl && !result.includes(dataUrl)) {
        result.push(dataUrl);
      }
    }
  }
  return result;
}

function readReferenceImageAsset(relativePath, assetRoot) {
  const normalized = relativePath.trim();
  if (!normalized || normalized.startsWith('/') || normalized.includes('\\')) {
    return '';
  }
  const resolvedRoot = path.resolve(assetRoot);
  const resolvedPath = path.resolve(resolvedRoot, normalized);
  const relative = path.relative(resolvedRoot, resolvedPath);
  if (!relative || relative.startsWith('..') || path.isAbsolute(relative)) {
    return '';
  }
  try {
    const stat = fs.statSync(resolvedPath);
    if (!stat.isFile() || stat.size > MAX_REFERENCE_IMAGE_BYTES) {
      return '';
    }
    const extension = path.extname(resolvedPath).toLowerCase();
    const mimeTypes = { '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp' };
    const mimeType = mimeTypes[extension];
    if (!mimeType) {
      return '';
    }
    return `data:${mimeType};base64,${fs.readFileSync(resolvedPath).toString('base64')}`;
  } catch (_) {
    return '';
  }
}

function isReferenceImageUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'https:' && !parsed.username && !parsed.password;
  } catch (_) {
    return false;
  }
}

function parseEvent(event) {
  let value = event;
  if (typeof value === 'string') {
    try {
      value = JSON.parse(value);
    } catch (_) {
      throw new ImageFunctionError('INVALID_ARGUMENT', '请求必须是有效的 JSON 对象');
    }
  }

  if (value && typeof value === 'object' && !Array.isArray(value) && 'body' in value) {
    value = value.body;
    if (typeof value === 'string') {
      try {
        value = JSON.parse(value);
      } catch (_) {
        throw new ImageFunctionError('INVALID_ARGUMENT', '请求 body 必须是有效的 JSON 对象');
      }
    }
  }

  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new ImageFunctionError('INVALID_ARGUMENT', '请求体必须是对象');
  }
  return value;
}

function normalizeString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function enhancePrompt(prompt, style, useCharacterReference = false) {
  const config = loadCharacterConfig();

  let enhancedPrompt = prompt;

  // 如果启用角色参考且配置存在，添加角色一致性描述
  if (useCharacterReference && config && config.character) {
    const characterDesc = config.character.appearance;
    const styleKeywords = config.character.styleKeywords;
    // 确保 prompt 以角色描述开头（如果还没有的话）
    if (!prompt.toLowerCase().includes('girl') && !prompt.toLowerCase().includes(config.character.name.toLowerCase())) {
      enhancedPrompt = `${characterDesc}, ${prompt}`;
    }
    if (styleKeywords) {
      enhancedPrompt = `${enhancedPrompt}, ${styleKeywords}`;
    }
  }

  const stylePresets = {
    comic: 'comic style, manga art, clean lines, vibrant colors',
    anime: 'anime style, detailed illustration, high quality',
    cute: 'cute kawaii style, chibi, adorable, pastel colors',
    realistic: 'realistic style, detailed, photorealistic'
  };
  const styleText = stylePresets[style] || stylePresets.anime;

  // 添加质量标签
  const qualityTags = config?.comicStyle?.quality || 'masterpiece, best quality';

  return `${enhancedPrompt}, ${styleText}, ${qualityTags}`;
}

function parseSize(size) {
  const supportedSizes = new Set([
    '1024x1024',
    '768x1024',
    '1024x768'
  ]);
  return supportedSizes.has(size) ? size : '1024x1024';
}

function readEnv(context, name) {
  if (
    context &&
    context.env &&
    Object.prototype.hasOwnProperty.call(context.env, name)
  ) {
    return normalizeString(context.env[name]);
  }
  return normalizeString(process.env[name]);
}

function parseAllowedHostSuffixes(value) {
  return value
    .split(',')
    .map((part) => part.trim().toLowerCase().replace(/^\.+/, ''))
    .filter(Boolean);
}

function parseBoundedInteger(value, fallback, min, max) {
  if (!value) {
    return fallback;
  }
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < min || parsed > max) {
    throw new ImageFunctionError(
      'CONFIGURATION_ERROR',
      `环境变量数值必须在 ${min} 到 ${max} 之间`
    );
  }
  return parsed;
}

function extractAndValidateImageUrl(result, allowedHostSuffixes) {
  const imageUrl = result && Array.isArray(result.data) ? result.data[0]?.url : '';
  if (
    typeof imageUrl !== 'string' ||
    !imageUrl ||
    imageUrl.length > MAX_IMAGE_URL_LENGTH
  ) {
    throw new ImageFunctionError(
      'UPSTREAM_RESPONSE_ERROR',
      '图片服务未返回图片 URL',
      true
    );
  }

  let parsed;
  try {
    parsed = new URL(imageUrl);
  } catch (_) {
    throw new ImageFunctionError(
      'UPSTREAM_RESPONSE_ERROR',
      '图片服务返回了无效 URL',
      true
    );
  }

  const hostname = parsed.hostname.toLowerCase();
  if (parsed.protocol !== 'https:' || parsed.username || parsed.password || !isPublicHostname(hostname)) {
    throw new ImageFunctionError(
      'UPSTREAM_RESPONSE_ERROR',
      '图片服务返回了不安全的 URL',
      false
    );
  }

  const allowed = allowedHostSuffixes.some((suffix) =>
    hostname === suffix || hostname.endsWith(`.${suffix}`)
  );
  if (!allowed) {
    throw new ImageFunctionError(
      'UPSTREAM_RESPONSE_ERROR',
      '图片 URL 域名不在允许列表中',
      false
    );
  }

  return parsed.toString();
}

function isPublicHostname(hostname) {
  const normalizedHostname = hostname.startsWith('[') && hostname.endsWith(']')
    ? hostname.slice(1, -1)
    : hostname;

  if (normalizedHostname === 'localhost' || normalizedHostname.endsWith('.localhost')) {
    return false;
  }

  const ipVersion = net.isIP(normalizedHostname);
  if (ipVersion === 4) {
    const octets = normalizedHostname.split('.').map(Number);
    return !(
      octets[0] === 10 ||
      octets[0] === 127 ||
      octets[0] === 0 ||
      (octets[0] === 169 && octets[1] === 254) ||
      (octets[0] === 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] === 192 && octets[1] === 168)
    );
  }
  if (ipVersion === 6) {
    return !(
      normalizedHostname === '::1' ||
      normalizedHostname.startsWith('fc') ||
      normalizedHostname.startsWith('fd') ||
      normalizedHostname.startsWith('fe80:')
    );
  }
  return true;
}

function callArkImageAPI(params, apiKey, timeoutMs = DEFAULT_TIMEOUT_MS) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(params);
    let settled = false;

    const finish = (fn, value) => {
      if (settled) {
        return;
      }
      settled = true;
      fn(value);
    };

    const req = https.request({
      hostname: ARK_API_HOST,
      path: ARK_API_PATH,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'Content-Length': Buffer.byteLength(body)
      }
    }, (res) => {
      const chunks = [];
      let totalBytes = 0;

      res.on('data', (chunk) => {
        totalBytes += chunk.length;
        if (totalBytes > MAX_RESPONSE_BYTES) {
          req.destroy(new ImageFunctionError(
            'UPSTREAM_RESPONSE_ERROR',
            '图片服务响应过大',
            true
          ));
          return;
        }
        chunks.push(chunk);
      });

      res.on('end', () => {
        if (settled) {
          return;
        }
        let result;
        try {
          result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
        } catch (_) {
          finish(reject, new ImageFunctionError(
            'UPSTREAM_RESPONSE_ERROR',
            `图片服务响应无法解析（HTTP ${res.statusCode || 0}）`,
            true
          ));
          return;
        }

        if (!res.statusCode || res.statusCode < 200 || res.statusCode >= 300 || result.error) {
          const retryable = res.statusCode === 429 || (res.statusCode || 0) >= 500;
          finish(reject, new ImageFunctionError(
            'UPSTREAM_HTTP_ERROR',
            `图片服务请求失败（HTTP ${res.statusCode || 0}）`,
            retryable
          ));
          return;
        }
        finish(resolve, result);
      });

      res.on('aborted', () => finish(reject, new ImageFunctionError(
        'UPSTREAM_RESPONSE_ERROR',
        '图片服务响应中断',
        true
      )));
    });

    req.setTimeout(timeoutMs, () => {
      req.destroy(new ImageFunctionError(
        'UPSTREAM_TIMEOUT',
        `图片服务在 ${timeoutMs}ms 内未完成`,
        true
      ));
    });
    req.on('error', (error) => {
      finish(reject, error instanceof ImageFunctionError ? error : new ImageFunctionError(
        'UPSTREAM_NETWORK_ERROR',
        '无法连接图片服务',
        true
      ));
    });
    req.write(body);
    req.end();
  });
}

function normalizeError(error) {
  if (error instanceof ImageFunctionError) {
    return error;
  }
  return new ImageFunctionError('INTERNAL_ERROR', '图片生成失败', false);
}

exports.generateImage = generateImage;
exports.callArkImageAPI = callArkImageAPI;
exports.ImageFunctionError = ImageFunctionError;
exports._private = {
  enhancePrompt,
  buildReferenceImageInputs,
  readReferenceImageAsset,
  extractAndValidateImageUrl,
  parseAllowedHostSuffixes,
  parseEvent,
  parseSize,
  validateInput,
  loadCharacterConfig
};
