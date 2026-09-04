/*
 * ============================================================================
 * 文件名：components/momo/MoMoOverlays.ets
 * ============================================================================
 * 【用途】弹簧驱动软体角色引擎的 overlay 特效层：在角色周边绘制状态
 *   徽标图形（thinking 三点 / orbit 环绕 / radar 扫描 / progress 进度环 /
 *   gather 聚集 / wave 声波 / send-recv 收发 / dock 上传 / whirl 加载 /
 *   pencil 书写 / bang 警示 / standby 熄屏 / ball 弹跳）。
 *   与 Web fx.js 的 OverlayLayer 同语义（MIT），绘制改为 ArkUI Canvas
 *   原生命令（世界系 0..200，中心 100,100），图形为 MoMo 简化复刻。
 * 【前置条件 / 假设】
 *   - 只调用 ctx 基本命令（arc/ellipse/moveTo/lineTo/stroke/fill/save/restore）；
 *   - 假设 overlay 状态由引擎 MoMoEngine 驱动（yl/mix/ovKind/ovPrev）；
 *   - 粒子数组小且复用（无每帧分配大结构）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：paint(ctx, now, stateAt, cur, prev, yl, mix, ovSpin)；
 *   - 输出：按需绘制 overlay 图形；extras() 返回身体扰动（y 位移/旋转）。
 * 【关键类 / 算法】
 *   - amount(name)：当前/前一 overlay 混合系数；
 *   - dotsPulse：思考点高斯脉冲（移植 Web dotsPulse）；
 *   - textFx 各绘制函数：与 Web paintXxx 简化等价。
 * 【参考源】
 *   - grok-icon-study-web/replica/src/fx.js（MIT）MAP/SCALE/RADIUS/周期等常量
 * ============================================================================
 */
import { clamp, Rc, y1e, K2 } from './MoMoMotionMath';
import { MOMO_INK } from './MoMoGeoData';

export class FxExtras {
  yre: number = 0;   // 平移 x
  aX: number = 0;    // 平移 y
  wl: number = 0;    // 旋转
  wre: number = 0;   // 缩放（保留接口）
  fade: number = 0;  // 淡出
  ballY: number = 0; // bouncing 弹跳位移
}

const R: number = 100;
const DOT_R = 22;
const DOT_GAP = 62;
const POP0 = 0.84;
const POP1 = 0.22;
const SEND_MS = 1500;
const RECV_MS = 1700;
const PENCIL_MS = 2500;
const CYCLE_ON_PROGRESS = 2500;
const CYCLE_ON_SPAWNING = 2000;

export class MoMoOverlays {
  private overlayAt: number = 0;
  private recvTick: number = -1;
  private recvDir: number = -0.7;
  private ink: number[][] = [];
  private osc: number = 0;

  reset(stateAt: number): void {
    this.overlayAt = stateAt;
    this.ink = [];
    this.recvTick = -1;
    this.recvDir = -0.7;
  }

  clear(): void {
    this.ink = [];
  }

  private amount(name: string, cur: string, prev: string, yl: number, mix: number): number {
    if (name === cur) {
      return yl * mix;
    }
    if (name === prev) {
      return yl * (1 - mix);
    }
    return 0;
  }

  // 思考点脉冲（Web dotsPulse：slot 0/2 双点）
  private dotsPulse(now: number, slot: number, yl: number): number[] {
    const Dt = (((((now - this.overlayAt) / 1400 + 0.119) % 1) + 1) % 1);
    let Mt = Math.abs(Dt - slot / 3);
    Mt = Math.min(Mt, 1 - Mt);
    const Lt = Math.exp(-(Mt * Mt) / (2 * 0.15 * 0.15));
    const lift = Lt * 9 * yl;
    const pop = POP0 + POP1 * Lt;
    const tone = 1 - 0.5 * (1 - Lt);
    return [lift, pop, tone];
  }

  extras(now: number, stateAt: number, cur: string, prev: string, yl: number, mix: number): FxExtras {
    const ex = new FxExtras();
    const kl = (name: string): number => this.amount(name, cur, prev, yl, mix);
    const pencil = kl('pencil');
    if (pencil > 0.004) {
      const p = this.pencilPose(now, stateAt);
      ex.yre += p[0] * pencil;
      ex.aX += (p[1] + p[2] * 0.5) * pencil;
      ex.wl += p[3] * pencil;
    }
    const bang = kl('bang');
    if (bang > 0.004) {
      ex.aX += 58 * bang;
    }
    const whirl = kl('whirl');
    if (whirl > 0.004) {
      const t = now / 1000;
      ex.yre += (Math.sin(t * 0.9) * 2 + Math.sin(t * 1.7) * 0.8) * whirl;
      ex.aX += (Math.sin(t * 1.3) * 2.4 + Math.sin(t * 0.6) * 1.2) * whirl;
    }
    const ball = kl('ball');
    if (ball > 0.004) {
      const t = (now - stateAt) / 1000;
      const grav = 0.62;
      const amp = 52;
      const k = (8 * amp) / (grav * grav);
      const v0 = 40;
      const t0 = Math.sqrt((2 * v0) / k);
      let y: number;
      if (t < t0) {
        y = v0 - 0.5 * k * t * t;
      } else {
        const c = (((t - t0) / grav) % 1 + 1) % 1;
        y = 4 * amp * c * (1 - c);
      }
      ex.ballY = (40 - y) * ball;
    }
    const standby = kl('standby');
    if (standby > 0.004) {
      ex.fade = (0.28 + 0.2 * Math.sin(now * 0.0016)) * standby;
    }
    return ex;
  }

  // 铅笔姿态：返回 [x, y, wig, rot]
  private pencilPose(now: number, stateAt: number): number[] {
    const Pt = now - stateAt;
    const mt = ((((Pt / PENCIL_MS) % 1) + 1) % 1);
    if (mt < 0.68) {
      const Mt = mt / 0.68;
      const Lt = Mt * Mt * (3 - 2 * Mt);
      const yn = clamp(Mt / 0.08, 0, 1) * clamp((1 - Mt) / 0.08, 0, 1);
      return [-54 + 118 * Lt, 26, Math.sin(Mt * 24) * 3.2 * yn, 17 + Math.sin(Pt * 6e-4) * 1];
    }
    const Dt = K2((mt - 0.68) / 0.32);
    return [64 - 118 * Dt, 26 - 20 * Math.sin(Dt * Math.PI), 0,
      17 - 2 * Math.sin(Dt * Math.PI) + Math.sin(Pt * 6e-4) * 1];
  }

  // 曲线（笔迹）——生成二次贝塞尔段命令
  private trace(ctx: CanvasRenderingContext2D, pts: number[][], width: number, color: string): void {
    if (pts.length < 2) {
      return;
    }
    ctx.strokeStyle = color;
    ctx.lineWidth = width;
    ctx.lineCap = 'round';
    ctx.lineJoin = 'round';
    ctx.beginPath();
    ctx.moveTo(pts[0][0], pts[0][1]);
    for (let i = 1; i < pts.length; i++) {
      ctx.lineTo(pts[i][0], pts[i][1]);
    }
    ctx.stroke();
  }

  /**
   * 绘制 overlay。cur/prev：当前/前一 overlay kind；yl：overlay 弹簧；mix：切换混合。
   */
  paint(ctx: CanvasRenderingContext2D, now: number, stateAt: number,
    cur: string, prev: string, yl: number, mix: number, ovSpin: number): void {
    this.overlayAt = stateAt;
    this.osc = now;
    const kl = (name: string): number => this.amount(name, cur, prev, yl, mix);
    const a = kl('dots');
    if (a > 0.004) {
      this.paintDots(ctx, a, now);
    }
    const b = kl('orbit');
    if (b > 0.004) {
      this.paintOrbit(ctx, b, now);
    }
    const c = kl('radar');
    if (c > 0.004) {
      this.paintRadar(ctx, c, now);
    }
    const d = kl('progress');
    if (d > 0.004) {
      this.paintProgress(ctx, d, now);
    }
    const e = kl('gather');
    if (e > 0.004) {
      this.paintGather(ctx, e, now);
    }
    const f = kl('wave');
    if (f > 0.004) {
      this.paintWave(ctx, f, now);
    }
    const g = kl('send');
    if (g > 0.004) {
      this.paintSend(ctx, g, now, stateAt);
    }
    const h = kl('receive');
    if (h > 0.004) {
      this.paintRecv(ctx, h, now, stateAt);
    }
    const i = kl('dock');
    if (i > 0.004) {
      this.paintDock(ctx, i, now, stateAt);
    }
    const j = kl('pencil');
    if (j > 0.004) {
      this.paintPencil(ctx, j, now, stateAt);
    }
    const k = kl('bang');
    if (k > 0.004) {
      this.paintBang(ctx, k, now, stateAt);
    }
    const l = kl('standby');
    if (l > 0.004) {
      this.paintStandby(ctx, l, now);
    }
    const m = kl('whirl');
    if (m > 0.004) {
      this.paintWhirl(ctx, m, now, ovSpin);
    }
  }

  private paintDots(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    for (let i = 0; i < 2; i++) {
      const Lt = clamp((a - i * 0.12) / (1 - i * 0.12), 0, 1);
      if (Lt <= 0.004) {
        continue;
      }
      const yn = Rc(Lt);
      const an = y1e(Lt);
      const pulse = this.dotsPulse(now, i === 0 ? 0 : 2, a);
      const pop = pulse[1];
      const tone = pulse[2];
      const x = R + ((i === 0 ? R - DOT_GAP : R + DOT_GAP) - R) * an;
      const y = R - pulse[0];
      const r = DOT_R * yn * pop;
      ctx.fillStyle = MOMO_INK.think;
      ctx.globalAlpha = Math.max(0, Math.min(1, yn * tone));
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
      ctx.globalAlpha = 1;
    }
  }

  private paintOrbit(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    const mt = Rc(a);
    const Mt = 52 * y1e(a);
    const Lt = 12;
    const yn = now * 0.0017;
    for (let i = 0; i < 5; i++) {
      const En = yn + (i * Math.PI * 2) / 5;
      const Zt = Math.cos(En);
      const dn = 0.5 + 0.5 * clamp(Zt, 0, 1);
      const x = R + Mt * Math.sin(En);
      const y = R - Mt * 0.42 * Math.cos(En);
      const r = Math.max(Lt * dn * mt, 0.3);
      ctx.fillStyle = MOMO_INK.dot;
      ctx.globalAlpha = Math.max(0, Math.min(1, clamp((Zt + 0.4) / 0.6, 0.18, 1) * mt));
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  private paintRadar(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    const Dt = Rc(a);
    for (let y = 0; y < 3; y++) {
      const Et = (((now / 1300 + y / 3) % 1) + 1) % 1;
      const r = 64 + (104 - 64) * Et;
      ctx.strokeStyle = MOMO_INK.dot;
      ctx.lineWidth = 3.4 * (1 - Et * 0.55);
      ctx.globalAlpha = Math.max(0, Math.min(1, Dt * (1 - Et) * 0.9));
      ctx.beginPath();
      ctx.arc(R, R, r, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  private paintProgress(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    const mt = Rc(a);
    const Dt = y1e(a);
    const Mt = 62;
    const Lt = clamp((now - this.overlayAt) / CYCLE_ON_PROGRESS, 0, 1);
    const yn = clamp(Lt / 0.85, 0, 1);
    // 底环
    ctx.strokeStyle = MOMO_INK.dot;
    ctx.lineWidth = 5;
    ctx.globalAlpha = Math.max(0, Math.min(1, mt * 0.16));
    ctx.beginPath();
    ctx.arc(R, R, Mt * Dt, 0, Math.PI * 2);
    ctx.stroke();
    // 进度弧（从 -90° 起）
    ctx.globalAlpha = Math.max(0, Math.min(1, mt));
    ctx.beginPath();
    ctx.arc(R, R, Mt * Dt, -Math.PI / 2, -Math.PI / 2 + yn * Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;
  }

  private paintGather(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    const mt = Rc(a);
    const Dt = CYCLE_ON_SPAWNING;
    for (let i = 0; i < 5; i++) {
      const yn = clamp(((now - this.overlayAt) / Dt - i * 0.09) / 0.62, 0, 1);
      if (yn >= 1) {
        continue;
      }
      const an = 1 - Math.pow(1 - yn, 3);
      const Et = i * 2.4 + yn * 2.2;
      const En = 96 * (1 - an);
      const x = R + En * Math.cos(Et);
      const y = R + En * Math.sin(Et) * 0.8;
      const r = 9 * (0.5 + 0.5 * an) * mt;
      ctx.fillStyle = MOMO_INK.dot;
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * clamp(yn * 5, 0, 1) * (1 - an * 0.25)));
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  private paintWave(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    const mt = [-2, -1, 1, 2];
    for (let i = 0; i < 4; i++) {
      const yn = mt[i];
      const an = clamp((a - Math.abs(yn) * 0.1) / (1 - Math.abs(yn) * 0.1), 0, 1);
      if (an <= 0.004) {
        continue;
      }
      const Et = y1e(an);
      const waveAmt = 0.42 + 0.29 * Math.sin(now * 0.0021) * Math.sin(now * 0.0034) + 0.29 * Math.sin(now * 0.0013 + 1.7);
      const En = waveAmt * (0.55 + 0.45 * Math.sin(now * 0.012 - Math.abs(yn) * 1.05));
      const r = Math.max(7 + 9 * clamp(En, 0.08, 1) * Rc(an), 0.5);
      const dn = 6 * clamp(En, 0, 1) * an;
      const x = R + yn * 44 * Et;
      const y = R - dn;
      ctx.fillStyle = MOMO_INK.think;
      ctx.globalAlpha = Math.max(0, Math.min(1, an));
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  private paintSend(ctx: CanvasRenderingContext2D, a: number, now: number, stateAt: number): void {
    const mt = Rc(a);
    const Dt = (((((now - stateAt) / SEND_MS) % 1) + 1) % 1);
    const Mt = clamp((Dt - 0.18) / 0.55, 0, 1);
    const Lt = Mt * Mt * (0.4 + 0.6 * Mt);
    const yn = 0.74;
    const an = -0.62;
    if (Mt > 0 && Mt < 1) {
      const x = R + yn * 108 * Lt;
      const y = R + an * 108 * Lt;
      ctx.fillStyle = MOMO_INK.eye;
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * (1 - Lt * Lt)));
      ctx.beginPath();
      ctx.arc(x, y, 10 * (1 - Lt * 0.55) * mt, 0, Math.PI * 2);
      ctx.fill();
    }
    const on2 = clamp((Dt - 0.26) / 0.55, 0, 1);
    const bn = on2 * on2 * (0.4 + 0.6 * on2);
    if (Mt > 0 && on2 > 0 && on2 < 1) {
      const x = R + yn * 108 * bn;
      const y = R + an * 108 * bn;
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * 0.3 * (1 - bn)));
      ctx.beginPath();
      ctx.arc(x, y, 5 * (1 - bn * 0.6) * mt, 0, Math.PI * 2);
      ctx.fill();
    }
    // 扩散环
    const on3 = clamp((Dt - 0.18) / 0.3, 0, 1);
    if (on3 > 0 && on3 < 1) {
      ctx.strokeStyle = MOMO_INK.eye;
      ctx.lineWidth = 2.8 * (1 - on3);
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * (1 - on3) * 0.8));
      ctx.beginPath();
      ctx.arc(R, R, 20 + 34 * Rc(on3), 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  private paintRecv(ctx: CanvasRenderingContext2D, a: number, now: number, stateAt: number): void {
    const mt = Rc(a);
    const Dt = now - stateAt;
    const Mt = Math.floor(Dt / RECV_MS);
    if (Mt !== this.recvTick) {
      this.recvTick = Mt;
      this.recvDir = -Math.PI * 1.25 + Math.random() * (Math.PI * 1.5);
    }
    const Lt = ((((Dt / RECV_MS) % 1) + 1) % 1);
    const yn = clamp(Lt / 0.6, 0, 1);
    const an = 1 - Math.pow(1 - yn, 3);
    if (yn < 1) {
      const Et = Math.cos(this.recvDir);
      const En = Math.sin(this.recvDir);
      const Zt = 108 * (1 - an);
      const Cn = 18 * Math.sin(yn * Math.PI) * (1 - an * 0.7);
      const x = R + Et * Zt + -En * Cn;
      const y = R + En * Zt + Et * Cn;
      ctx.fillStyle = MOMO_INK.eye;
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * clamp(yn * 3.5, 0, 1) * (0.3 + 0.7 * an)));
      ctx.beginPath();
      ctx.arc(x, y, 3.5 + 6.5 * an, 0, Math.PI * 2);
      ctx.fill();
    }
    const bn2 = clamp((Lt - 0.58) / 0.32, 0, 1);
    if (bn2 > 0 && bn2 < 1) {
      ctx.strokeStyle = MOMO_INK.eye;
      ctx.lineWidth = 2.8 * (1 - bn2);
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * (1 - bn2) * 0.8));
      ctx.beginPath();
      ctx.arc(R, R, 20 + 26 * Rc(bn2), 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  private paintDock(ctx: CanvasRenderingContext2D, a: number, now: number, stateAt: number): void {
    const mt = Rc(a);
    const Dt = (now - stateAt) / 1000;
    const Mt = 42;
    const Lt = 1.1;
    for (let y = 0; y < 2; y++) {
      const Et = clamp((Dt - (0.2 + y * 1.3)) / 0.9, 0, 1);
      if (Et <= 0) {
        continue;
      }
      const En = 1 - Math.pow(1 - Et, 3);
      const Zt = now * 0.001 * Lt + y * Math.PI;
      const dx = R + Mt * Math.sin(Zt);
      const dy = R + Mt * 0.5 * Math.cos(Zt) + Math.sin(now * 0.003 + y) * 2;
      const bx = R - 120 + y * 30;
      const by = R + 95;
      const x = bx + (dx - bx) * En;
      const yv = by + (dy - by) * En;
      ctx.fillStyle = MOMO_INK.dot;
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * clamp(Et * 4, 0, 1)));
      ctx.beginPath();
      ctx.arc(x, yv, (7 + 3 * En) * mt, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }

  private paintPencil(ctx: CanvasRenderingContext2D, a: number, now: number, stateAt: number): void {
    const p = this.pencilPose(now, stateAt);
    const yl = clamp(a, 0, 1);
    const rot = (p[3] - 14) * Math.PI / 180;
    const len = 26;
    const px = R + p[0];
    const py = R + p[1] + p[2] * 0.15;
    ctx.save();
    ctx.translate(px, py - 8);
    ctx.rotate(rot);
    // 铅笔杆 + 笔尖
    ctx.fillStyle = MOMO_INK.eye;
    ctx.globalAlpha = Math.max(0, Math.min(1, clamp(a * 1.6 - 0.3, 0, 1)));
    ctx.beginPath();
    ctx.rect(-3, -len / 2, 6, len - 5);
    ctx.fill();
    ctx.beginPath();
    ctx.moveTo(-3, len / 2 - 5);
    ctx.lineTo(0, len / 2 + 3);
    ctx.lineTo(3, len / 2 - 5);
    ctx.closePath();
    ctx.fill();
    ctx.restore();
    // 笔迹
    if (a > 0.6 && p[2] === 0 && p[1] < 40) {
      const x = R + p[0];
      const yv = R + p[1] + 19;
      const len2 = this.ink.length;
      if (len2 === 0 || Math.hypot(x - this.ink[len2 - 1][0], yv - this.ink[len2 - 1][1]) > 2.4) {
        this.ink.push([x, yv]);
        if (this.ink.length > 48) {
          this.ink.splice(0, 2);
        }
      }
    } else if (this.ink.length) {
      this.ink.splice(0, 2);
    }
    this.trace(ctx, this.ink, 6, MOMO_INK.eye);
    ctx.globalAlpha = 1;
  }

  private paintBang(ctx: CanvasRenderingContext2D, a: number, now: number, stateAt: number): void {
    const Dt = (now - stateAt) / 1000;
    const Mt = Rc(clamp(a * 1.1, 0, 1));
    const Lt = Math.exp(-(((Dt % 2.2) + 2.2) % 2.2) * 5.5);
    const yn = Math.sin(Dt * 42) * 2.2 * Lt;
    const ox = R;
    const oy = R - 74 - (1 - Mt) * 70;
    ctx.save();
    ctx.translate(ox, oy);
    ctx.rotate(yn * Math.PI / 180);
    ctx.fillStyle = MOMO_INK.eye;
    ctx.globalAlpha = Math.max(0, Math.min(1, clamp(a * 1.5 - 0.2, 0, 1)));
    // 感叹号：竖条 + 点
    ctx.beginPath();
    ctx.rect(-2.6, -16, 5.2, 20);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(0, 16, 3.4, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    ctx.globalAlpha = 1;
  }

  private paintStandby(ctx: CanvasRenderingContext2D, a: number, now: number): void {
    const mt = Rc(a);
    const Lt = 0.5 + 0.5 * Math.sin(now * 0.0016);
    ctx.fillStyle = MOMO_INK.eye;
    ctx.globalAlpha = Math.max(0, Math.min(1, mt * (0.06 + 0.1 * Lt)));
    ctx.beginPath();
    ctx.arc(R, R, 26 + 7 * Lt, 0, Math.PI * 2);
    ctx.fill();
    ctx.globalAlpha = 1;
    if (a < 0.995) {
      ctx.strokeStyle = MOMO_INK.eye;
      ctx.lineWidth = 2.4;
      ctx.globalAlpha = Math.max(0, Math.min(1, (1 - a) * 0.5));
      ctx.beginPath();
      ctx.arc(R, R, 104 - 88 * a, 0, Math.PI * 2);
      ctx.stroke();
    }
    ctx.globalAlpha = 1;
  }

  private paintWhirl(ctx: CanvasRenderingContext2D, a: number, now: number, ovSpin: number): void {
    const mt = Rc(a);
    for (let i = 0; i < 6; i++) {
      const ang = ovSpin * 0.85 + (i * Math.PI * 2) / 6;
      const x = R + 78 * Math.sin(ang);
      const y = R - 52 * Math.cos(ang);
      const s = 0.55 + 0.45 * clamp((Math.cos(ang) + 1) / 2, 0, 1);
      ctx.fillStyle = MOMO_INK.dot;
      ctx.globalAlpha = Math.max(0, Math.min(1, mt * (0.35 + 0.65 * s)));
      ctx.beginPath();
      ctx.arc(x, y, 7.5 * s * mt + 0.5, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.globalAlpha = 1;
  }
}
