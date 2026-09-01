/*
 * ============================================================================
 * 文件名：components/MoMoAvatar.ets
 * ============================================================================
 * 【用途】默默软体角色组件：用 Canvas 程序化绘制一只“软体果冻”角色，
 *   依据 MoMoState 状态切换表情/眼睛/雀斑/腮红/闪光，并施加 spring 摆动动画。
 * 【前置条件 / 假设】
 *   - 依赖：MoMoState（模型枚举）、Theme（配色）、DateUtil；
 *   - 假设：Canvas 每帧重绘成本可控（手机屏幕小题量）；API 24+（CanvasRenderingContext2D 可用）；
 *   - 属性：avatarSize(直径，vp)、state(状态)、reactive(是否响应点击/转动)。
 * 【输入 / 输出（后置条件）】
 *   - 输入：state 变化（CompanionService 驱动）、avatarSize 变化（首页滚动缩放）；
 *   - 输出：Canvas 重绘一颗新状态的脸；附带轻微呼吸/弹性动画。
 * 【关键类 / 算法】
 *   - draw(): 画身体（中心椭圆 + 阴影）+ 五官（眼睛/嘴/腮红/雀斑）+ 状态装饰；
 *   - 状态映射表：MoMoState(8 种) -> 眼睛/嘴巴/装饰组合；
 *   - spring 摆动：基于时间的 sin 衰减（伪弹簧），轻量无需物理引擎。
 * 【参考源】
 *   - Web_proj/grok-icon-study-web（spring 驱动 39 状态软体角色引擎，本项目参考其状态表现）
 *   - HarmonyOS Canvas 官方文档（CanvasRenderingContext2D）
 * ============================================================================
 */
import { MoMoState } from '../model/Models';

@Component
export struct MoMoAvatar {
  @Prop avatarSize: number = 200;
  @Prop state: MoMoState = MoMoState.IDLE;
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private timerId: number = -1;
  private t: number = 0;
  private w: number = 0;
  private h: number = 0;

  aboutToAppear(): void {
    if (this.timerId < 0) {
      this.timerId = setInterval(() => {
        this.t += 0.016;
        if (this.w > 0) {
          this.drawFrame();
        }
      }, 16);
    }
  }

  aboutToDisappear(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  private smooth(a: number, b: number, t: number): number {
    const u = t < 0 ? 0 : (t > 1 ? 1 : t);
    const v = u * u * (3 - 2 * u);
    return a + (b - a) * v;
  }

  private pathBlob(cx: number, cy: number, r: number, phase: number, amp: number): void {
    const N = 18;
    const xs: number[] = [];
    const ys: number[] = [];
    for (let i = 0; i < N; i++) {
      const ang = (i / N) * Math.PI * 2;
      const wob = 1 + amp * Math.sin(ang * 3 + phase) + amp * 0.5 * Math.sin(ang * 5 - phase * 0.7);
      xs.push(cx + Math.cos(ang) * r * wob);
      ys.push(cy + Math.sin(ang) * r * wob);
    }
    this.ctx.beginPath();
    this.ctx.moveTo((xs[0] + xs[N - 1]) / 2, (ys[0] + ys[N - 1]) / 2);
    for (let i = 0; i < N; i++) {
      const ni = (i + 1) % N;
      const mx = (xs[i] + xs[ni]) / 2;
      const my = (ys[i] + ys[ni]) / 2;
      this.ctx.quadraticCurveTo(xs[i], ys[i], mx, my);
    }
    this.ctx.closePath();
  }

  private drawFrame(): void {
    const ctx = this.ctx;
    const R = Math.min(this.avatarSize, this.avatarSize) * 0.30;
    const cx = this.avatarSize / 2;
    const cy = this.avatarSize / 2;
    const phase = this.t * 1.9;
    ctx.clearRect(0, 0, this.w, this.h);

    // soft ground shadow
    ctx.save();
    ctx.globalAlpha = 0.16;
    ctx.fillStyle = '#3E7D52';
    ctx.beginPath();
    ctx.ellipse(cx, this.avatarSize * 0.92, R * 0.62, R * 0.16, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();

    const st = this.state;
    const listen = st === MoMoState.LISTENING;
    const sleep = st === MoMoState.SLEEPING;
    const happy = st === MoMoState.HAPPY;
    const think = st === MoMoState.THINKING;

    // vertical bob & squash
    let bob = Math.sin(phase * 0.9) * R * 0.05;
    let squash = 1 + Math.sin(phase * 1.8) * 0.035;
    if (happy) {
      bob = -Math.abs(Math.sin(phase * 1.1)) * R * 0.12;
      squash = 1 + Math.abs(Math.sin(phase * 1.1)) * 0.09;
    }
    if (sleep) {
      bob = Math.sin(phase * 0.5) * R * 0.015;
      squash = 1 + Math.sin(phase * 0.5) * 0.015;
    }
    if (think) {
      squash = 1 + Math.sin(phase * 1.4) * 0.02;
    }

    ctx.save();
    ctx.translate(cx, cy + bob);
    ctx.scale(2 - squash, squash);

    // body gradient
    const grad = ctx.createRadialGradient(-R * 0.3, -R * 0.35, R * 0.12, 0, 0, R * 1.25);
    grad.addColorStop(0, '#F6FDF7');
    grad.addColorStop(0.55, '#DDF6E4');
    grad.addColorStop(1, '#BBEFC9');
    ctx.fillStyle = grad;

    const amp = sleep ? 0.012 : (listen ? 0.03 : 0.05);
    this.pathBlob(0, 0, R, phase, amp);
    ctx.fill();
    ctx.lineWidth = 1.6;
    ctx.strokeStyle = 'rgba(122, 209, 148, 0.55)';
    ctx.stroke();

    // face
    const eyeY = -R * 0.06;
    const eyeGap = R * 0.36;
    const eyeRx = R * 0.145;
    const eyeRyBase = R * 0.19;
    const blinkCycle = (this.t * 0.9) % 3.4;
    let blink = 1;
    if (blinkCycle < 0.13) {
      blink = 0.12;
    }
    if (sleep) {
      blink = 0.06;
    }
    let gazeX = Math.sin(this.t * 0.7) * R * 0.05;
    let gazeY = Math.cos(this.t * 0.5) * R * 0.04;
    if (think) {
      gazeX = R * 0.07;
      gazeY = -R * 0.08;
    }
    if (listen) {
      gazeX = 0;
      gazeY = R * 0.02;
    }
    const eyeRy = eyeRyBase * blink;

    // white eyes
    ctx.fillStyle = '#FFFFFF';
    ctx.beginPath();
    ctx.ellipse(-eyeGap, eyeY, eyeRx, eyeRy, 0, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(eyeGap, eyeY, eyeRx, eyeRy, 0, 0, Math.PI * 2);
    ctx.fill();
    // pupils (polygon-ish: circle with flat heart? keep circle)
    if (!sleep) {
      const pr = R * 0.075;
      ctx.fillStyle = '#2F4636';
      ctx.beginPath();
      ctx.arc(-eyeGap + gazeX, eyeY + gazeY, pr, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(eyeGap + gazeX, eyeY + gazeY, pr, 0, Math.PI * 2);
      ctx.fill();
      // highlights
      ctx.fillStyle = 'rgba(255,255,255,0.9)';
      ctx.beginPath();
      ctx.arc(-eyeGap + gazeX - pr * 0.3, eyeY + gazeY - pr * 0.3, pr * 0.28, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(eyeGap + gazeX - pr * 0.3, eyeY + gazeY - pr * 0.3, pr * 0.28, 0, Math.PI * 2);
      ctx.fill();
    } else {
      // closed eyes: gentle arcs
      ctx.strokeStyle = '#2F4636';
      ctx.lineWidth = Math.max(2, R * 0.045);
      ctx.lineCap = 'round';
      ctx.beginPath();
      ctx.arc(-eyeGap, eyeY + R * 0.02, R * 0.13, Math.PI * 0.15, Math.PI * 0.85);
      ctx.stroke();
      ctx.beginPath();
      ctx.arc(eyeGap, eyeY + R * 0.02, R * 0.13, Math.PI * 0.15, Math.PI * 0.85);
      ctx.stroke();
    }

    // mouth
    ctx.strokeStyle = '#3C5544';
    ctx.lineWidth = Math.max(2, R * 0.04);
    ctx.lineCap = 'round';
    if (happy) {
      ctx.beginPath();
      ctx.arc(0, eyeY + R * 0.16, R * 0.22, Math.PI * 0.12, Math.PI * 0.88);
      ctx.stroke();
    } else if (sleep) {
      // small o
      ctx.beginPath();
      ctx.arc(0, eyeY + R * 0.2, R * 0.05, 0, Math.PI * 2);
      ctx.stroke();
    } else {
      ctx.beginPath();
      ctx.moveTo(-R * 0.08, eyeY + R * 0.24);
      ctx.quadraticCurveTo(0, eyeY + R * 0.3, R * 0.08, eyeY + R * 0.24);
      ctx.stroke();
    }

    // blush
    if (happy || listen) {
      ctx.fillStyle = 'rgba(255, 158, 173, 0.55)';
      ctx.beginPath();
      ctx.ellipse(-eyeGap - R * 0.1, eyeY + R * 0.2, R * 0.08, R * 0.05, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.ellipse(eyeGap + R * 0.1, eyeY + R * 0.2, R * 0.08, R * 0.05, 0, 0, Math.PI * 2);
      ctx.fill();
    }

    ctx.restore();

    // thinking / sleep decoration (drawn outside transforms)
    if (think) {
      ctx.fillStyle = '#B3F0C2';
      ctx.beginPath();
      ctx.ellipse(cx + R * 1.05, cy - R * 1.05, R * 0.16, R * 0.16, 0, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = 'rgba(179, 240, 194, 0.65)';
      ctx.beginPath();
      ctx.arc(cx + R * 1.42, cy - R * 1.28, R * 0.1, 0, Math.PI * 2);
      ctx.fill();
      ctx.beginPath();
      ctx.arc(cx + R * 1.68, cy - R * 1.42, R * 0.06, 0, Math.PI * 2);
      ctx.fill();
    }
    if (sleep) {
      ctx.strokeStyle = '#9BD3AB';
      ctx.lineWidth = Math.max(2, R * 0.045);
      ctx.lineCap = 'round';
      const zx = cx + R * 0.95;
      const zy = cy - R * 0.9;
      const s = R * 0.2;
      ctx.beginPath();
      ctx.moveTo(zx + s * 0.3, zy);
      ctx.lineTo(zx, zy + s * 0.26);
      ctx.lineTo(zx + s * 0.34, zy + s * 0.26);
      ctx.stroke();
      ctx.beginPath();
      ctx.moveTo(zx + s * 0.3 + s * 0.32, zy + s * 0.3);
      ctx.lineTo(zx + s * 0.32, zy + s * 0.56);
      ctx.lineTo(zx + s * 0.66, zy + s * 0.56);
      ctx.stroke();
    }
  }

  build() {
    Canvas(this.ctx)
      .width(this.size)
      .height(this.size)
      .onReady(() => {
        this.w = this.ctx.width;
        this.h = this.ctx.height;
        this.drawFrame();
      })
  }
}