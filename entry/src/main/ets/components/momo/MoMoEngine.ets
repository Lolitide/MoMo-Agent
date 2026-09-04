/*
 * ============================================================================
 * 文件名：components/momo/MoMoEngine.ets
 * ============================================================================
 * 【用途】弹簧驱动软体角色引擎核心（对应 Web grok-icon-study-web 的
 *   GrokCharacter，MIT 许可移植）：39 状态状态机、弹簧场（半隐式欧拉）、
 *   眼睛播放列表 morph / 眨眼 / 视线 / wink、自动 tricks（spin/hop/dizzy）、
 *   overlay 切换，输出为 ArkUI Canvas 原生命令绘制。
 * 【前置条件 / 假设】
 *   - 纯引擎类：不持有 UI 组件；ctx 由调用方（MoMoAvatar）在 paint 时传入；
 *   - 世界系 0..200（中心 100,100）；外部以 sizePx 缩放绘制；
 *   - 移植差异：3D 姿态/粒子轨带/取景 zoom 不做，保留 2D 弹簧手感与
 *     全部状态行为；overlay 图形为简化复刻（见 MoMoOverlays）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：tick(nowMs, dtSec) 与 setState/setShape/spinOnce/bounceOnce/
 *     pointerTo/clearPointer；输出：paint(ctx, sizePx) 按帧绘制。
 * 【关键类 / 算法】
 *   - applyPose：39 状态的运动目标（移植 Web pose.js switch）；
 *   - evalTrick：spinDizzy/spinWild/spinBounce（移植 Web tricks.js）；
 *   - stepOverlay：overlay 开关与 CYCLE 振荡（移植 Web character.js）。
 * 【参考源】
 *   - grok-icon-study-web/replica/src/{math,tables,pose,tricks,eyes,fx,character}.js
 *     （MIT 许可；本文件只含引擎逻辑，几何为 MoMo 项目原创）
 * ============================================================================
 */
import {
  Spring, clamp, lerp, rand, sign, K2, Rn,
  lerpPoly, polyCentroid, closedSplineSegs
} from './MoMoMotionMath';
import { MOMO_EYES, MOMO_INK, shapeByName, MoMoShape } from './MoMoGeoData';
import { findState, ONBOARDING_SEQ, ONBOARDING_MS } from './MoMoStateTable';
import { MoMoOverlays } from './MoMoOverlays';

const VIEW: number = 200;
const R: number = 100;

// ticking 上下文（Web _freshCtx 的字段集合）
class StateCtx {
  nodUntil: number = 0;
  nodEnd: number = 0;
  angryShakeUntil: number = 0;
  impulseAt: number = 0;
  tyKick: number = 0;
  spinKick: number = 0;
  forceSleepEye: boolean = false;
  wakeEye: number[] | null = null;
  wakeBlink: boolean = false;
  wakingBlinked: boolean = false;
  slumpAt: number = 0;
  stAt: number = 0;
  wantPn: number[] | null = null;
  wantBlink: boolean = false;
  dragCycle: number = -1;
  notifyPop: boolean = false;
}

class PoseOut {
  spin: number = 0;
  tx: number = 0;
  ty: number = 0;
  squash: number = 1;
  lid: number = 1;
  eyeBoost: number = 1;
}

class Trick {
  kind: string = '';
  t0: number = 0;
  dir: number = 1;
  turns: number = 1;
}

class TrickFx {
  turn: number | null = null;
  Kr: number = 0;
  yi: number = 0;
  ki: number = 0;
  Yr: number = 0;
  Zr: number = 0;
  wi: number = 0;
  lidMul: number | null = null;
  eyeBoost: number | null = null;
  done: boolean = false;
  wantHop: boolean = false;
}

export class MoMoEngineOptions {
  shape: string = 'blob';
  mode: string = 'hold';        // 'hold' | 'onboarding'
  autoTricks: boolean = true;
  reduceMotion: boolean = false;
  emphasis: boolean = false;
}

const TRICK_EMPTY: TrickFx = new TrickFx();

export class MoMoEngine {
  private state: string = 'idle';
  private mode: string = 'hold';
  private shapeName: string = 'blob';
  private autoTricks: boolean = true;
  private reduceMotion: boolean = false;
  private emphasis: boolean = false;
  private paused: boolean = false;
  private moodN: number = 0;

  private t0: number = 0;
  private stateAt: number = 0;
  private last: number = 0;

  // ---- springs ----
  private spinS: Spring = new Spring(0);
  private txS: Spring = new Spring(0);
  private tyS: Spring = new Spring(0);
  private squashS: Spring = new Spring(1);
  private blinkS: Spring = new Spring(1);
  private eyeScaleS: Spring = new Spring(1);
  private gazeXS: Spring = new Spring(0);
  private gazeYS: Spring = new Spring(0);
  private eyeMorphS: Spring = new Spring(1);
  private overlayS: Spring = new Spring(0);
  private overlayMixS: Spring = new Spring(1);
  private notifyS: Spring = new Spring(0);
  private humDotsS: Spring = new Spring(0);
  private shapeSpringS: Spring = new Spring(1);
  private overlayTurnS: Spring = new Spring(0);
  private spinTurnS: Spring | null = null;

  // ---- 眼睛状态 ----
  private eyeFrom: number = 0;
  private eyeTo: number = 0;
  private eyeStiffness: number = 8;
  private eyeIdx: number = 0;
  private eyeHoldMs: number = 3000;
  private eyeRemain: number = 0;
  private eyeUntil: number = 0;
  private blinkUntil: number = 0;
  private fromPolys: number[][][] | null = null; // [left, right]
  private blinkQueue: number[][] = [];           // [at, v]
  private winkAt: number = -1e9;
  private winkEye: number = 0;
  private winkUntil: number = 0;
  private gazeUntil: number = 0;

  // ---- tricks ----
  private trick: Trick | null = null;
  private hopAt: number = -1;
  private trickAt: number = 0;
  private trickCycle: number = 0;
  private wildWide: boolean = false;
  private celebrateAt: number = -1;

  // ---- overlay ----
  private ovKind: string = '';
  private ovPrev: string = '';
  private ovTarget: string | null = null;
  private ovOn: boolean = false;
  private ovRest: boolean = false;
  private ovRestAt: number = 0;
  private ovStartAt: number = 0;
  private ovSpin: number = 0;
  private ovTurnAcc: number = 0;
  private ovTurnDir: number = 1;

  private ctxSt: StateCtx = new StateCtx();
  private poseOut: PoseOut = new PoseOut();
  private fx: MoMoOverlays = new MoMoOverlays();
  private pointerX: number = 0;
  private pointerY: number = 0;
  private pointerTx: number = 0;
  private pointerTy: number = 0;

  // ---- shape morph ----
  private prevRing: number[][] | null = null;

  // ---- 首页滚动弹簧：视觉尺寸向 avatarSize 弹簧逼近（有惯性回弹） ----
  private viewS: Spring = new Spring(300);
  private viewTarget: number = 300;
  // ---- idle 低频随机动作（spin/hop/spinBounce/spinDizzy） ----
  private idleMoves: boolean = true;
  private idleTrickAt: number = 0;

  private bodyGrad: CanvasGradient | null = null;

  constructor(opts: MoMoEngineOptions) {
    this.shapeName = opts.shape || 'blob';
    this.mode = opts.mode || 'hold';
    this.autoTricks = opts.autoTricks !== false;
    this.reduceMotion = !!opts.reduceMotion;
    this.emphasis = !!opts.emphasis;
    // 时钟约定：唯一时间源 = tick(nowMs) 的 DisplaySync 帧时钟。
    // 首帧由 boot() 初始化（不可以用 Date.now：与帧时钟不一致会让
    // 播放列表/眨眼/视线等所有绝对时间点失效）。
    this.viewS.snap(320);
    this.viewTarget = 320;
  }

  // 首帧时钟启动：以帧时钟为基准初始化全部绝对时间点
  private boot(now: number): void {
    this.t0 = now;
    this.stateAt = now;
    this.last = now;
    this.eyeUntil = now + rand(4000, 8000);
    this.winkUntil = now + rand(3000, 8000);
    this.gazeUntil = now + 800;
    this.trickAt = now + rand(2500, 5000);
    this.trickCycle = Math.floor(rand(0, 5));
    this.idleTrickAt = now + rand(6000, 12000);
    this.setState(this.pendingState, this.pendingReset);
  }

  private booted: boolean = false;

  // ---------------- 公共接口 ----------------

  private pendingState: string = 'idle';
  private pendingReset: boolean = true;

  setState(name: string, resetEyes: boolean): void {
    // 未 boot（首帧前）时挂起：boot 后以最新期望状态启动
    if (!this.booted) {
      this.pendingState = name;
      this.pendingReset = resetEyes;
      return;
    }
    const rec = findState(name);
    if (!rec) {
      return;
    }
    this.state = name;
    this.stateAt = this.last;
    this.trick = null;
    this.spinTurnS = null;
    this.hopAt = -1;
    this.wildWide = false;
    const list = rec.playlist;
    this.eyeIdx = 0;
    if (resetEyes) {
      this.eyeFrom = list[0];
      this.eyeTo = list[0];
      this.fromPolys = null;
      this.eyeMorphS.snap(1);
    } else if (name !== 'sleeping' && name !== 'waking') {
      this.morphEyes(list[0], name === 'excited' ? 10 : 8);
    }
    const hold = rand(rec.holdMs[0], rec.holdMs[1]);
    this.eyeHoldMs = hold;
    this.eyeRemain = hold;
    this.eyeUntil = this.stateAt + hold;
    this.blinkUntil = rec.blinkMs ? this.stateAt + rand(1500, 7000) : Infinity;
    this.gazeUntil = this.stateAt + rand(500, 1400);
    this.winkUntil = this.stateAt + rand(3000, 8000);
    this.freshCtx(this.stateAt);
    this.ctxSt.stAt = this.stateAt + (
      name === 'excited' ? rand(400, 1100)
        : name === 'searching' ? rand(800, 1600)
          : name === 'working' ? rand(1200, 2400)
            : rand(6000, 10000));
    this.celebrateAt = name === 'celebrate' ? this.stateAt + 140 : -1;
    this.fx.reset(this.stateAt);
    if (name !== 'waking' && name !== 'sleeping' && name !== 'drowsy') {
      this.queueBlink(this.stateAt);
    }
  }

  setShape(name: string): void {
    if (name === this.shapeName) {
      return;
    }
    const prev = shapeByName(this.shapeName);
    const next = shapeByName(name);
    const k = K2(clamp(this.shapeSpringS.x, 0, 1));
    if (k >= 1 || this.prevRing === null) {
      this.prevRing = prev.ring;
    } else {
      this.prevRing = this.lerpRing(this.prevRing, prev.ring, k);
    }
    this.shapeName = name;
    this.shapeSpringS.x = 0;
    this.shapeSpringS.v = 0;
    this.shapeSpringS.t = 1;
    this.cycleShapeTrick();
  }

  setPaused(v: boolean): void {
    this.paused = !!v;
  }

  setEmphasis(v: boolean): void {
    this.emphasis = !!v;
  }

  // 首页滚动弹簧：每帧接收组件 avSize（目标），引擎内弹簧逼近
  setViewTarget(px: number): void {
    if (px > 1) {
      this.viewTarget = px;
    }
  }

  // idle 是否启用低频随机动作（spin/hop/…）
  setIdleMoves(v: boolean): void {
    this.idleMoves = !!v;
  }

  spinOnce(turns: number): void {
    if (this.paused || this.reduceMotion) {
      return;
    }
    this.pn(turns, sign());
  }

  bounceOnce(): void {
    if (this.paused || this.reduceMotion) {
      return;
    }
    this.hopAt = this.last;
  }

  pointerTo(x: number, y: number, sizePx: number): void {
    if (sizePx <= 0) {
      return;
    }
    const nx = (x / sizePx - 0.5) * 2;
    const ny = (y / sizePx - 0.5) * 2;
    this.pointerTx = clamp(nx, -0.6, 0.6) * 22;
    this.pointerTy = clamp(ny, -0.6, 0.6) * 14;
  }

  clearPointer(): void {
    this.pointerTx = 0;
    this.pointerTy = 0;
  }

  setNow(now: number): void {
    this.last = now;
  }

  getStateName(): string {
    return this.state;
  }

  isBusy(): boolean {
    return true; // 呼吸/眨眼永续，主推 60fps；暂停态由调用方跳过
  }

  // ---------------- 内部 ----------------

  private freshCtx(now: number): void {
    this.ctxSt = new StateCtx();
    this.ctxSt.nodUntil = now + rand(1200, 2200);
    this.ctxSt.impulseAt = now + rand(500, 1200);
    this.ctxSt.slumpAt = 0;
    this.ctxSt.stAt = now + rand(6000, 10000);
    this.ctxSt.dragCycle = -1;
    this.ctxSt.notifyPop = false;
    this.ctxSt.wakingBlinked = false;
    this.ctxSt.wakeBlink = false;
    this.ctxSt.forceSleepEye = false;
    this.ctxSt.wakeEye = null;
    this.ctxSt.wantPn = null;
    this.ctxSt.wantBlink = false;
    this.ctxSt.tyKick = 0;
    this.ctxSt.spinKick = 0;
  }

  private queueBlink(now: number): void {
    this.blinkQueue.push([now, 0.05]);
    this.blinkQueue.push([now + 70, 0.05]);
    this.blinkQueue.push([now + 150, 1.08]);
    this.blinkQueue.push([now + 300, 1]);
    if (Math.random() < 0.14) {
      this.blinkQueue.push([now + 370, 0.05]);
      this.blinkQueue.push([now + 480, 1]);
    }
  }

  private consumeBlink(now: number): number | null {
    let key: number | null = null;
    while (this.blinkQueue.length > 0 && now >= this.blinkQueue[0][0]) {
      key = this.blinkQueue.shift()![1];
    }
    return key;
  }

  private winkLid(base: number, now: number, i: number): number {
    let lid = Math.max(base, 0.04);
    if (now < this.winkAt + 320) {
      const xr = (now - this.winkAt) / 320;
      const Fr = xr < 0.42 ? 1 - xr / 0.42 : (xr - 0.42) / 0.58;
      lid = Math.max(lid * clamp(Fr, 0, 1), 0.04);
    }
    void i;
    return lid;
  }

  private morphEyes(index: number, stiffness: number): void {
    if (index === this.eyeTo && this.eyeMorphS.t === 1) {
      return;
    }
    const t = clamp(this.eyeMorphS.x, 0, 1);
    this.eyeFrom = this.eyeTo;
    this.fromPolys = this.currentPolys(t);
    this.eyeTo = index;
    this.eyeMorphS.x = 0;
    this.eyeMorphS.v = 0;
    this.eyeMorphS.t = 1;
    this.eyeStiffness = stiffness;
  }

  private currentPolys(t: number): number[][][] {
    const src = this.fromPolys ? this.fromPolys : [MOMO_EYES[this.eyeFrom].left, MOMO_EYES[this.eyeFrom].right];
    const to = MOMO_EYES[this.eyeTo];
    return [lerpPoly(src[0], to.left, t), lerpPoly(src[1], to.right, t)];
  }

  private pn(turns: number, dir: number): void {
    if (this.reduceMotion || this.paused || this.spinTurnS !== null) {
      return;
    }
    const s = new Spring(0);
    s.t = turns * Math.PI * 2 * dir;
    this.spinTurnS = s;
  }

  private cycleShapeTrick(): void {
    if (this.reduceMotion || this.paused || !this.autoTricks) {
      return;
    }
    this.trickCycle = (this.trickCycle + 1) % 5;
    this.wildWide = false;
    if (this.trickCycle === 0) {
      this.pn(1, sign());
    } else if (this.trickCycle === 1) {
      this.wildWide = true;
      this.pn(2, sign());
    } else if (this.trickCycle === 2) {
      if (!this.trick) {
        this.trick = this.startTrick('spinBounce');
      }
    } else if (this.trickCycle === 3) {
      if (!this.trick) {
        this.trick = this.startTrick('spinDizzy');
      }
    } else {
      this.pn(1, sign());
    }
  }

  private startTrick(kind: string): Trick | null {
    if (this.reduceMotion) {
      return null;
    }
    const t = new Trick();
    t.kind = kind;
    t.t0 = this.last;
    t.dir = sign();
    t.turns = kind === 'spinDizzy' ? Math.round(rand(3, 4)) : kind === 'spinWild' ? 9 : 1;
    return t;
  }

  // ---------------- tricks eval（移植 Web tricks.js） ----------------

  private evalTrick(trick: Trick | null, now: number): TrickFx {
    if (!trick) {
      return TRICK_EMPTY;
    }
    const Et = (now - trick.t0) / 1000;
    const kind = trick.kind;
    const dir = trick.dir;
    const turns = trick.turns;
    const out = new TrickFx();
    if (kind === 'spinDizzy') {
      const on = 0.55 + turns * 0.16;
      const bn = 1.5;
      if (Et < on) {
        const Cn = Et / on;
        out.turn = turns * Math.PI * 2 * dir * (Cn * Cn);
      } else if (Et < on + bn) {
        const Cn = Et - on;
        const bi = Math.pow(1 - Cn / bn, 1.3);
        out.Kr = Math.sin(Cn * 10) * 17 * dir * bi;
        out.yi = Math.cos(Cn * 10) * 10 * dir * bi;
        out.ki = Math.sin(Cn * 20) * 3 * bi;
        out.lidMul = 0.46 + 0.14 * Math.sin(Cn * 21);
        out.eyeBoost = 1.03;
      } else {
        out.done = true;
      }
    } else if (kind === 'spinWild') {
      const ud = 2.3 - 0.3;
      const Pc = 0.5;
      const Go = Math.PI * 2;
      const End = 0.24 + 2.3 + 1.25;
      const gm = (turns * Go + Pc) / (0.3 / 2 + ud + 1.25 / 4);
      if (Et < End + 1.7) {
        let cr = 0;
        if (Et < 0.24) {
          cr = -Pc * (1 - Math.cos((Et / 0.24) * Math.PI)) / 2;
        } else if (Et < 0.24 + 0.3) {
          const Ua = Et - 0.24;
          cr = -Pc + gm * Ua * Ua / (2 * 0.3);
        } else if (Et < 0.24 + 2.3) {
          cr = -Pc + gm * (0.3 / 2 + (Et - 0.24 - 0.3));
        } else if (Et < End) {
          const Ua = (Et - 0.24 - 2.3) / 1.25;
          cr = -Pc + gm * (0.3 / 2 + ud) + gm * 1.25 * (1 - Math.pow(1 - Ua, 4)) / 4;
        } else {
          cr = turns * Go;
        }
        out.turn = cr * dir;
        let pl = 0;
        if (Et > 0.24 + 2.3) {
          const Ua = Math.min((Et - 0.24 - 2.3) / 1.25, 1);
          pl = Ua < 0.4 ? 0 : Math.pow((Ua - 0.4) / 0.6, 2);
          if (Et >= End) {
            pl = Math.pow(1 - (Et - End) / 1.7, 1.6);
          }
        }
        const Yl = Math.max(Et - 0.24 - 2.3, 0);
        out.Yr = cr / (turns * Go) * 3 * 360 * dir;
        out.Kr = Math.sin(Yl * 9.2) * 11 * dir * pl;
        out.yi = (Math.cos(Yl * 9.2) - 1) * 6 * dir * pl;
        out.ki = Math.sin(Yl * 18.4) * 2.6 * pl;
        out.Zr = Math.sin(Yl * 11.5) * 13 * dir * pl;
        out.wi = (Math.cos(Yl * 9) - 1) * 3.5 * pl;
        out.lidMul = 1.14 - 0.44 * pl + 0.1 * Math.sin(Yl * 16) * pl;
        out.eyeBoost = 1.12 - 0.09 * pl;
      } else {
        out.done = true;
      }
    } else if (kind === 'spinBounce') {
      if (Et < 0.7) {
        out.turn = turns * Math.PI * 2 * dir * K2(Et / 0.7);
      } else {
        out.wantHop = true;
        out.done = true;
      }
    }
    return out;
  }

  // hop 抛物线（Web HOP_SEGS）
  private hopY(now: number): number | null {
    if (this.hopAt < 0) {
      return 0;
    }
    const Et = (now - this.hopAt) / 1000;
    const segs: number[][] = [[48, 0.5], [28, 0.382], [14, 0.27], [6, 0.177]];
    let total = 0;
    for (const seg of segs) {
      total += seg[1];
    }
    if (Et >= total) {
      return null;
    }
    let en = 0;
    for (const seg of segs) {
      if (Et < en + seg[1]) {
        const bn = (Et - en) / seg[1];
        return -4 * seg[0] * bn * (1 - bn);
      }
      en += seg[1];
    }
    return 0;
  }

  // ---------------- pose 目标（移植 Web pose.js applyPose） ----------------

  private applyPose(now: number, mt: number, dtState: number): PoseOut {
    const prev = this.poseOut;
    const out = new PoseOut();
    let spin = prev.spin;
    let tx = prev.tx;
    let ty = prev.ty;
    let squash = prev.squash;
    let lid = 1;
    let eyeBoost = 1;
    const ctx = this.ctxSt;
    const pt = 0;
    const state = this.state;
    const list = findState(state);
    const playlist = list ? list.playlist : [0];

    if (state === 'sleeping') {
      const En = Math.min(dtState / 2, 1);
      const Zt = Math.sin(clamp(dtState / 0.5, 0, 1) * Math.PI);
      spin = pt + 4 * En + Math.sin(mt * 0.25) * 2;
      tx = -2 * En;
      ty = 8 * En + Math.sin(mt * 0.55) * 3 - Zt * 5;
      squash = 1 + Math.sin(mt * 0.55) * 0.016 + Zt * 0.05;
      if (playlist.indexOf(this.eyeTo) >= 0) {
        lid = this.eyeMorphS.x > 0.85 ? 1 : 0.08;
      } else if (dtState < 1.2) {
        const dn = Math.min(1, dtState / 1);
        lid = Math.max(0.08, 1 - dn * (1 + 0.15 * Math.sin(dtState * 6.5)));
      } else {
        lid = 0.08;
        if (this.blinkS.x < 0.18) {
          ctx.forceSleepEye = true;
        }
      }
    } else if (state === 'waking') {
      if (dtState < 0.5) {
        lid = 0.07;
        ty = 6;
        ctx.wakeEye = [3, 12];
      } else if (dtState < 1.2) {
        lid = 1;
        eyeBoost = 1.12;
        ty = -5;
        tx = 0;
        spin = pt;
        squash = 1.04;
        if (!ctx.wakingBlinked) {
          ctx.wantBlink = true;
        }
      } else if (dtState < 2.2) {
        ty = 0;
        squash = 1;
        ctx.wakeEye = [0, 7];
        if (dtState < 1.4) {
          ctx.wakeBlink = true;
        }
      } else {
        const Et = Math.min((dtState - 2.2) / 0.8, 1);
        ctx.wakeEye = [0, 7];
        spin = pt + Math.sin(Et * Math.PI * 3) * 6 * (1 - Et);
        ty = Math.sin(mt * 0.9) * 2;
      }
    } else if (state === 'idle') {
      spin = pt + Math.sin(mt * 0.5) * 1.5 + Math.sin(mt * 0.17) * 0.6;
      tx = Math.sin(mt * 0.27) * 1;
      ty = Math.sin(mt * 0.85) * 1.2;
      squash = 1 + Math.sin(mt * 0.85) * 0.007;
    } else if (state === 'listening') {
      spin = pt + 8 + Math.sin(mt * 0.5) * 1.5;
      tx = 2;
      ty = -2 + Math.sin(mt * 0.8) * 0.8;
      squash = 1.015;
      if (now >= ctx.nodUntil) {
        ctx.nodUntil = now + rand(1800, 3200);
        ctx.nodEnd = now + 380;
      }
      if (now < ctx.nodEnd) {
        const Et = 1 - (ctx.nodEnd - now) / 380;
        ty += Math.sin(Et * Math.PI) * 4.5;
        spin += Math.sin(Et * Math.PI) * 2;
      }
    } else if (state === 'thinking') {
      spin = pt - 9 + Math.sin(mt * 0.35) * 5;
      tx = Math.sin(mt * 0.3) * 5;
      ty = Math.sin(mt * 0.6) * 2.5;
      squash = 1;
    } else if (state === 'searching') {
      const Et = Math.sin(mt * 1.3);
      spin = pt + Et * 13;
      tx = Et * 7;
      ty = Math.sin(mt * 1.7) * 3;
      squash = 1;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, sign()];
        ctx.stAt = now + rand(4000, 7000);
      }
    } else if (state === 'working') {
      const Et = Math.sin(mt * Math.PI * 2 * 1.6);
      spin = pt + 4 + Et * 2.5;
      tx = 3;
      ty = 1.5 + Math.max(0, Et) * 3;
      squash = 1 - Math.max(0, Et) * 0.02;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, 1];
        ctx.stAt = now + rand(6000, 9000);
      }
    } else if (state === 'excited') {
      const Et = (mt * 2.2) % 1;
      const En = Math.sin(Et * Math.PI);
      ty = -En * 10 + 2;
      squash = Et < 0.1 ? 0.92 : Et < 0.3 ? 1.05 : 1;
      tx = Math.sin(mt * 1.1) * 4;
      eyeBoost = 1.06;
      spin = pt + Math.sin(mt * Math.PI * 2 * 1.1) * 7;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, sign()];
        ctx.stAt = now + rand(2800, 5000);
      }
    } else if (state === 'surprised') {
      const Et = Math.min(dtState / 1.2, 1);
      tx = -4 * (1 - Et);
      ty = -8 * (1 - Et);
      squash = dtState < 0.2 ? 1.08 : 1;
      eyeBoost = 1.15 - Et * 0.08;
      spin = pt + Math.sin(mt * 11) * 1.5 * (1 - Et);
    } else if (state === 'suspicious') {
      spin = pt - 6 + Math.sin(mt * 0.3) * 3;
      tx = Math.sin(mt * 0.25) * -4;
      ty = 1 + Math.sin(mt * 0.45) * 1.2;
      squash = 1;
      lid = 0.8;
      if (now >= ctx.impulseAt) {
        ctx.spinKick = 30;
        ctx.impulseAt = now + rand(4000, 7000);
      }
    } else if (state === 'angry') {
      if (now >= ctx.impulseAt) {
        ctx.angryShakeUntil = now + 420;
        ctx.tyKick = 70;
        ctx.impulseAt = now + rand(1800, 3200);
      }
      spin = pt + (now < ctx.angryShakeUntil ? Math.sin(now * 0.05) * 4.5 : 0);
      tx = 0;
      ty = 3.5;
      squash = 0.975;
    } else if (state === 'drowsy') {
      spin = pt + Math.sin(mt * 0.32) * 2.5;
      tx = Math.sin(mt * 0.2) * 1.5;
      ty = 6 + Math.sin(mt * 0.36) * 2.2;
      squash = 1 + Math.sin(mt * 0.36) * 0.022;
      lid = 0.34 + Math.sin(mt * 0.8) * 0.07;
      if (now >= ctx.nodUntil && !ctx.slumpAt) {
        ctx.slumpAt = now;
      }
      if (ctx.slumpAt) {
        const En = (now - ctx.slumpAt) / 1000;
        const Zt = 1.7;
        const dn = 0.3;
        const on = 1.5;
        if (En < Zt) {
          const bn = En / Zt;
          const Cn = bn * bn;
          const bi = Math.sin(bn * Math.PI * 2.5) * 2.2 * (1 - bn);
          ty = 6 + Cn * 19 + bi;
          spin = pt + Cn * 10;
          lid = 0.34 - Cn * (0.34 - 0.04);
          squash = 1 - Cn * 0.045;
        } else if (En < Zt + dn) {
          const bn = (En - Zt) / dn;
          const Cn = Math.sin(bn * Math.PI);
          ty = 25 - Cn * 7;
          spin = pt + 10 - Cn * 4;
          lid = 0.04 + Cn * 0.42;
        } else if (En < Zt + dn + on) {
          const bn = (En - Zt - dn) / on;
          const Cn = 1 - Math.pow(1 - bn, 2.2);
          ty = 25 - 19 * Cn;
          spin = pt + 10 * (1 - Cn);
          lid = 0.46 + (0.34 - 0.46) * Cn;
          if (bn > 0.32 && bn < 0.46) {
            lid = 0.05;
          }
        } else {
          ctx.slumpAt = 0;
          ctx.nodUntil = now + rand(1500, 3500);
        }
      }
    } else if (state === 'happy') {
      const Et = Math.sin(mt * 2.4);
      spin = pt + Math.sin(mt * 1.2) * 3;
      tx = Math.sin(mt * 1.1) * 2.5;
      ty = -Math.abs(Et) * 3;
      squash = 1 + Et * 0.02;
      eyeBoost = 1.05;
    } else if (state === 'curious') {
      spin = pt + 10 + Math.sin(mt * 0.7) * 6;
      tx = Math.sin(mt * 0.6) * 5;
      ty = -2 + Math.sin(mt * 0.9) * 1.5;
      squash = 1.01;
      eyeBoost = 1.08;
      if (now >= ctx.nodUntil) {
        ctx.nodUntil = now + rand(1600, 2800);
        ctx.nodEnd = now + 440;
      }
      if (now < ctx.nodEnd) {
        const Et = 1 - (ctx.nodEnd - now) / 440;
        tx += Math.sin(Et * Math.PI) * 8;
        spin += Math.sin(Et * Math.PI) * 5;
      }
    } else if (state === 'confused') {
      const Et = Math.sin(mt * 0.8);
      spin = pt + Et * 12;
      tx = Et * 3;
      ty = Math.sin(mt * 0.5) * 2;
      squash = 1;
      lid = 0.9;
      if (now >= ctx.impulseAt) {
        ctx.spinKick = 22;
        ctx.impulseAt = now + rand(2600, 4200);
      }
    } else if (state === 'bored') {
      spin = pt - 3 + Math.sin(mt * 0.25) * 4;
      tx = Math.sin(mt * 0.2) * 4;
      ty = 5 + Math.sin(mt * 0.35) * 1.5;
      squash = 0.99;
      lid = 0.6;
      eyeBoost = 0.98;
      if (now >= ctx.impulseAt) {
        ctx.nodEnd = now + 600;
        ctx.impulseAt = now + rand(4000, 7000);
      }
      if (now < ctx.nodEnd) {
        const Et = 1 - (ctx.nodEnd - now) / 600;
        squash = 1 + Math.sin(Et * Math.PI) * 0.05;
        ty += Math.sin(Et * Math.PI) * 3;
      }
    } else if (state === 'proud') {
      spin = pt + Math.sin(mt * 0.4) * 2.5;
      tx = Math.sin(mt * 0.35) * 2;
      ty = -4 + Math.sin(mt * 0.6);
      squash = 1.03;
      eyeBoost = 1.02;
      lid = 0.9;
    } else if (state === 'shy') {
      spin = pt - 8 + Math.sin(mt * 0.5) * 3;
      tx = -3 + Math.sin(mt * 0.4) * 2;
      ty = 3;
      squash = 0.98;
      eyeBoost = 0.95;
      lid = 0.85;
    } else if (state === 'sad') {
      spin = pt + 3 + Math.sin(mt * 0.3) * 2;
      tx = Math.sin(mt * 0.25) * 1.5;
      ty = 7 + Math.sin(mt * 0.4);
      squash = 0.97;
      lid = 0.7;
      eyeBoost = 0.97;
    } else if (state === 'laughing') {
      const Et = Math.sin(mt * Math.PI * 2 * 3.2);
      spin = pt + Et * 4;
      tx = Math.sin(mt * 2) * 2;
      ty = -Math.abs(Et) * 5;
      squash = 1 + Et * 0.03;
      lid = 0.7;
    } else if (state === 'scared') {
      spin = pt + Math.sin(now * 0.04) * 2;
      tx = -2 + Math.sin(now * 0.05) * 1.5;
      ty = 2 + Math.sin(mt * 1.5);
      squash = 0.97;
      eyeBoost = 1.12;
      lid = 1.05;
    } else if (state === 'playful') {
      spin = pt + Math.sin(mt * 1.4) * 8;
      tx = Math.sin(mt * 1.1) * 4;
      ty = -Math.abs(Math.sin(mt * 2.2)) * 3;
      squash = 1 + Math.sin(mt * 2.2) * 0.015;
      eyeBoost = 1.06;
      if (now >= ctx.stAt) {
        ctx.wantPn = [1, sign()];
        ctx.stAt = now + rand(3500, 6000);
      }
    } else if (state === 'celebrate') {
      spin = pt;
      tx = 0;
      ty = -Math.abs(Math.sin(mt * 1.6)) * 2.5;
      squash = 1;
      eyeBoost = 1.1;
      lid = 1.1;
    } else if (state === 'dragging') {
      const En = (dtState % 3.4) / 3.4;
      if (En < 0.12) {
        tx = -16;
        ty = -22;
        spin = pt - 5;
      } else if (En < 0.62) {
        const dn = (En - 0.12) / 0.5;
        tx = -16 + 32 * K2(dn);
        ty = -22 + Math.sin(mt * 1.4) * 2;
        spin = pt + Math.sin(mt * 2.6) * 6;
        eyeBoost = 1.06;
      } else {
        const cycle = Math.floor(dtState / 3.4);
        if (cycle !== ctx.dragCycle) {
          ctx.dragCycle = cycle;
          ctx.tyKick = 90;
        }
        tx = 16;
        ty = 0;
        spin = pt;
      }
      squash = 1;
    } else if (state === 'humming' || state === 'loading') {
      spin = pt + Math.sin(mt * 0.4) * 2;
      tx = Math.sin(mt * 0.3) * 1.5;
      ty = Math.sin(mt * 0.7) * 1.5;
      squash = 1;
    } else if (state === 'notifying') {
      if (!ctx.notifyPop && dtState > 0.12) {
        ctx.notifyPop = true;
        ctx.tyKick = -26;
        ctx.wantBlink = true;
      }
      eyeBoost = 1 + 0.05 * Math.exp(-dtState * 3);
      spin = pt + 3;
      tx = 2;
      ty = -1;
      squash = 1;
    } else {
      spin = pt;
      tx = 0;
      ty = 0;
      squash = 1;
    }
    out.spin = spin;
    out.tx = tx;
    out.ty = ty;
    out.squash = squash;
    out.lid = lid;
    out.eyeBoost = eyeBoost;
    return out;
  }

  private nextGaze(): number[] {
    const rec = findState(this.state);
    if (!rec) {
      return [0, 0, 2500];
    }
    let gx: number;
    let gy: number;
    if (rec.gxRand) {
      gx = sign() * rand(rec.gxMin, rec.gxMax) * 15;
    } else {
      gx = rand(rec.gxMin, rec.gxMax) * 15;
    }
    if (rec.gyRand) {
      gy = sign() * rand(rec.gyMin, rec.gyMax) * 9;
    } else {
      gy = rand(rec.gyMin, rec.gyMax) * 9;
    }
    if (this.state === 'notifying' && Math.random() >= 0.72) {
      gx = 0.1 * 15;
      gy = -0.05 * 9;
    }
    const hold = rand(rec.gHold[0], rec.gHold[1]);
    return [gx, gy, hold];
  }

  // ---------------- overlay 步进（移植 _stepOverlay） ----------------

  private stepOverlay(now: number): void {
    const rec = findState(this.state);
    const want = (rec && rec.overlay !== '') ? rec.overlay : null;
    if (want !== this.ovTarget) {
      this.ovTarget = want;
      this.fx.reset(now);
      this.ovRest = false;
      this.ovRestAt = 0;
      this.ovStartAt = now;
    }
    let on = want !== null;
    if (want && rec && rec.cycle) {
      const cycleOn = rec.name === 'progress' ? 2500 : 2000;
      if (!this.ovRest && now - this.ovStartAt > cycleOn) {
        this.ovRest = true;
        this.ovRestAt = now;
      } else if (this.ovRest && now - this.ovRestAt > 1500) {
        this.ovRest = false;
        this.ovStartAt = now;
      }
      on = !this.ovRest;
    }
    this.overlayS.t = on ? 1 : 0;
    if (on !== this.ovOn) {
      if (!this.reduceMotion) {
        if (on) {
          this.ovTurnDir = sign();
        }
        this.ovTurnAcc += Math.PI * this.ovTurnDir;
        this.overlayTurnS.t = this.ovTurnAcc;
      }
      this.ovOn = on;
    }
    if (want && want !== this.ovKind) {
      if (this.ovKind !== '' && this.overlayS.x > 0.02) {
        this.ovPrev = this.ovKind;
        this.overlayMixS.x = 0;
        this.overlayMixS.v = 0;
        this.overlayMixS.t = 1;
      } else {
        this.ovPrev = '';
        this.overlayMixS.x = 1;
        this.overlayMixS.v = 0;
        this.overlayMixS.t = 1;
      }
      this.ovKind = want;
      this.fx.reset(now);
    }
    if (!want && this.overlayS.x < 0.004) {
      this.ovKind = '';
      this.ovPrev = '';
    }
    if (this.overlayMixS.x > 0.996) {
      this.ovPrev = '';
    }
  }

  // ---------------- 主 tick ----------------

  tick(nowMs: number, dtSec: number): void {
    if (this.paused) {
      this.last = nowMs;
      return;
    }
    if (!this.booted) {
      this.booted = true;
      this.boot(nowMs);
    }
    const dt = Math.min(dtSec, 0.1);
    this.last = nowMs;
    const now = nowMs;

    if (this.mode === 'onboarding' && now - this.stateAt >= ONBOARDING_MS) {
      this.moodN += 1;
      if (this.moodN % 2 === 0) {
        this.setState('idle', false);
      } else {
        const idx = Math.floor(((this.moodN - 1) / 2) % ONBOARDING_SEQ.length);
        this.setState(ONBOARDING_SEQ[idx], false);
      }
    }

    const mt = (now - this.t0) / 1000;
    const dtState = (now - this.stateAt) / 1000;
    const pose = this.applyPose(now, mt, dtState);
    this.poseOut = pose;
    this.spinS.t = pose.spin;
    this.txS.t = pose.tx;
    this.tyS.t = pose.ty;
    this.squashS.t = pose.squash;
    this.eyeScaleS.t = pose.eyeBoost;

    if (this.ctxSt.tyKick !== 0) {
      this.tyS.v += this.ctxSt.tyKick;
      this.ctxSt.tyKick = 0;
    }
    if (this.ctxSt.spinKick !== 0) {
      this.spinS.v += this.ctxSt.spinKick;
      this.ctxSt.spinKick = 0;
    }
    if (this.ctxSt.forceSleepEye) {
      this.ctxSt.forceSleepEye = false;
      this.morphEyes(13, 11);
    }
    if (this.ctxSt.wakeEye) {
      this.morphEyes(this.ctxSt.wakeEye[0], this.ctxSt.wakeEye[1]);
      this.ctxSt.wakeEye = null;
    }
    if (this.ctxSt.wakeBlink && !this.ctxSt.wakingBlinked && this.blinkQueue.length === 0) {
      this.queueBlink(now);
      this.ctxSt.wakingBlinked = true;
    }
    this.ctxSt.wakeBlink = false;
    if (this.ctxSt.wantBlink) {
      this.queueBlink(now);
      this.ctxSt.wantBlink = false;
    }
    if (this.ctxSt.wantPn) {
      if (this.autoTricks) {
        this.pn(this.ctxSt.wantPn[0], this.ctxSt.wantPn[1]);
      }
      this.ctxSt.wantPn = null;
    }

    this.stepOverlay(now);

    if (this.autoTricks && this.celebrateAt > 0 && now >= this.celebrateAt && !this.trick) {
      this.trick = this.startTrick('spinWild');
      this.celebrateAt = now + 6200;
    }
    const rec = findState(this.state);
    if (this.autoTricks && now >= this.trickAt && rec && (rec.vt || rec.bt)) {
      const z = Math.random();
      if (rec.vt) {
        if (z < 0.55) {
          this.pn(1, sign());
        } else {
          this.trick = this.startTrick('spinBounce');
        }
      } else if (z < 0.34) {
        this.trick = this.startTrick('spinBounce');
      } else if (z < 0.62) {
        this.hopAt = now;
      } else if (z < 0.86) {
        this.trick = this.startTrick('spinDizzy');
      } else {
        this.pn(1, sign());
      }
      this.trickAt = now + rand(9000, 18000);
    }
    // idle 低频随机动作池：让首页默默更活泼（6-12s 一次）
    if (this.autoTricks && this.idleMoves && this.state === 'idle' && now >= this.idleTrickAt
      && !this.trick && this.spinTurnS === null && this.hopAt < 0) {
      const z = Math.random();
      if (z < 0.4) {
        this.pn(1, sign());
      } else if (z < 0.65) {
        this.hopAt = now;
      } else if (z < 0.85) {
        this.trick = this.startTrick('spinBounce');
      } else {
        this.trick = this.startTrick('spinDizzy');
      }
      this.idleTrickAt = now + rand(6000, 12000);
    }

    const tf = this.evalTrick(this.trick, now);
    if (tf.wantHop) {
      this.hopAt = now;
    }
    if (tf.done) {
      this.trick = null;
    }
    if (tf.eyeBoost !== null) {
      this.eyeScaleS.t = tf.eyeBoost;
    }

    // 眼睛播放列表推进
    if (this.state !== 'waking' && this.state !== 'sleeping' && now >= this.eyeUntil) {
      const list = rec ? rec.playlist : [0];
      const step = 1 + Math.floor(rand(0, list.length - 1));
      this.eyeIdx = (this.eyeIdx + step) % list.length;
      const stiff = this.state === 'searching' || this.state === 'excited' ? 10 : 6;
      this.morphEyes(list[this.eyeIdx], stiff);
      const hold = rand(rec ? rec.holdMs[0] : 2000, rec ? rec.holdMs[1] : 3600);
      this.eyeHoldMs = hold;
      this.eyeRemain = hold;
      this.eyeUntil = now + hold;
    }

    // 眨眼节律
    const blinkCadence = rec ? rec.blinkMs : null;
    if (blinkCadence && now >= this.blinkUntil) {
      this.queueBlink(now);
      this.blinkUntil = now + rand(blinkCadence[0], blinkCadence[1]);
    }
    const blinkKey = this.consumeBlink(now);
    const lidTarget = blinkKey !== null ? blinkKey
      : (this.blinkQueue.length > 0 ? this.blinkS.t
        : (tf.lidMul !== null ? tf.lidMul : pose.lid));
    this.blinkS.t = lidTarget;

    // gaze
    if (now >= this.gazeUntil) {
      const gz = this.nextGaze();
      this.gazeXS.t = gz[0];
      this.gazeYS.t = gz[1];
      this.gazeUntil = now + gz[2];
    }
    // wink
    if (rec && rec.wink && now >= this.winkUntil) {
      this.winkAt = now;
      this.winkEye = Math.random() < 0.5 ? 0 : 1;
      this.winkUntil = now + rand(4500, 10000);
    }
    // emphasis
    if (this.emphasis) {
      this.eyeScaleS.t = Math.max(this.eyeScaleS.t, 1.32);
      this.blinkS.t = Math.max(this.blinkS.t, 1.18);
    }
    // humming/loading ovSpin
    const humming = this.state === 'humming';
    const loading = this.state === 'loading';
    if ((humming || loading) && !this.reduceMotion) {
      const Zt = dtState;
      const dn = loading ? 3 : 1.6;
      const on = Zt < 0.5 ? 7 * K2(Zt / 0.5) : Zt < 1.3 ? 7 + (dn - 7) * K2((Zt - 0.5) / 0.8) : dn + 0.3 * Math.sin(Zt * 0.5);
      this.ovSpin += on * dt;
    }

    // 弹簧积分（子步 1/120）
    const nSteps = Math.max(1, Math.ceil(dt / (1 / 120)));
    const step = dt / nSteps;
    for (let i = 0; i < nSteps; i++) {
      this.eyeMorphS.step(this.eyeStiffness, 1, step);
      if (this.spinTurnS) {
        this.spinTurnS.step(6.2, 1, step);
      }
      this.spinS.step(5, 0.9, step);
      this.txS.step(3.5, 1, step);
      this.tyS.step(4, 1, step);
      this.squashS.step(10, 0.8, step);
      this.blinkS.step(26, 1, step);
      this.eyeScaleS.step(9, 0.85, step);
      this.notifyS.step(9, 0.55, step);
      this.humDotsS.step(6, 1, step);
      this.gazeXS.step(13, 1, step);
      this.gazeYS.step(13, 1, step);
      this.overlayS.step(14, 1, step);
      this.overlayMixS.step(11, 1, step);
      this.shapeSpringS.step(10, 1, step);
      this.overlayTurnS.step(14, 1, step);
    }

    // 指针跟随（spring）
    const z = Rn(0.16);
    this.pointerX += (this.pointerTx - this.pointerX) * z;
    this.pointerY += (this.pointerTy - this.pointerY) * z;

    // 滚动尺寸弹簧（freq7/damp1.05：轻微惯性回弹）
    this.viewS.t = this.viewTarget;
    this.viewS.step(7, 1.05, dt);

    this.notifyS.t = this.state === 'notifying' ? 1 : 0;
    this.humDotsS.t = this.state === 'humming' ? 1 : 0;

    if (this.spinTurnS) {
      if (Math.abs(this.spinTurnS.t - this.spinTurnS.x) < 0.004 && Math.abs(this.spinTurnS.v) < 0.015) {
        this.spinTurnS = null;
        this.wildWide = false;
      }
    }
  }

  // ---------------- 绘制 ----------------

  paint(ctx: CanvasRenderingContext2D, sizePx: number): void {
    if (sizePx <= 1) {
      return;
    }
    const now = this.last;
    // 每帧清屏：Canvas 不自动清除旧像素（否则 spin/滚动产生残影）
    ctx.clearRect(0, 0, sizePx, sizePx);
    // 视觉尺寸 = 弹簧值（滚动有惯性回弹；不超过画布防止裁切）
    const drawPx = Math.min(Math.abs(this.viewS.x), sizePx);
    const scale = drawPx / VIEW;
    ctx.save();
    ctx.scale(scale, scale);

    // 地面阴影（不随身体）
    ctx.save();
    ctx.globalAlpha = 0.16;
    ctx.fillStyle = MOMO_INK.shadow;
    ctx.beginPath();
    ctx.ellipse(R, R + 88, 42, 11, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    const yl = clamp(this.overlayS.x, 0, 1);
    const mix = clamp(this.overlayMixS.x, 0, 1);
    const ex = this.fx.extras(now, this.stateAt, this.ovKind, this.ovPrev, yl, mix);
    const bodyW = 1 - 0.18 * yl;
    const hop = this.hopY(now);
    const hopV = (hop === null || hop === 0) ? 0 : hop;
    const tx = this.txS.x * bodyW + ex.yre * yl;
    const ty = (this.tyS.x + hopV) * bodyW + ex.aX * yl + ex.ballY;
    const turn = this.currentTurn();
    const rot = (this.spinS.x * bodyW + turn) * 1 + ex.wl * yl;
    const sx = bodyW;
    const sy = this.squashS.x * bodyW + 0.02 * yl;

    // 身体 + 眼睛（clip 到身体内）
    ctx.save();
    ctx.translate(R + tx, R + ty);
    ctx.rotate(rot * Math.PI / 180);
    ctx.scale(sx, sy);
    ctx.translate(-R, -R);

    const shape = shapeByName(this.shapeName);
    const morphK = K2(clamp(this.shapeSpringS.x, 0, 1));
    const morphing = morphK < 0.999 && this.prevRing !== null;
    const ring = morphing
      ? this.lerpRing(this.prevRing !== null ? this.prevRing : shape.ring, shape.ring, morphK)
      : shape.ring;

    // body path + 渐变填充
    this.bodyPath(ctx, ring);
    if (!this.bodyGrad) {
      const g = ctx.createRadialGradient(R - 30, R - 35, 12, R, R, 125);
      g.addColorStop(0, MOMO_INK.bodyFrom);
      g.addColorStop(0.55, MOMO_INK.bodyMid);
      g.addColorStop(1, MOMO_INK.bodyTo);
      this.bodyGrad = g;
    }
    ctx.fillStyle = this.bodyGrad;
    ctx.fill();
    ctx.lineWidth = 1.6;
    ctx.strokeStyle = MOMO_INK.stroke;
    ctx.stroke();

    // clip 后画眼睛
    ctx.save();
    this.bodyPath(ctx, ring);
    ctx.clip();
    this.paintEyes(ctx, now, shape);
    ctx.restore();

    ctx.restore();

    // overlay（屏幕坐标）
    this.fx.paint(ctx, now, this.stateAt, this.ovKind, this.ovPrev, yl, mix, this.ovSpin);

    // notifying 徽标
    if (this.notifyS.x > 0.02) {
      const amt = clamp(this.notifyS.x, 0, 1.4);
      ctx.fillStyle = MOMO_INK.badge;
      ctx.beginPath();
      ctx.arc(R + 66, R - 66, 20 * amt, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();
  }

  private currentTurn(): number {
    if (this.spinTurnS) {
      return this.spinTurnS.x;
    }
    const tf = this.evalTrick(this.trick, this.last);
    if (tf.turn !== null) {
      return tf.turn;
    }
    if (this.state === 'humming' || this.state === 'loading') {
      return this.ovSpin;
    }
    return 0;
  }

  private bodyPath(ctx: CanvasRenderingContext2D, ring: number[][]): void {
    const segs = closedSplineSegs(ring);
    ctx.beginPath();
    ctx.moveTo(ring[0][0], ring[0][1]);
    for (let i = 0; i < segs.length; i++) {
      const s = segs[i];
      ctx.bezierCurveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
    }
    ctx.closePath();
  }

  private paintEyes(ctx: CanvasRenderingContext2D, now: number, shape: MoMoShape): void {
    const morphT = clamp(this.eyeMorphS.x, 0, 1);
    const polys = this.currentPolys(morphT);
    const pulse = 1 + 0.07 * Math.sin(morphT * Math.PI);
    const sXS = shape.faceSX;
    const faceEye = shape.faceEye;
    const faceX = shape.faceX;
    const faceY = shape.faceY;
    const top = shape.top;
    const bottom = shape.bottom;

    const cents: number[][] = [polyCentroid(polys[0]), polyCentroid(polys[1])];
    let a1 = 0;
    let o1 = 0;
    for (const p of polys[0]) {
      a1 = Math.max(a1, Math.abs(p[0] - cents[0][0]));
    }
    for (const p of polys[1]) {
      o1 = Math.max(o1, Math.abs(p[0] - cents[1][0]));
    }
    // 眼距用基准位置差（局部多边形质心恒为 0，Web 为绝对坐标）
    const ll = Math.abs(18 - -18) * sXS;
    const cap = a1 + o1 > 0.5 ? clamp(ll / (a1 + o1), 0.35, 4) : 4;
    const oX = Math.min(clamp(this.eyeScaleS.x, 0.2, 2) * faceEye, cap / pulse);
    const Hee0 = Math.min(oX * 0.96, cap / pulse);
    const u10 = oX * 0.92;
    const gazeX = this.gazeXS.x;
    const gazeY = this.gazeYS.x;
    const notifyX = clamp(this.notifyS.x, 0, 1);

    // 椭圆参数化判定：双端均为椭圆（或已稳定到椭圆）时用原生 ctx.ellipse
    const fromG = MOMO_EYES[this.eyeFrom];
    const toG = MOMO_EYES[this.eyeTo];
    const morphDone = this.eyeMorphS.x > 0.999;
    const useEllipse = (morphDone && toG.kind === 'ellipse') ||
      (!morphDone && fromG.kind === 'ellipse' && toG.kind === 'ellipse');
    const exRx = lerp(fromG.rx, toG.rx, morphT);
    const eyRy = lerp(fromG.ry, toG.ry, morphT);
    // 眼睛基准位置（局部多边形中心 => 面部位置）：左 -18 / 右 +18
    const baseX: number[] = [-18, 18];
    for (let i = 0; i < 2; i++) {
      const poly = polys[i];
      const lid = this.winkLid(this.blinkS.x, now, i);
      const bx = baseX[i];
      const Wo = bx * sXS;

      let Kj = Math.sin(now * 42e-5 + i) * 1.4 + Math.sin(now * 0.001 + i * 2) * 0.5;
      let Ko = Math.sin(now * 58e-5 + i) * 0.9;
      Kj += this.pointerX;
      Ko += this.pointerY;
      Kj += gazeX;
      Ko += gazeY;
      Kj -= 10 * notifyX;
      Ko += 7 * notifyX;

      const Vee = clamp(Hee0 * pulse, 0.02, 2.4);
      const v2 = clamp(lid * u10 * pulse, 0.02, 2.4);
      const dd = R + faceX + Wo + Kj * sXS;
      const Yj = clamp(R + faceY + Ko, top + 2, bottom - 2);

      ctx.save();
      ctx.translate(dd, Yj);
      ctx.scale(Vee, v2);
      ctx.fillStyle = MOMO_INK.eye;
      ctx.beginPath();
      if (useEllipse) {
        // 真·椭圆：Canvas 原生 ellipse（完美抗锯齿）
        ctx.ellipse(0, 0, exRx, eyRy, 0, 0, Math.PI * 2);
      } else {
        // 弧线/折角眼型与跨类型 morph：闭合 Catmull-Rom 样条平滑（无折角）
        const segs = closedSplineSegs(poly);
        ctx.moveTo(poly[0][0], poly[0][1]);
        for (let k = 0; k < segs.length; k++) {
          const s = segs[k];
          ctx.bezierCurveTo(s[0], s[1], s[2], s[3], s[4], s[5]);
        }
        ctx.closePath();
      }
      ctx.fill();
      ctx.restore();
    }
  }

  private lerpRing(a: number[][], b: number[][], t: number): number[][] {
    const out: number[][] = [];
    for (let i = 0; i < a.length; i++) {
      out.push([a[i][0] + (b[i][0] - a[i][0]) * t, a[i][1] + (b[i][1] - a[i][1]) * t]);
    }
    return out;
  }
}
