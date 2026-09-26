/**
 * ============================================================================
 * 云函数：生成图片（即梦AI）
 * ============================================================================
 * 功能：调用火山引擎即梦API生成图片
 * 输入：{ userId, prompt, style, size }
 * 输出：{ taskId, status }
 */

const https = require('https');
// 即梦AI配置（火山方舟）
const ARK_API_HOST = 'ark.cn-beijing.volces.com';

exports.handler = async (event, context, callback, logger) => {
  const respond = (result) => typeof callback === 'function' ? callback(result) : result;

  try {
    const { userId, prompt, style, size } = event;

    if (!userId || !prompt) {
      return respond({
        success: false,
        error: '参数错误：缺少userId或prompt'
      });
    }

    logger?.info(`[${userId}] 生成图片: ${prompt.substring(0, 50)}...`);

    // 调用即梦API
    const result = await callArkImageAPI({
      model: context?.env?.ARK_IMAGE_MODEL || process.env.ARK_IMAGE_MODEL || 'doubao-seedream-5-0-flash-260915',
      prompt: enhancePrompt(prompt, style),
      size: parseSize(size),
      response_format: 'url',
      watermark: false
    }, context?.env?.ARK_API_KEY || process.env.ARK_API_KEY);

    // 生成任务ID
    const taskId = `task_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    // 实际应用中，这里应该保存任务状态到数据库
    // 这里简化处理，直接返回图片URL

    return respond({
      success: true,
      taskId: taskId,
      status: 'success',
      imageUrl: result.data?.[0]?.url || ''
    });
  } catch (error) {
    logger?.error(`生成图片失败: ${error.message}`);
    return respond({
      success: false,
      error: error.message || '生成图片失败'
    });
  }
};

/**
 * 增强prompt
 */
function enhancePrompt(prompt, style) {
  const stylePresets = {
    comic: 'comic style, manga art, clean lines, vibrant colors',
    anime: 'anime style, detailed illustration, high quality',
    cute: 'cute kawaii style, chibi, adorable, pastel colors',
    realistic: 'realistic style, detailed, photorealistic'
  };

  const styleText = stylePresets[style] || stylePresets.anime;

  return `${prompt}, ${styleText}, masterpiece, best quality`;
}

/**
 * 解析尺寸
 */
function parseSize(size) {
  const supportedSizes = new Set([
    '1024x1024',
    '768x1024',
    '1024x768'
  ]);

  return supportedSizes.has(size) ? size : '1024x1024';
}

/**
 * 调用即梦API
 */
function callArkImageAPI(params, apiKey) {
  return new Promise((resolve, reject) => {
    const body = JSON.stringify(params);

    const options = {
      hostname: ARK_API_HOST,
      path: '/api/v3/images/generations',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'Content-Length': Buffer.byteLength(body)
      }
    };

    const req = https.request(options, (res) => {
      let data = '';

      res.on('data', (chunk) => {
        data += chunk;
      });

      res.on('end', () => {
        try {
          const result = JSON.parse(data);

          if (res.statusCode < 200 || res.statusCode >= 300 || result.error) {
            reject(new Error(result.error?.message || `方舟API请求失败（HTTP ${res.statusCode}）`));
            return;
          }

          resolve(result);
        } catch (err) {
          reject(new Error(`方舟API响应解析失败（HTTP ${res.statusCode}）`));
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.write(body);
    req.end();
  });
}
