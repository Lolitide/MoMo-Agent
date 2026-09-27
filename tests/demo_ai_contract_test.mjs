/*
 * ============================================================================
 * 文件名：tests/demo_ai_contract_test.mjs
 * ============================================================================
 * 【用途】AI 通路的静态契约测试，回答两个问题：
 *     1. 游客（无登录）能不能用真实 AI？—— 客户端与云函数的函数名、入参、
 *        返回结构是否严格对齐（对不上就一定调不通）；
 *     2. 演示模式会不会让现场演示卡在错误页？—— 页面是否统一经 DemoAIGateway
 *        分流，且真实分支失败后是否一定落到预制内容。
 *
 * 【前置条件 / 假设】
 *   - 假设：仓库根目录即本文件所在目录的上一级；
 *   - 假设：断言基于源码文本结构；重命名方法需同步更新本测试。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：entry/src/main/ets/service、entry/src/main/ets/pages、cloud-functions；
 *   - 输出：全部通过时打印一行成功信息；任一失败时抛 AssertionError 并以非 0 退出。
 * ============================================================================
 */
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const testDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(testDir, '..');

const read = async (relativePath) => readFile(path.join(root, relativePath), 'utf8');

const [gateway, cloudFunctionService, aiServiceCloud, chatFn, summaryFn, scriptFn,
  correctionFn, imageFn, imageStatusFn, todayPage, comicPage, mainPage, homePage] =
  await Promise.all([
    read('entry/src/main/ets/service/ai/DemoAIGateway.ets'),
    read('entry/src/main/ets/service/cloud/CloudFunctionService.ets'),
    read('entry/src/main/ets/service/ai/AIServiceCloud.ets'),
    read('cloud-functions/llm-chat.js'),
    read('cloud-functions/llm-daily-summary.js'),
    read('cloud-functions/llm-comic-script.js'),
    read('cloud-functions/llm-memory-correction.js'),
    read('cloud-functions/image-generate.js'),
    read('cloud-functions/image-get-status.js'),
    read('entry/src/main/ets/pages/B_TodayMemory.ets'),
    read('entry/src/main/ets/pages/B_DailyComic.ets'),
    read('entry/src/main/ets/pages/MainPage.ets'),
    read('entry/src/main/ets/pages/A_Home.ets')
  ]);

// ---------------------------------------------------------------------------
// 1. 客户端函数名 <-> 云函数文件：必须一一对应
//    任何一侧改名都会让「游客用 AI」静默失效，因此在此锁死。
// ---------------------------------------------------------------------------
const functionConstants = {
  FUNCTION_LLM_CHAT: ['llm-chat', chatFn],
  FUNCTION_LLM_SUMMARY: ['llm-daily-summary', summaryFn],
  FUNCTION_LLM_COMIC_SCRIPT: ['llm-comic-script', scriptFn],
  FUNCTION_LLM_CORRECTION: ['llm-memory-correction', correctionFn],
  FUNCTION_IMAGE_GENERATE: ['image-generate', imageFn],
  FUNCTION_IMAGE_STATUS: ['image-get-status', imageStatusFn]
};

for (const [constant, [fnName, source]] of Object.entries(functionConstants)) {
  assert.match(cloudFunctionService,
    new RegExp(`private static readonly ${constant} = '${fnName}';`),
    `CloudFunctionService 中的 ${constant} 与云函数名 ${fnName} 不一致`);
  assert.match(source, /exports\.handler\s*=/,
    `云函数 ${fnName}.js 未导出 handler，无法被 cloudFunction.call 调用`);
}

// ---------------------------------------------------------------------------
// 2. 云函数只把 userId 当作关联字段，不作鉴权 —— 这是「游客可用 AI」的依据。
//    若这一约定被改写为「必须校验身份」，本测试会失败，提醒同步调整
//    客户端的数据策略（因为游客没有可验证的云身份）。
// ---------------------------------------------------------------------------
assert.match(await read('cloud-functions/llm-common.js'), /untrusted correlation field/,
  'llm-common.js 中「userId 仅作关联字段、不作身份证明」的约定被改动');
assert.match(summaryFn, /requireUserId/,
  'llm-daily-summary 未走 requireUserId（userId 校验约定被改动）');

// ---------------------------------------------------------------------------
// 3. 页面层不得绕过网关直连 AIServiceCloud
// ---------------------------------------------------------------------------
for (const [name, source] of [
  ['B_TodayMemory.ets', todayPage],
  ['B_DailyComic.ets', comicPage],
  ['MainPage.ets', mainPage]
]) {
  assert.doesNotMatch(source, /AIServiceCloud/,
    `${name} 仍直接引用 AIServiceCloud，应统一经 DemoAIGateway 分流`);
  assert.match(source, /DemoAIGateway/,
    `${name} 未接入 DemoAIGateway`);
}

// AIServiceCloud 只允许出现在网关与仓库层
assert.match(gateway, /import \{ AIServiceCloud \} from '\.\/AIServiceCloud';/,
  '网关未引入 AIServiceCloud');
assert.doesNotMatch(homePage, /AIServiceCloud/,
  'A_Home.ets 不应直接引用 AIServiceCloud');

// ---------------------------------------------------------------------------
// 4. 网关必须在演示态短路，并在真实分支失败后降级到预制内容
// ---------------------------------------------------------------------------
assert.match(gateway, /export class DemoAIGateway/, 'DemoAIGateway 缺失');
assert.match(gateway, /import \{ DemoModeService \} from '\.\.\/DemoModeService';/,
  '网关未引入 DemoModeService');
assert.match(gateway, /import \{ DemoMockData \} from '\.\.\/\.\.\/mock\/DemoMockData';/,
  '网关未引入 DemoMockData');

// 四个能力入口都要有：演示态短路 + 真实态 try/catch
const gatewayMethods = [
  ['dailySummary', 'DemoMockData.demoDailySummaryText()'],
  ['comicScript', 'DemoAIGateway.demoPanels()'],
  ['comic', 'DemoMockData.buildComic()'],
  ['correction', 'DemoMockData.demoCorrectionResult()']
];
for (const [method, demoFallback] of gatewayMethods) {
  const start = gateway.indexOf(`static async ${method}(`);
  assert.ok(start >= 0, `网关缺少方法 ${method}()`);
  const nextStatic = gateway.indexOf('  static ', start + 10);
  const section = gateway.slice(start, nextStatic > start ? nextStatic : gateway.length);
  assert.match(section, /DemoModeService\.get\(\)\.isDemo\(\)/,
    `网关方法 ${method}() 未做演示态分流`);
  assert.ok(section.includes(demoFallback),
    `网关方法 ${method}() 演示态未返回预制内容 ${demoFallback}`);
  assert.match(section, /catch \(err\)/,
    `网关方法 ${method}() 缺少异常处理，无法在云端失败时降级`);
}

// 降级时必须提示用户，不能静默伪装成功
assert.match(gateway, /PromptUtil\.toast\(/, '网关降级时未向用户发出提示');

// ---------------------------------------------------------------------------
// 5. AI 服务本身不得以「登录状态」作为调用前置条件
//    （游客没有可验证云身份，任何 isLoggedIn 前置都会让游客失去 AI 能力）
// ---------------------------------------------------------------------------
const aiInitStart = aiServiceCloud.indexOf('async initialize(context?: Context)');
const ensureProfileStart = aiServiceCloud.indexOf('private async ensureUserProfile()');
assert.ok(aiInitStart >= 0 && ensureProfileStart > aiInitStart,
  'AIServiceCloud.initialize() 段落无法定位');
const aiInitializeSection = aiServiceCloud.slice(aiInitStart, ensureProfileStart);
assert.doesNotMatch(aiInitializeSection, /isLoggedIn/,
  'AIServiceCloud.initialize() 以登录状态为前置，会让游客失去 AI 能力');
assert.doesNotMatch(aiInitializeSection, /ensureUserProfile\(\)/,
  'AIServiceCloud.initialize() 依赖 CloudDB 用户档案，会阻断无云身份的游客');

console.log('AI 通路契约检查通过：函数名与云函数一一对应、游客无登录可调用、演示态短路与失败降级齐备。');
