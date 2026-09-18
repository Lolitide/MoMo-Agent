/**
 * ============================================================================
 * 云函数：生成每日总结
 * ============================================================================
 * 功能：调用DeepSeek API生成每日总结
 * 输入：{ userId, events, mood }
 * 输出：{ content, usage }
 */

const https = require('https');

// DeepSeek API配置
const DEEPSEEK_API_KEY = process.env.DEEPSEEK_API_KEY || 'your-api-key';
const DEEPSEEK_API_URL = 'api.deepseek.com';

/**
 * 云函数入口
 */
exports.handler = async (event, context) => {
  try {
    const { userId, events, mood } = event;

    // 验证输入
    if (!userId || !events || !Array.isArray(events)) {
      return {
        success: false,
        error: '参数错误：缺少userId或events'
      };
    }

    console.log(`[${userId}] 生成每日总结，事件数：${events.length}，心情：${mood}`);

    // 构造Prompt
    const prompt = buildSummaryPrompt(events, mood);

    // 调用DeepSeek API
    const response = await callDeepSeek([
      { role: 'system', content: '你是默默（Mo Mo），一个温暖、善解人意的AI桌宠。你的任务是根据用户的每日事件生成温馨的总结。' },
      { role: 'user', content: prompt }
    ]);

    return {
      success: true,
      content: response.content,
      usage: response.usage
    };
  } catch (error) {
    console.error('生成总结失败:', error);
    return {
      success: false,
      error: error.message || '生成总结失败'
    };
  }
};

/**
 * 构造总结Prompt
 */
function buildSummaryPrompt(events, mood) {
  const eventList = events.map((e, i) => `${i + 1}. ${e}`).join('\n');

  return `请根据用户今天的事件，生成一段温馨的每日总结。

【今日事件】
${eventList}

【心情】${mood}

【要求】
1. 总结应该温暖、贴心，像朋友般关心用户
2. 关注用户的情绪和状态
3. 提炼关键事件和亮点
4. 长度控制在150-200字
5. 口吻亲切自然，使用"你"称呼用户

请直接输出总结内容，不要有其他说明文字。`;
}

/**
 * 调用DeepSeek API
 */
function callDeepSeek(messages) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify({
      model: 'deepseek-chat',
      messages: messages,
      temperature: 0.7,
      max_tokens: 500
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
