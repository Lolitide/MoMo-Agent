/**
 * ============================================================================
 * 云函数：生成图片（即梦AI）
 * ============================================================================
 * 功能：调用火山引擎即梦API生成图片
 * 输入：{ userId, prompt, style, size }
 * 输出：{ taskId, status }
 */

const https = require('https');
const crypto = require('crypto');

// 即梦AI配置（火山引擎）
const JIMENG_ACCESS_KEY = process.env.JIMENG_ACCESS_KEY || 'your-access-key';
const JIMENG_SECRET_KEY = process.env.JIMENG_SECRET_KEY || 'your-secret-key';
const JIMENG_API_HOST = 'visual.volcengineapi.com';

exports.handler = async (event, context) => {
  try {
    const { userId, prompt, style, size } = event;

    if (!userId || !prompt) {
      return {
        success: false,
        error: '参数错误：缺少userId或prompt'
      };
    }

    console.log(`[${userId}] 生成图片: ${prompt.substring(0, 50)}...`);

    // 调用即梦API
    const result = await callJimengAPI({
      req_key: 'high_aes_general_v21_L',
      prompt: enhancePrompt(prompt, style),
      model_version: 'general_v2.1',
      return_url: true,
      scale: parseSize(size)
    });

    // 生成任务ID
    const taskId = `task_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;

    // 实际应用中，这里应该保存任务状态到数据库
    // 这里简化处理，直接返回图片URL

    return {
      success: true,
      taskId: taskId,
      status: 'success',
      imageUrl: result.data?.image_urls?.[0] || ''
    };
  } catch (error) {
    console.error('生成图片失败:', error);
    return {
      success: false,
      error: error.message || '生成图片失败'
    };
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
  const sizeMap = {
    '512x512': '1:1',
    '1024x1024': '1:1',
    '768x1024': '3:4',
    '1024x768': '4:3'
  };

  return sizeMap[size] || '1:1';
}

/**
 * 调用即梦API
 */
function callJimengAPI(params) {
  return new Promise((resolve, reject) => {
    const service = 'cv';
    const action = 'CVProcess';
    const version = '2022-08-31';
    const timestamp = Math.floor(Date.now() / 1000);

    // 构造请求体
    const body = JSON.stringify(params);

    // 生成签名
    const signature = generateSignature(service, action, version, timestamp, body);

    const options = {
      hostname: JIMENG_API_HOST,
      path: `/?Action=${action}&Version=${version}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Date': new Date(timestamp * 1000).toUTCString(),
        'Authorization': signature,
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

          if (result.ResponseMetadata?.Error) {
            reject(new Error(result.ResponseMetadata.Error.Message));
            return;
          }

          resolve(result);
        } catch (err) {
          reject(err);
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

/**
 * 生成火山引擎API签名（简化版）
 */
function generateSignature(service, action, version, timestamp, body) {
  // 实际签名算法较复杂，这里简化处理
  // 完整实现参考：https://www.volcengine.com/docs/6459/671286

  const hash = crypto.createHmac('sha256', JIMENG_SECRET_KEY)
    .update(`${action}${version}${timestamp}${body}`)
    .digest('hex');

  return `HMAC-SHA256 Credential=${JIMENG_ACCESS_KEY}, SignedHeaders=content-type;x-date, Signature=${hash}`;
}
