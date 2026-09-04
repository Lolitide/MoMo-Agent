/*
 * ============================================================================
 * 文件名：components/momo/MoMoStateTable.ets
 * ============================================================================
 * 【用途】弹簧驱动软体角色引擎的行为数据表：39 个状态（每状态的眼睛
 *   播放列表/停留/眨眼节律/视线/overlay 徽标），弹簧常数表（移植自
 *   Web 项目 grok-icon-study-web 的 replica/src/tables.js，MIT 许可）。
 * 【前置条件 / 假设】
 *   - 纯数据表：不依赖业务层（MoMoState 映射放在组件壳内）；
 *   - 39 状态为引擎内部命名，与 MoMoState(6 枚举) 通过映射表关联；
 *   - gaze 编码为 [min,max,needSign]，引擎乘 15/9（与 Web 一致）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：无；输出：findState/SPRING_SPECS/ONBOARDING 序列。
 * 【关键类 / 算法】
 *   - 数据表逐一搬自 Web EYE_PLAYLIST/EYE_HOLD_MS/BLINK_MS/HOLD_GAZE/nextGaze；
 *   - SPRING_SPECS[i] = [freq, damp]，与 Web SPRINGS 一致。
 * 【参考源】
 *   - grok-icon-study-web/replica/src/tables.js（MIT，数值照搬）
 * ============================================================================
 */

export class SpringSpec {
  name: string;
  freq: number;
  damp: number;

  constructor(name: string, freq: number, damp: number) {
    this.name = name;
    this.freq = freq;
    this.damp = damp;
  }
}

// Web SPRINGS 常数表（MIT）——引擎逐弹簧使用
export const SPRING_SPECS: SpringSpec[] = [
  new SpringSpec('spin', 5, 0.9),
  new SpringSpec('x', 3.5, 1),
  new SpringSpec('y', 4, 1),
  new SpringSpec('squash', 10, 0.8),
  new SpringSpec('blink', 26, 1),
  new SpringSpec('eyeScale', 9, 0.85),
  new SpringSpec('gazeX', 13, 1),
  new SpringSpec('gazeY', 13, 1),
  new SpringSpec('notify', 9, 0.55),
  new SpringSpec('humDots', 6, 1),
  new SpringSpec('overlay', 14, 1),
  new SpringSpec('overlayMix', 11, 1),
  new SpringSpec('shape', 10, 1),
  new SpringSpec('overlayTurn', 14, 1),
  new SpringSpec('spinTurn', 6.2, 1),
  new SpringSpec('manualMix', 7, 1)
];

// 每个状态的行为描述
export class MoMoStateRec {
  name: string = '';
  playlist: number[] = [];
  holdMs: number[] = [2000, 3600];
  blinkMs: number[] | null = null;
  gxMin: number = -0.4;
  gxMax: number = 0.4;
  gxRand: boolean = true;
  gyMin: number = -0.3;
  gyMax: number = 0.3;
  gyRand: boolean = true;
  gHold: number[] = [2500, 5000];
  overlay: string = '';
  cycle: boolean = false;
  wink: boolean = false;
  vt: boolean = false;
  bt: boolean = false;
  holdGazeX: number = 0;
  holdGazeY: number = 0;
  holdEye: number = -1;
  group: string = 'Lifecycle';
}

function rec(name: string, playlist: number[], hold: number[], blink: number[] | null,
  overlay: string, cycle: boolean, wink: boolean, vt: boolean, bt: boolean,
  hgx: number, hgy: number, holdEye: number, group: string): MoMoStateRec {
  const r = new MoMoStateRec();
  r.name = name;
  r.playlist = playlist;
  r.holdMs = hold;
  r.blinkMs = blink;
  r.overlay = overlay;
  r.cycle = cycle;
  r.wink = wink;
  r.vt = vt;
  r.bt = bt;
  r.holdGazeX = hgx;
  r.holdGazeY = hgy;
  r.holdEye = holdEye;
  r.group = group;
  return r;
}

function gaze(spec: string): number[] {
  const parts = spec.split(',');
  return [Number(parts[0]), Number(parts[1]), Number(parts[2])];
}

// 39 状态表（移植自 Web tables.js；overlay 为 fx MAP 的 kind 名）
const RAW: MoMoStateRec[] = [
  // ---- Lifecycle ----
  rec('sleeping', [13, 22, 4], [6000, 10000], null, '', false, false, false, false, 0, 0, -1, 'Lifecycle'),
  rec('waking', [13], [800, 800], null, '', false, false, false, false, 0, 0, -1, 'Lifecycle'),
  rec('idle', [0, 8], [9000, 16000], [6000, 14000], '', false, true, false, false, 0, 0, -1, 'Lifecycle'),
  rec('listening', [10, 1, 19], [2800, 5000], [3000, 7000], '', false, false, false, false, 5, -2, -1, 'Lifecycle'),
  rec('thinking', [8, 16, 14, 17, 5], [2000, 3600], [3500, 7000], 'dots', false, false, false, false, 12, -7, -1, 'Lifecycle'),
  rec('searching', [15, 9, 3, 20, 12, 18], [1000, 1800], [1600, 4000], '', false, false, false, false, 14, -4, -1, 'Lifecycle'),
  rec('working', [7, 16, 11, 10], [1800, 3200], [2800, 5500], '', false, false, false, false, 3, 7, -1, 'Lifecycle'),
  // ---- Reactions ----
  rec('excited', [2, 17, 21, 3, 11], [1100, 2000], [2000, 4000], '', false, true, true, false, 0, 0, -1, 'Reactions'),
  rec('surprised', [3, 21], [2500, 4000], [1800, 3500], '', false, false, false, false, 0, 0, -1, 'Reactions'),
  rec('suspicious', [14, 5, 23], [2600, 4500], [4500, 8000], '', false, false, false, false, -15, 3, -1, 'Reactions'),
  rec('angry', [7, 16], [2200, 3800], [3500, 7000], '', false, false, false, false, 0, 2, -1, 'Reactions'),
  rec('drowsy', [4, 22, 13], [4000, 8000], null, '', false, false, false, false, 4, 7, -1, 'Reactions'),
  rec('happy', [2, 11, 17, 19], [2500, 4500], [2500, 5000], '', false, true, true, false, -6, -4, -1, 'Reactions'),
  rec('curious', [3, 21, 0, 15], [1800, 3200], [2500, 5500], '', false, true, true, false, 12, -6, -1, 'Reactions'),
  rec('confused', [14, 5, 8], [2200, 3800], [2800, 5500], '', false, false, false, false, 12, 3, -1, 'Reactions'),
  rec('bored', [4, 22, 0], [3500, 6000], [4000, 8000], '', false, false, false, false, 12, 6, -1, 'Reactions'),
  rec('proud', [15, 8, 2], [3500, 6000], [3500, 7000], '', false, false, false, false, 0, -6, -1, 'Reactions'),
  rec('shy', [0, 24, 13], [3000, 5500], [3000, 6000], '', false, false, false, false, 10, 7, 24, 'Reactions'),
  rec('sad', [4, 13, 22], [4000, 7000], [4000, 8000], '', false, false, false, false, 2, 8, -1, 'Reactions'),
  rec('laughing', [2, 11, 17], [1200, 2400], [2500, 5000], '', false, false, false, false, 4, -4, -1, 'Reactions'),
  rec('scared', [3, 21], [900, 1800], [1200, 3000], '', false, false, false, false, 12, 2, -1, 'Reactions'),
  rec('playful', [2, 17, 11, 8], [1500, 3000], [2000, 4500], '', false, true, false, true, 10, -4, -1, 'Reactions'),
  rec('celebrate', [2, 8, 17], [1400, 2600], [2200, 4500], '', false, false, false, false, 0, 0, -1, 'Reactions'),
  // ---- Agent morphs ----
  rec('orbit', [0, 8], [4000, 8000], null, 'orbit', false, false, false, false, 0, 0, -1, 'Agent morphs'),
  rec('radar', [0, 8], [4000, 8000], null, 'radar', false, false, false, false, 0, 0, -1, 'Agent morphs'),
  rec('progress', [0, 8], [4000, 8000], null, 'progress', true, false, false, false, 0, 0, -1, 'Agent morphs'),
  // ---- Product lifecycle ----
  rec('spawning', [3, 0], [1200, 1200], null, 'gather', true, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('humming', [0, 8], [5000, 9000], [4000, 8000], 'whirl', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('loading', [0, 8], [6000, 10000], null, 'whirl', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('dictating', [10, 1, 19], [4000, 8000], null, 'wave', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('writing', [15, 9], [4000, 8000], null, 'pencil', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('sending', [0, 8], [4000, 8000], null, 'send', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('receiving', [19, 0, 8], [4000, 8000], null, 'receive', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('uploading', [15, 9, 8], [4000, 8000], null, 'dock', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('notifying', [3, 21, 0], [1500, 2600], [2000, 4000], '', false, false, false, false, 7, -3, -1, 'Product lifecycle'),
  rec('alerting', [3, 21], [2000, 3600], null, 'bang', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('dragging', [3, 15, 0], [1600, 3000], [2200, 4500], '', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('bouncing', [2, 17], [3000, 6000], null, 'ball', false, false, false, false, 0, 0, -1, 'Product lifecycle'),
  rec('powering-down', [13, 22], [6000, 9000], null, 'standby', false, false, false, false, 0, 0, -1, 'Product lifecycle')
];

// 视线特征（移植 Web nextGaze；gx*15 / gy*9，range 第 3 位=需要随机方向）
const GAZE_TABLE: string[][] = [
  ['idle', '0,0,0', '0,0,0', '2500,5500'],
  ['listening', '-0.3,0.3,0', '-0.25,0.25,0', '2200,4200'],
  ['thinking', '0.5,1,1', '-1,-0.4,0', '1500,2800'],
  ['searching', '0.7,1,1', '-1,1,0', '550,1150'],
  ['working', '-0.4,0.4,0', '0.4,1,0', '1200,2400'],
  ['excited', '-1,1,0', '-1,0.3,0', '700,1400'],
  ['surprised', '0,0,0', '0,0,0', '1600,2600'],
  ['suspicious', '1,1,1', '0.3,0.3,0', '2200,4200'],
  ['angry', '-0.2,0.2,0', '0.2,0.2,0', '1800,3200'],
  ['drowsy', '-0.4,0.4,0', '0.4,1,0', '2500,4500'],
  ['happy', '-0.7,0.7,0', '-0.6,0,0', '1800,3400'],
  ['curious', '0.6,1,1', '-1,1,0', '950,1900'],
  ['confused', '0.5,1,1', '-0.6,1,0', '1100,2300'],
  ['bored', '0.7,1,1', '0.4,0.9,0', '3000,6000'],
  ['proud', '-0.3,0.3,0', '-0.7,-0.3,0', '2600,4600'],
  ['shy', '0.6,1,1', '0.5,1,0', '2000,4000'],
  ['sad', '-0.3,0.3,0', '0.6,1,0', '2800,5000'],
  ['laughing', '-0.5,0.5,0', '-0.6,-0.2,0', '800,1700'],
  ['scared', '0.7,1,1', '-0.6,0.6,0', '450,1050'],
  ['playful', '0.5,1,1', '-0.6,0,0', '900,1800'],
  ['notifying', '0.1,0.45,0', '-0.3,-0.05,0', '1200,2400']
];

const INDEX: Map<string, MoMoStateRec> = new Map<string, MoMoStateRec>();
for (const s of RAW) {
  INDEX.set(s.name, s);
}

for (const g of GAZE_TABLE) {
  const r = findState(g[0]);
  if (r) {
    const gx = gaze(g[1]);
    const gy = gaze(g[2]);
    const gh = gaze(g[3]);
    r.gxMin = gx[0];
    r.gxMax = gx[1];
    r.gxRand = gx[2] === 1;
    r.gyMin = gy[0];
    r.gyMax = gy[1];
    r.gyRand = gy[2] === 1;
    r.gHold = [gh[0], gh[1]];
  }
}

export function findState(name: string): MoMoStateRec | null {
  const r = INDEX.get(name);
  return r ? r : null;
}

export function stateNames(): string[] {
  const out: string[] = [];
  for (const k of INDEX.keys()) {
    out.push(k);
  }
  return out;
}

// onboarding 序列（引擎 mode='onboarding' 使用）
export const ONBOARDING_SEQ: string[] = ['curious', 'happy', 'playful', 'excited', 'listening', 'proud', 'laughing', 'shy'];
export const ONBOARDING_MS: number = 1200;
