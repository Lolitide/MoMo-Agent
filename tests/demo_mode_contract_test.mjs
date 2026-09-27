/*
 * ============================================================================
 * 文件名：tests/demo_mode_contract_test.mjs
 * ============================================================================
 * 【用途】演示模式的静态契约测试（与 t3_contract_test.mjs 同风格：只读源码做断言，
 *   不依赖 ArkTS 运行时，可在任意装有 Node 的机器上执行）。
 *   守护的核心契约是三条：
 *     1. 演示数据零持久化：DemoModeService 不得出现 preferences / 云函数调用；
 *     2. 演示数据零上云：MemoryRepository 的写操作在演示态下必须短路云端调用；
 *     3. 游客数据不被污染：DataSyncService 的落盘路径有双保险，且默认启动分支
 *        （不为未验证游客启用云同步）保持不变 —— 这一条与 t3 的断言互为冗余。
 *
 * 【前置条件 / 假设】
 *   - 假设：仓库根目录即本文件所在目录的上一级；
 *   - 假设：断言基于源码文本结构；重命名文件/方法需同步更新本测试。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：entry/src/main/ets 下的若干源文件；
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

const [demoModeSource, demoMockSource, repoSource, syncSource, settingsSource, servicesSource] =
  await Promise.all([
    read('entry/src/main/ets/service/DemoModeService.ets'),
    read('entry/src/main/ets/mock/DemoMockData.ets'),
    read('entry/src/main/ets/repository/Repositories.ets'),
    read('entry/src/main/ets/service/DataSyncService.ets'),
    read('entry/src/main/ets/pages/A_Settings.ets'),
    read('entry/src/main/ets/service/Services.ets')
  ]);

// ---------------------------------------------------------------------------
// 1. 演示模式开关存在且具备完整生命周期
// ---------------------------------------------------------------------------
assert.match(demoModeSource, /export class DemoModeService/, 'DemoModeService 缺失');
assert.match(demoModeSource, /async enable\(\): Promise<void>/, 'enable() 缺失或签名变化');
assert.match(demoModeSource, /async disable\(\): Promise<void>/, 'disable() 缺失或签名变化');
assert.match(demoModeSource, /isDemo\(\): boolean/, 'isDemo() 缺失或签名变化');
assert.match(demoModeSource, /subscribe\(cb: StateListener\)/, 'subscribe() 缺失或签名变化');

// ---------------------------------------------------------------------------
// 2. 演示态零持久化 / 零联网（硬约束）
//    注意：只允许出现在注释里，不允许出现在可执行代码里。
// ---------------------------------------------------------------------------
const stripLineComments = (text) =>
  text.split('\n').filter((line) => !line.trim().startsWith('*') && !line.trim().startsWith('//')).join('\n');

const demoModeCode = stripLineComments(demoModeSource);
assert.doesNotMatch(demoModeCode, /preferences/,
  'DemoModeService 不得接触 Preferences：演示模式是内存态');
assert.doesNotMatch(demoModeCode, /@ohos\.data\.preferences|@kit\.ArkData/,
  'DemoModeService 不得引入 Preferences 相关模块');
assert.doesNotMatch(demoModeCode, /cloudFunction|CloudDB|CloudStorage|cloudManager/,
  'DemoModeService 不得调用任何云能力：演示模式的开关必须能离线完成');

// ---------------------------------------------------------------------------
// 3. 演示数据工厂不落盘：只生产实例
// ---------------------------------------------------------------------------
const demoMockCode = stripLineComments(demoMockSource);
assert.doesNotMatch(demoMockCode, /preferences|cloudFunction|CloudDB/,
  'DemoMockData 只能生产数据实例，不得读写持久化或云能力');

// ---------------------------------------------------------------------------
// 4. MemoryRepository：演示态写入必须短路云端同步
// ---------------------------------------------------------------------------
const memoryStart = repoSource.indexOf('export class MemoryRepository');
const memoryEnd = repoSource.indexOf('export class EventRepository');
assert.ok(memoryStart >= 0 && memoryEnd > memoryStart, 'MemoryRepository 段落无法定位');
const memorySection = repoSource.slice(memoryStart, memoryEnd);

assert.match(memorySection, /private demoActive: boolean = false/, 'MemoryRepository 缺少 demoActive 标记');
assert.match(memorySection, /activateDemo\(\): void/, 'MemoryRepository.activateDemo() 缺失');
assert.match(memorySection, /deactivateDemo\(\): void/, 'MemoryRepository.deactivateDemo() 缺失');
assert.match(memorySection, /isDemo\(\): boolean/, 'MemoryRepository.isDemo() 缺失');

// add / update / delete 三处都必须在演示态下提前返回
assert.match(memorySection, /if \(this\.demoActive\) \{\s*this\.notify\(\);\s*return;\s*\}\s*this\.syncToCloud\(m\)/,
  'MemoryRepository.add() 在演示态下仍会 syncToCloud');
assert.match(memorySection, /if \(this\.demoActive\) \{\s*this\.notify\(\);\s*return;\s*\}\s*this\.syncToCloud\(m\)/,
  'MemoryRepository.update() 在演示态下仍会 syncToCloud');
assert.match(memorySection, /if \(this\.demoActive\) \{\s*this\.notify\(\);\s*return;\s*\}\s*this\.deleteFromCloud\(id\)/,
  'MemoryRepository.delete() 在演示态下仍会 deleteFromCloud');

// activateDemo 必须断开云身份（与上面的守卫构成双保险）
assert.match(memorySection, /this\.userId = '';/,
  'activateDemo() 未清空 userId，云端调用存在被重新打开的风险');
assert.match(memorySection, /this\.memories = DemoMockData\.buildMemories\(\)/,
  'activateDemo() 未载入演示记忆种子');
assert.match(memorySection, /this\.memories = this\.realMemories;/,
  'deactivateDemo() 未还原真实记忆数组');

// 恢复示例数据在演示态下必须是「演示种子」而不是普通 Mock 的 8 条
assert.match(memorySection, /this\.demoActive \? DemoMockData\.buildMemories\(\) : MockData\.buildMemories\(\)/,
  'restoreSamples() 在演示态下语义不一致');

// ---------------------------------------------------------------------------
// 5. 其余仓库都要有演示态支路
//    Event / Comic / User 为「自带状态 + 快照还原」；
//    MemoryTree / Companion 为「委托查询」——它们没有自己的数据副本，
//    因此只需读 MemoryRepository 的演示态（也必须是这条路径，不能各存一份）。
// ---------------------------------------------------------------------------
for (const [name, nextName] of [
  ['EventRepository', 'ComicRepository'],
  ['ComicRepository', 'UserRepository'],
  ['UserRepository', 'CompanionRepository']
]) {
  const start = repoSource.indexOf(`export class ${name} {`);
  const end = repoSource.indexOf(`export class ${nextName} {`);
  assert.ok(start >= 0 && end > start, `${name} 段落无法定位`);
  const section = repoSource.slice(start, end);
  assert.match(section, /isDemo\(\): boolean/, `${name} 缺少 isDemo()`);
  assert.match(section, /activateDemo\(\): void/, `${name} 缺少 activateDemo()`);
  assert.match(section, /deactivateDemo\(\): void/, `${name} 缺少 deactivateDemo()`);
}

for (const [name, nextName] of [
  ['MemoryTreeRepository', 'MemoryTypeUtilSafe'],
  ['CompanionRepository', 'MemoryTreeRepository']
]) {
  const start = repoSource.indexOf(`export class ${name} {`);
  const end = repoSource.indexOf(`export class ${nextName} {`);
  assert.ok(start >= 0 && end > start, `${name} 段落无法定位`);
  const section = repoSource.slice(start, end);
  assert.match(section, /MemoryRepository\.get\(\)\.isDemo\(\)/,
    `${name} 未按 MemoryRepository 的演示态分支（不得自建数据副本）`);
  assert.match(section, /DemoMockData\./, `${name} 演示态未返回演示数据`);
}

// 演示漫画必须同时可供三条展示路径读取
const comicStart = repoSource.indexOf('export class ComicRepository {');
const comicEnd = repoSource.indexOf('export class UserRepository {');
const comicSection = repoSource.slice(comicStart, comicEnd);
assert.match(comicSection, /this\.generatedComic = this\.demoComic;/,
  '演示态未把预制漫画登记为 generatedComic（首页卡片与今日漫画页会读到空）');
assert.match(comicSection, /this\.generatedScript = DemoMockData\.buildComicPanels\(\);/,
  '演示态未登记预制分镜脚本');
assert.match(comicSection, /generateDemoTodayComic\(\): Comic/, '缺少纯本地的演示漫画生成方法');

// ---------------------------------------------------------------------------
// 6. DataSyncService：落盘双保险 + 默认启动分支不变（与 t3 互为冗余）
// ---------------------------------------------------------------------------
assert.match(syncSource, /private persistenceSuspended: boolean = false;/, '缺少暂停落盘标记');
assert.match(syncSource, /suspendGuestPersistence\(\): void/, '缺少 suspendGuestPersistence()');
assert.match(syncSource, /resumeGuestPersistence\(\): void/, '缺少 resumeGuestPersistence()');

// scheduleGuestPersist() 的守卫：只截取该函数自身，避免把其后新增的方法算进来
const scheduleStart = syncSource.indexOf('private scheduleGuestPersist()');
const scheduleEnd = syncSource.indexOf('persistGuestLoop().catch');
assert.ok(scheduleStart >= 0 && scheduleEnd > scheduleStart, 'scheduleGuestPersist() 段落无法定位');
const scheduleSection = syncSource.slice(scheduleStart, scheduleEnd);
assert.match(scheduleSection, /this\.persistenceSuspended \|\| MemoryRepository\.get\(\)\.isDemo\(\)/,
  'scheduleGuestPersist() 缺少演示态双重守卫');

const persistStart = syncSource.indexOf('private async persistGuestLoop()');
const buildStart = syncSource.indexOf('private buildGuestSnapshot(');
assert.ok(persistStart >= 0 && buildStart > persistStart, 'persistGuestLoop() 段落无法定位');
const persistSection = syncSource.slice(persistStart, buildStart);
assert.match(persistSection, /if \(this\.persistenceSuspended \|\| MemoryRepository\.get\(\)\.isDemo\(\)\) \{\s*return;/,
  'persistGuestLoop() 循环中途未检查暂停标记，可能写入演示数据');

// 默认启动分支不得为未验证游客启用云同步（t3 的同一约束在此再锁一次）
const initializeStart = syncSource.indexOf('async initialize(context?: Context)');
const activateStart = syncSource.indexOf('async activateVerifiedCloudSync');
assert.ok(initializeStart >= 0 && activateStart > initializeStart, 'DataSyncService.initialize() 段落无法定位');
const defaultInitialize = syncSource.slice(initializeStart, activateStart);
assert.doesNotMatch(defaultInitialize, /cloudManager\.initialize/,
  '默认启动不得为未验证的游客身份初始化云同步');

// ---------------------------------------------------------------------------
// 7. 设置页：演示模式入口 + 重置项仅在演示态出现 + 开关与二次确认
// ---------------------------------------------------------------------------
assert.match(settingsSource, /import \{ DemoModeService \} from '\.\.\/service\/DemoModeService';/,
  '设置页未引入 DemoModeService');
assert.match(settingsSource, /demoSection\(\)/, '设置页缺少演示模式区块');
assert.match(settingsSource, /DemoModeService\.get\(\)\.enable\(\)/, '设置页未接入开启演示模式');
assert.match(settingsSource, /DemoModeService\.get\(\)\.disable\(\)/, '设置页未接入退出演示模式');
assert.match(settingsSource, /requestEnableDemo\(\): void/, '开启演示模式缺少二次确认');
// 「演示条数」与「重置演示数据」都必须被限制在 if (this.isDemo) 区块内
const demoGuardStart = settingsSource.indexOf('if (this.isDemo) {');
const demoGuardEnd = settingsSource.indexOf('\n        }', demoGuardStart);
assert.ok(demoGuardStart >= 0 && demoGuardEnd > demoGuardStart,
  '设置页的 if (this.isDemo) 区块无法定位');
const demoGuardBlock = settingsSource.slice(demoGuardStart, demoGuardEnd);
assert.ok(demoGuardBlock.includes('重置演示数据'),
  '「重置演示数据」未被限制在演示态内显示');
assert.ok(demoGuardBlock.includes('this.demoCountRow()'),
  '「演示记忆条数」未被限制在演示态内显示');
assert.match(settingsSource, /DemoModeService\.get\(\)\.subscribe\(this\.demoListener\)/,
  '设置页未订阅演示模式变化');
assert.match(settingsSource, /DemoModeService\.get\(\)\.unsubscribe\(this\.demoListener\)/,
  '设置页离开时未取消订阅（存在内存泄漏）');

// ---------------------------------------------------------------------------
// 8. DemoUIState：演示态文案集中在服务层，不散落在页面
// ---------------------------------------------------------------------------
assert.match(servicesSource, /export class DemoUIState/, 'DemoUIState 缺失');
assert.match(servicesSource, /static prefix\(\): string/, 'DemoUIState.prefix() 缺失');
assert.match(servicesSource, /static menuPrefix\(\): string/, 'DemoUIState.menuPrefix() 缺失');

// ---------------------------------------------------------------------------
// 9. 演示种子与花园的隐式契约（改数据时容易被忽略）
//    - m4 必须存在：A_Garden 在无 pendingFocus 时默认高亮它；
//    - m4 必须是「重要回忆」的**新**表达方式：类型为四类之一（GOAL）+ importance 5 + 标签，
//      而不是旧的 IMPORTANT 类型（该类型已降级为标签，见 Models.ets）；
//    - 演示记忆条数不少于 8，保证 4 个类型簇都有内容、能看出生长层次。
// ---------------------------------------------------------------------------
const memSeeds = [...demoMockSource.matchAll(/DemoMockData\.mk\('(m\d+)',[^)]*?(\d+),\s*MemoryType\.(\w+),\s*(\d+)\)/g)];
assert.equal(memSeeds.length, 14, `演示记忆种子应为 14 条，实际 ${memSeeds.length} 条`);
assert.ok(memSeeds.length >= 8, '演示记忆少于 8 条时，4 个类型簇会显得稀疏');
const m4 = memSeeds.find((item) => item[1] === 'm4');
assert.ok(m4, '演示种子缺少 m4：A_Garden 默认高亮该节点');
assert.notEqual(m4[3], 'IMPORTANT',
  'm4 不应再使用 IMPORTANT 类型：「重要回忆」已降级为标签，类型必须落在四类之一');
assert.ok(['LIFE', 'STUDY', 'GOAL', 'INTEREST'].includes(m4[3]),
  `m4 的类型必须是四类之一，实际 ${m4[3]}`);
assert.equal(m4[4], '5', 'm4 作为重要回忆，importance 应为 5');
assert.match(demoMockSource, /m4\.tags = \['重要回忆'/,
  'm4 未带上「重要回忆」标签：重要回忆的语义必须由标签承载');
assert.match(demoMockSource, /m8\.tags = \['重要回忆'/,
  'm8 未带上「重要回忆」标签');
assert.match(demoMockSource, /m14\.tags = \['重要回忆'/,
  'm14 未带上「重要回忆」标签');

// 只画 4 类：演示数据里不得再出现第 5 种类型
assert.doesNotMatch(demoMockSource, /MemoryType\.IMPORTANT/,
  'DemoMockData 仍使用 IMPORTANT 类型：花园只会画 4 类，这类记忆会因为无簇可归而消失');

// ---------------------------------------------------------------------------
// 10. 演示记忆条数设置（设置页滑杆 → DemoModeService → DemoMockData）
//     这一项存在的意义：现场需要把花园「调满」来看记忆很多时的形态。
//     约束仍然是「演示数据不长期保存」——条数本身也只在内存里，冷启动回默认值。
// ---------------------------------------------------------------------------
assert.match(demoMockSource, /private static targetCount: number = 14;/,
  '演示条数默认值应等于手工种子条数（14）：不改动既有演示观感');
assert.match(demoMockSource, /static readonly MIN_COUNT: number = 4;/,
  '缺少条数下限（少于 4 条凑不齐 4 个类型簇）');
assert.match(demoMockSource, /static readonly MAX_COUNT: number = 60;/,
  '缺少条数上限（上限用于压测花园布局）');
assert.match(demoMockSource, /static readonly BASE_COUNT: number = 14;/,
  '缺少手工种子条数常量');
assert.match(demoMockSource, /static setTargetCount\(n: number\): number \{/,
  '缺少 setTargetCount()：设置页没有可调入口');
assert.match(demoMockSource, /Math\.min\(DemoMockData\.MAX_COUNT, Math\.max\(DemoMockData\.MIN_COUNT, Math\.round\(n\)\)\)/,
  'setTargetCount() 未把入参夹到 [MIN_COUNT, MAX_COUNT]');
assert.match(demoMockSource, /static getTargetCount\(\): number \{/, '缺少 getTargetCount()');
assert.match(demoMockSource, /private static extend\(mem: Memory\[\], target: number\): void \{/,
  '缺少 extend()：条数调大时无法补齐演示记忆');
assert.match(demoMockSource, /private static trim\(mem: Memory\[\], target: number\): Memory\[\] \{/,
  '缺少 trim()：条数调小时无法截取演示记忆');

// 条数调到最小时也不能把花园削成残的：必须保住 m4 锚点与四种类型覆盖
const trimBlock = demoMockSource.match(/private static trim\(mem: Memory\[\], target: number\): Memory\[\] \{([\s\S]*?)\n  \}/)[1];
assert.match(trimBlock, /sorted\[i\]\.id === 'm4'/,
  'trim() 未保住 m4：A_Garden 默认高亮节点会消失');
assert.match(trimBlock, /DemoMockData\.hasType\(kept, types\[t\]\)/,
  'trim() 未保证四种类型各留一条：花园会少掉一整朵花');

// 补齐的补充记忆必须是确定性的（不用随机数），否则每次进演示模式花园都不一样
const extendBlock = demoMockSource.match(/private static extend\(mem: Memory\[\], target: number\): void \{([\s\S]*?)\n  \}/)[1];
assert.ok(!/Math\.random/.test(extendBlock),
  'extend() 用了随机数：演示花园每次都不一样，无法对比不同条数下的布局');

// 服务层：条数设置必须走 DemoModeService，页面不得直接依赖 mock 层
assert.match(demoModeSource, /setDemoMemoryCount\(n: number\): number \{/,
  'DemoModeService 缺少 setDemoMemoryCount()');
assert.match(demoModeSource, /MemoryRepository\.get\(\)\.refreshDemoData\(\);/,
  'setDemoMemoryCount() 未重建演示记忆：花园不会立即按新条数重排');
assert.match(demoModeSource, /demoMemoryTarget\(\): number \{/,
  'DemoModeService 缺少 demoMemoryTarget()');
assert.match(demoModeSource, /static minDemoMemoryCount\(\): number \{/,
  'DemoModeService 缺少条数下限透传');
assert.match(demoModeSource, /static maxDemoMemoryCount\(\): number \{/,
  'DemoModeService 缺少条数上限透传');

// 仓库层：refreshDemoData() 在非演示态必须是空操作 —— 绝不能碰真实数据
assert.match(memorySection, /refreshDemoData\(\): boolean \{\s*if \(!this\.demoActive\) \{\s*return false;\s*\}/,
  'refreshDemoData() 在非演示态会继续执行：调条数有污染真实记忆的风险');
assert.match(memorySection, /this\.memories = DemoMockData\.buildMemories\(\);\s*this\.notify\(\);\s*return true;/,
  'refreshDemoData() 未重建演示记忆并广播');

// 设置页：滑杆只在演示态出现，且松手才生效（拖动过程不能重建整座花园）
assert.match(settingsSource, /this\.demoCountRow\(\)/,
  '设置页未渲染演示条数行');
assert.match(settingsSource, /Slider\(\{[\s\S]{0,200}min: DemoModeService\.minDemoMemoryCount\(\)/,
  '设置页缺少条数滑杆');
assert.match(settingsSource, /mode === SliderChangeMode\.End \|\| mode === SliderChangeMode\.Click/,
  '滑杆未区分拖动与松手：每移动一格都会重建花园');
assert.match(settingsSource, /DemoModeService\.get\(\)\.setDemoMemoryCount\(this\.demoMemoryTarget\)/,
  '设置页未把条数写回 DemoModeService');
assert.match(settingsSource, /aboutToAppear\(\)[\s\S]{0,600}this\.demoMemoryTarget = DemoModeService\.get\(\)\.demoMemoryTarget\(\);/,
  '设置页未在进入时同步当前条数');

console.log('演示模式契约检查通过：内存隔离、零持久化、零上云、游客数据边界、设置页入口与演示条数设置均符合约定。');
