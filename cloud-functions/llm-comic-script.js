/**
 * ============================================================================
 * 云函数：生成漫画脚本
 * ============================================================================
 * 功能：调用DeepSeek API生成5格漫画脚本
 * 输入：{ userId, summary, events }
 * 输出：{ panels: [{ index, description, prompt, dialogue }], theme }
 */

const https = require('https');

const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || 'your-api-key';
const DEEPSEEK_API_URL = 'api.deepseek.com';

exports.handler = async (event, context) => {
  try {
    const { userId, summary, events } = event;

    if (!userId || !summary) {
      return {
        success: false,
        error: '参数错误：缺少userId或summary'
      };
    }

    console.log(`[${userId}] 生成漫画脚本`);

    // 构造Prompt
    const prompt = buildComicScriptPrompt(summary, events);

    // 调用DeepSeek API
    const response = await callDeepSeek([
      {
        role: 'system',
        content: '你是一位擅长将日常故事转化为温馨漫画的创作者。你需要将用户的每日总结改编成5格漫画分镜脚本。'
      },
      { role: 'user', content: prompt }
    ]);

    // 解析JSON响应
    const scriptData = JSON.parse(response.content);

    return {
      success: true,
      panels: scriptData.panels,
      theme: scriptData.theme
    };
  } catch (error) {
    console.error('生成脚本失败:', error);
    return {
      success: false,
      error: error.message || '生成脚本失败'
    };
  }
};

function buildComicScriptPrompt(summary, events) {
  const eventList = events ? events.map((e, i) => `${i + 1}. ${e}`).join('\n') : '';

  return `请将以下每日总结改编成5格漫画分镜脚本。

【每日总结】
${summary}

${eventList ? `【今日事件】\n${eventList}\n` : ''}

【要求】
1. 生成5个分镜（panel），每个分镜包含：
   - index: 序号（0-4）
   - description: 场景描述（中文，50字内）
   - prompt: 英文绘图提示词（用于AI生成图片）
   - dialogue: 对话或旁白（可选，20字内）

2. prompt要求：
   - 使用英文描述
   - 包含：角色、场景、动作、情绪、画风
   - 画风：anime style, warm colors, cute character
   - 示例："A cute AI pet sitting by the window in the morning, anime style, warm sunlight, peaceful atmosphere"

3. 故事要连贯、温馨、有情感共鸣

【输出格式（JSON）】
{
  "theme": "今日主题",
  "panels": [
    {
      "index": 0,
      "description": "清晨，默默在窗边迎接新的一天",
      "prompt": "A cute AI pet sitting by the window in the morning, anime style, warm colors",
      "dialogue": "早安！新的一天开始啦~"
    },
    ...
  ]
}

请直接输出JSON，不要有其他文字。`;
}

function callDeepSeek(messages) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      model: 'deepseek-chat',
      messages: messages,
      temperature: 0.8,
      max_tokens: 1500
    });

    const options = {
      hostname: DEEPSEEK_API_URL,
      path: '/v1/chat/completions',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${DEEPSEEK_API_KEY}`,
        'Content-Length': Buffer.byteLength(postData)
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

          if (result.error) {
            reject(new Error(result.error.message));
            return;
          }

          resolve({
            content: result.choices[0].message.content,
            usage: result.usage
          });
        } catch (err) {
          reject(err);
        }
      });
    });

    req.on('error', (err) => {
      reject(err);
    });

    req.write(postData);
    req.end();
  });
}
