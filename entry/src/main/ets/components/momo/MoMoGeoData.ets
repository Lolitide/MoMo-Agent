/*
 * ============================================================================
 * 文件名：components/momo/MoMoGeoData.ets
 * ============================================================================
 * 【用途】弹簧驱动软体角色引擎的原创几何数据：8 个身体形态（32 点半径
 *   ring）、25 组多边形眼睛（局部坐标、morph 兼容）、绿系色板。
 * 【前置条件 / 假设】
 *   - 纯数据类，运行期一次性构建为静态常量；
 *   - 假设：世界系 0..200，身体中心 (100,100)；身体基准半径 60；
 *   - 所有眼睛多边形点数相同（10 点），保证 morph 逐点插值；
 *   - 【原创声明】本文件几何全部为 MoMo 项目自绘，不包含
 *     grok-icon-study-web 仓库刻意排除的商业几何（GROK_GEO）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：无；输出：MOMO_SHAPES/MOMO_EYES/MOMO_INK 常量。
 * 【关键类 / 算法】
 *   - eyeEllipse/eyeArc/eyePoly：以 10 点局部坐标生成眼型；
 *   - radiiFor：8 个形态的 32 点半径表（谐波/椭圆/棱角综合）。
 * 【参考源】
 *   - grok-icon-study-web 引擎的 index 约定（shapes/eyes 数据结构，
 *     MIT），几何本身为项目原创；配色沿用 MoMo Theme 绿系与现 MoMoAvatar。
 * ============================================================================
 */
import { ringFromRadii, spanHalf } from './MoMoMotionMath';

export class MoMoShape {
  name: string = '';
  ring: number[][] = [];
  faceX: number = 0;
  faceY: number = -4;
  faceSX: number = 1;
  faceSY: number = 1;
  faceEye: number = 1;
  top: number = 30;
  bottom: number = 170;
  radius: number = 60;
}

export class MoMoEyeGroup {
  left: number[][] = [];
  right: number[][] = [];
  // 椭圆参数化标记与半轴（'ellipse' 时原生 ctx.ellipse 绘制；其余用样条平滑）
  kind: string = 'poly';
  rx: number = 0;
  ry: number = 0;
}

// 眼点数（morph 兼容）
const EYE_N: number = 10;

// 椭圆眼（cx/cy 为 0,0 局部坐标）
function eyeEllipse(w: number, h: number): number[][] {
  const pts: number[][] = [];
  for (let i = 0; i < EYE_N; i++) {
    const a = (i / EYE_N) * Math.PI * 2;
    pts.push([Math.cos(a) * w / 2, Math.sin(a) * h / 2]);
  }
  return pts;
}

// 弓形眼：上下两条弧（bowTop/bowBot 为向外的弓高），恰好 10 点
function eyeArc(w: number, h: number, bowTop: number, bowBot: number): number[][] {
  const pts: number[][] = [];
  const hw = w / 2;
  for (let i = 0; i < 5; i++) {
    const t = i / 4;
    pts.push([-hw + w * t, -h / 2 - bowTop * Math.sin(t * Math.PI)]);
  }
  for (let i = 0; i < 5; i++) {
    const t = i / 4;
    pts.push([hw - w * t, h / 2 + bowBot * Math.sin(t * Math.PI)]);
  }
  return pts;
}

// 尖角（三角/折角眼）
function eyePoly(pts: number[][]): number[][] {
  const out: number[][] = [];
  for (let i = 0; i < EYE_N; i++) {
    const src = pts[i % pts.length];
    out.push([src[0], src[1]]);
  }
  return out;
}

function buildEyes(): MoMoEyeGroup[] {
  const list: MoMoEyeGroup[] = [];
  const add = (l: number[][], r?: number[][]): void => {
    const g = new MoMoEyeGroup();
    g.left = l;
    g.right = r ? r : l;
    list.push(g);
  };
  const addEllipse = (w: number, h: number): void => {
    const g = new MoMoEyeGroup();
    g.left = eyeEllipse(w, h);
    g.right = g.left;
    g.kind = 'ellipse';
    g.rx = w / 2;
    g.ry = h / 2;
    list.push(g);
  };
  // 0 圆睁（idle 主眼）
  addEllipse(15, 19);
  // 1 细高椭圆（listening）
  addEllipse(13, 21);
  // 2 弯月笑眼（happy）
  add(eyeArc(17, 9, 0.5, 5.5));
  // 3 小圆点（surprised/scared）
  addEllipse(12, 13);
  // 4 半闭椭圆（drowsy/sad）
  addEllipse(16, 12);
  // 5 斜长眯眼（suspicious 次型）
  add(eyePoly([[ -9, -2 ], [ -3, -8 ], [ 4, -6 ], [ 9, 0 ], [ 6, 5 ], [ 0, 4 ], [ -5, 5 ]]));
  // 6 竖长椭圆（working/think 次型）
  addEllipse(12, 22);
  // 7 愤怒下压三角（angry）
  add(eyePoly([[ -9, 4 ], [ -4, -8 ], [ 6, -2 ]]));
  // 8 上挑椭圆（thinking 主眼）
  addEllipse(14, 17);
  // 9 下拉半圆（searching 集中）
  add(eyePoly([[ -9, -3 ], [ -8, 3 ], [ -3, 7 ], [ 4, 7 ], [ 9, 2 ], [ 7, -4 ]]));
  // 10 圆点（listening 次型）
  addEllipse(13, 15);
  // 11 弯月笑眼窄（laughing）
  add(eyeArc(18, 7, 0.4, 5.0));
  // 12 下垂半闭（sad）
  add(eyePoly([[ -9, 1 ], [ -8, 5 ], [ -2, 7 ], [ 5, 6 ], [ 9, 2 ], [ 5, 0 ]]));
  // 13 闭眼线（sleeping）
  add(eyeArc(15, 2.4, 1.2, 1.2));
  // 14 左斜眯（suspicious 主眼）
  add(eyePoly([[ -9, -5 ], [ -2, -6 ], [ 5, -3 ], [ 9, 2 ], [ 4, 5 ], [ -2, 4 ]]));
  // 15 长椭（working/uploading）
  addEllipse(17, 14);
  // 16 上翻弧（angry 次型/proud）
  add(eyePoly([[ -9, -4 ], [ -3, -7 ], [ 5, -4 ], [ 9, 1 ], [ 4, 4 ], [ -4, 2 ]]));
  // 17 弯笑变体（excited）
  add(eyeArc(19, 8, 0.6, 6.0));
  // 18 下弧（searching 次型）
  add(eyePoly([[ -8, -1 ], [ -6, 4 ], [ 0, 6 ], [ 7, 4 ], [ 8, -2 ], [ 2, -3 ]]));
  // 19 上偏圆点（thinking/notify）
  addEllipse(13, 14);
  // 20 平长椭（bored）
  addEllipse(18, 11);
  // 21 大圆（surprised）
  addEllipse(17, 17);
  // 22 闭眼舒适线（sleeping 次型）
  add(eyeArc(16, 2, 0.6, 1.6));
  // 23 高弧眯（suspicious 次型）
  add(eyePoly([[ -8, -5 ], [ -1, -7 ], [ 6, -5 ], [ 9, 0 ], [ 5, 4 ], [ -3, 3 ]]));
  // 24 下垂弓（shy 垂目）
  add(eyePoly([[ -9, 0 ], [ -8, 5 ], [ -2, 9 ], [ 5, 9 ], [ 9, 5 ], [ 6, 1 ]]));
  return list;
}

// 8 个形态的 32 点半径（相对中心）：
// blob: 谐波软体；pebble: 横椭；squircle: 微方；tablet: 宽胶囊；
// wedge: 左上饱满右下收；hex: 六边感；cloud: 多瓣；teardrop: 上圆下尖。
function radiiFor(name: string): number[] {
  const out: number[] = [];
  const N = 32;
  for (let i = 0; i < N; i++) {
    const a = (i / N) * Math.PI * 2; // 0 = 正上方，顺时针
    const s = Math.sin(a);
    const c = Math.cos(a);
    let r = 60;
    if (name === 'blob') {
      r = 60 + 3.2 * Math.sin(3 * a + 0.4) + 1.6 * Math.sin(5 * a - 0.8);
    } else if (name === 'pebble') {
      r = 60 * (1 + 0.13 * c * c - 0.06 * s * s); // 略横
    } else if (name === 'squircle') {
      r = 60 * (1 + 0.05 * Math.cos(4 * a));
    } else if (name === 'tablet') {
      r = 60 * (1 + 0.2 * c * c - 0.1 * s * s); // 宽胶囊
    } else if (name === 'wedge') {
      r = 60 * (1 + 0.15 * c - 0.08 * s);
    } else if (name === 'hex') {
      r = 60 * (1 + 0.085 * Math.cos(6 * a));
    } else if (name === 'cloud') {
      r = 60 * (1 + 0.07 * Math.cos(3 * a + 1.2) + 0.05 * Math.cos(5 * a));
    } else if (name === 'teardrop') {
      const drop = Math.max(0, s); // 下方
      r = 60 * (1 - 0.16 * Math.pow(drop, 1.4));
    }
    out.push(r);
  }
  return out;
}

function buildShapes(): MoMoShape[] {
  const names: string[] = ['blob', 'pebble', 'squircle', 'tablet', 'wedge', 'hex', 'cloud', 'teardrop'];
  const list: MoMoShape[] = [];
  for (const name of names) {
    const sh = new MoMoShape();
    sh.name = name;
    sh.ring = ringFromRadii(radiiFor(name), 100);
    sh.radius = 60;
    // 上下极值（眼睛夹持）
    let top = Infinity;
    let bottom = -Infinity;
    for (const p of sh.ring) {
      if (p[1] < top) {
        top = p[1];
      }
      if (p[1] > bottom) {
        bottom = p[1];
      }
    }
    sh.top = top;
    sh.bottom = bottom;
    if (name === 'tablet') {
      sh.faceSX = 1.14;
    } else if (name === 'pebble') {
      sh.faceSX = 1.08;
    } else if (name === 'teardrop') {
      sh.faceY = -8;
    } else if (name === 'squircle') {
      sh.faceEye = 0.95;
    }
    list.push(sh);
  }
  return list;
}

// 绿系色板（沿用 Theme 品牌色与现 MoMoAvatar 质感）
export class MoMoInk {
  bodyFrom: string = '#F6FDF7';
  bodyMid: string = '#DDF6E4';
  bodyTo: string = '#BBEFC9';
  stroke: string = 'rgba(122, 209, 148, 0.55)';
  eye: string = '#2F4636';
  eyeWhite: string = '#FFFFFF';
  eyeSoft: string = 'rgba(47, 70, 54, 0.82)';
  shadow: string = '#3E7D52';
  blush: string = 'rgba(255, 158, 173, 0.55)';
  think: string = '#B3F0C2';
  badge: string = '#F6B26B';
  spark: string = '#F4C34E';
  dot: string = '#5FBF7C';
}

export const MOMO_INK: MoMoInk = new MoMoInk();

export const MOMO_SHAPES: MoMoShape[] = buildShapes();

export const MOMO_EYES: MoMoEyeGroup[] = buildEyes();

export function shapeByName(name: string): MoMoShape {
  for (const s of MOMO_SHAPES) {
    if (s.name === name) {
      return s;
    }
  }
  return MOMO_SHAPES[0];
}

// 身体 ring 在 y 处的跨度（眼睛夹持）
export function ringSpanAt(ring: number[][], y: number): number[] {
  return spanHalf(ring, y, 100);
}

// 世界系身体中心
export const GEO_R: number = 100;
