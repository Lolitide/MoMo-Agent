/*
 * ============================================================================
 * 文件名：components/momo/MoMoMotionMath.ets
 * ============================================================================
 * 【用途】弹簧驱动软体角色引擎的数学层：半隐式欧拉弹簧积分（与
 *   Web 项目 grok-icon-study-web 的 replica/src/math.js 同源算法，MIT），
 *   缓动、多边形插值、闭合样条采样、环形跨度。
 * 【前置条件 / 假设】
 *   - 纯函数/纯类：无 UI 依赖，不持有组件引用；
 *   - 假设：世界坐标系为 0..200 逻辑单位，身体中心 R=100；
 *   - 移植差异：不实现 SVG path 展平/3D 旋转（solidRadii/rot3），
 *     身体用固定 32 点极坐标 ring 表示，姿态为 2D（rotate + scale）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：frame dt（秒）；输出：弹簧状态推进、坐标数组生成。
 * 【关键类 / 算法】
 *   - Spring.step(freq, damp, dt)：半隐式欧拉，子步 DT=1/120 由调用方拆分；
 *   - closedSplineSegs：为闭合 ring 生成 Catmull-Rom 三次贝塞尔控制点串；
 *   - spanHalf：多边形在给定 y 处的左右跨度（眼睛夹持宽度）。
 * 【参考源】
 *   - grok-icon-study-web/replica/src/math.js（MIT）：stepSpring/K2/Dke/lerpPoly/spanPoly
 * ============================================================================
 */

// 归一化视窗：中心 (100,100)，逻辑尺寸 200x200。
export const MOMO_VIEW: number = 200;
export const MOMO_R: number = 100;

export class Spring {
  x: number;
  v: number;
  t: number;

  constructor(x: number = 0) {
    this.x = x;
    this.v = 0;
    this.t = x;
  }

  step(freq: number, damp: number, dt: number): void {
    this.v += (-2 * damp * freq * this.v - freq * freq * (this.x - this.t)) * dt;
    this.x += this.v * dt;
    if (!Number.isFinite(this.x) || !Number.isFinite(this.v)) {
      this.x = this.t;
      this.v = 0;
    }
  }

  snap(v: number): void {
    this.x = v;
    this.t = v;
    this.v = 0;
  }
}

export function springBusy(s: Spring): boolean {
  return Math.abs(s.x - s.t) > 0.002 || Math.abs(s.v) > 0.04;
}

export function clamp(n: number, a: number, b: number): number {
  return Math.min(b, Math.max(a, n));
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function rand(a: number, b: number): number {
  return a + Math.random() * (b - a);
}

export function sign(): number {
  return Math.random() < 0.5 ? -1 : 1;
}

// easeInOutCubic
export function K2(n: number): number {
  return n < 0.5 ? 4 * n * n * n : 1 - Math.pow(-2 * n + 2, 3) / 2;
}

// 平滑插值（smoothstep）
export function Dke(n: number): number {
  return n * n * (3 - 2 * n);
}

export function Rc(n: number): number {
  return 1 - Math.pow(1 - n, 3);
}

// easeOutBack
export function y1e(n: number): number {
  return 1 + 2.70158 * Math.pow(n - 1, 3) + 1.70158 * Math.pow(n - 1, 2);
}

// 指数接近（默认 bs=1/60，同 Web Rn）
export function Rn(n: number, bs: number = 1 / 60): number {
  return 1 - Math.exp(Math.log(1 - n) * 60 * bs);
}

export function angLerp(from: number, to: number, t: number): number {
  let d = to - from;
  while (d > 180) {
    d -= 360;
  }
  while (d < -180) {
    d += 360;
  }
  return from + d * t;
}

// 多边形逐点插值（要求 a/b 同点数，Web lerpPoly）
export function lerpPoly(a: number[][], b: number[][], t: number): number[][] {
  const out: number[][] = [];
  for (let i = 0; i < a.length; i++) {
    out.push([a[i][0] + (b[i][0] - a[i][0]) * t, a[i][1] + (b[i][1] - a[i][1]) * t]);
  }
  return out;
}

export function polyCentroid(p: number[][]): number[] {
  let x = 0;
  let y = 0;
  for (let i = 0; i < p.length; i++) {
    x += p[i][0];
    y += p[i][1];
  }
  return [x / p.length, y / p.length];
}

// 多边形相对中心的半宽（左右眼布置用）
export function polyMaxHalfW(p: number[][], c: number[]): number {
  let w = 0;
  for (let i = 0; i < p.length; i++) {
    w = Math.max(w, Math.abs(p[i][0] - c[0]));
  }
  return w;
}

/**
 * 闭合 Catmull-Rom 样条转三次贝塞尔段。
 * 与 Web fx.js closedSpline 公式一致，输出 [c1x,c1y,c2x,c2y,ex,ey] 段数组（含闭段）。
 */
export function closedSplineSegs(pts: number[][]): number[][] {
  const n = pts.length;
  const segs: number[][] = [];
  for (let s = 0; s < n; s++) {
    const prev = pts[(s - 1 + n) % n];
    const cur = pts[s];
    const next = pts[(s + 1) % n];
    const next2 = pts[(s + 2) % n];
    const c1x = cur[0] + (next[0] - prev[0]) / 6;
    const c1y = cur[1] + (next[1] - prev[1]) / 6;
    const c2x = next[0] - (next2[0] - cur[0]) / 6;
    const c2y = next[1] - (next2[1] - cur[1]) / 6;
    segs.push([c1x, c1y, c2x, c2y, next[0], next[1]]);
  }
  return segs;
}

/**
 * 多边形在 y 高度处的左右跨度（相对中心 R）。
 * 返回 [left, right]（x 坐标）；无交点时返回 [R, R]。
 */
export function spanHalf(ring: number[][], y: number, R: number): number[] {
  let left = -Infinity;
  let right = Infinity;
  const n = ring.length;
  for (let i = 0; i < n; i++) {
    const a = ring[i];
    const b = ring[(i + 1) % n];
    if ((a[1] <= y) === (b[1] <= y)) {
      continue;
    }
    const x = a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]);
    if (x <= R) {
      if (x > left) {
        left = x;
      }
    } else if (x < right) {
      right = x;
    }
  }
  const l = Number.isFinite(left) ? left : R;
  const rr = Number.isFinite(right) ? right : R;
  return [l, rr];
}

/**
 * 由 32 点半径表生成世界坐标 ring（0..200 世界系，中心 (R,R)）。
 * 角度从正上方开始顺时针。radii 长度必须为 32。
 */
export function ringFromRadii(radii: number[], R: number): number[][] {
  const n = radii.length;
  const ring: number[][] = [];
  for (let i = 0; i < n; i++) {
    const ang = -Math.PI / 2 + (i / n) * Math.PI * 2;
    ring.push([R + Math.cos(ang) * radii[i], R + Math.sin(ang) * radii[i]]);
  }
  return ring;
}
