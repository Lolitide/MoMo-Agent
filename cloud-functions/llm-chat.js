'use strict';

const common = require('./llm-common');

function createHandler(dependencies = {}) {
  const callDeepSeek = dependencies.callDeepSeek || common.callDeepSeek;
  return async (event, context, callback, logger) => {
    try {
      const input = common.parseEvent(event);
      common.requireUserId(input.userId);
      const message = common.requireString(input.message, 'message', { min: 1, max: 4000 });
      const history = common.chatContext(input.context);
      const config = common.getDeepSeekConfig(context);
      const completion = await callDeepSeek([
        {
          role: 'system',
          content: '你是默默（Mo Mo），一位温暖、简洁、尊重边界的 AI 桌宠。不要声称已读取未在本次对话中提供的私人数据。'
        },
        ...history,
        { role: 'user', content: message }
      ], config, { maxTokens: 800, temperature: 0.7 });

      return common.respond(callback, {
        success: true,
        content: completion.content,
        ...(completion.usage ? { usage: completion.usage } : {})
      });
    } catch (error) {
      return common.respond(callback, common.errorResponse(error, logger, 'llm-chat'));
    }
  };
}

exports.handler = createHandler();
exports._test = { createHandler };
