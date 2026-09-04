/*
 * ============================================================================
 * 文件名：components/MoMoAvatar.ets
 * ============================================================================
 * 【用途】默默软体角色组件：以 spring 驱动的角色引擎（引擎移植自
 *   Web 项目 grok-icon-study-web 的 GrokCharacter，MIT 许可）驱动
 *   Canvas 绘制，实现 39 种状态行为 / 弹簧运动 / 多边形眼睛 morph /
 *   眨眼 / 视线 / wink / 自动 tricks / overlay 特效。
 * 【前置条件 / 假设】
 *   - 依赖：MoMoState（模型枚举）、momo/MoMoEngine（纯引擎类）、
 *     momo/MoMoGeoData（原创几何，非 Grok 商业数据）；
 *   - 假设：DisplaySync（@kit.ArkGraphics2D，API 11+）提供 60fps 帧回调；
 *     组件销毁/页面隐藏时停止帧同步，避免后台绘制；API 22+；
 *   - 属性：avatarSize(直径 vp)、state(状态)、interactive(是否响应触摸)。
 * 【输入 / 输出（后置条件）】
 *   - 输入：state 变化（CompanionService 驱动）、avatarSize 变化（首页滚动缩放）、
 *     interactive 时触摸（点击 spin / 长按 bounce / 拖移眼神跟随）；
 *   - 输出：Engine 驱动 Canvas 每帧重绘 spring 动画角色。
 * 【关键类 / 算法】
 *   - MoMoEngine.tick：状态机 + 弹簧积分 + 眼睛/眨眼/视线/tricks；
 *   - MoMoEngine.paint：世界系 0..200 -> sizePx 缩放绘制；
 *   - DisplaySync：帧对齐的驱动源（@ohos.graphics.displaySync，API 11+）。
 * 【参考源】
 *   - Web_proj/grok-icon-study-web（MIT）：引擎逻辑移植，几何为 MoMo 自绘；
 *     配色沿用 MoMo Theme 绿系与现 MoMoAvatar 质感。
 * ============================================================================
 */
import { displaySync } from '@kit.ArkGraphics2D';
import { MoMoState } from '../model/Models';
import { MoMoEngine, MoMoEngineOptions } from './momo/MoMoEngine';

@Component
export struct MoMoAvatar {
  @Prop avatarSize: number = 200;
  @Prop @Watch('onStateChange') state: MoMoState = MoMoState.IDLE;
  @Prop interactive: boolean = false;
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private engine: MoMoEngine | null = null;
  private ds: displaySync.DisplaySync | null = null;
  private lastNs: number = 0;
  private cvReady: boolean = false;

  private mapState(s: MoMoState): string {
    switch (s) {
      case MoMoState.CURIOUS:
        return 'curious';
      case MoMoState.HAPPY:
        return 'happy';
      case MoMoState.THINKING:
        return 'thinking';
      case MoMoState.LISTENING:
        return 'listening';
      case MoMoState.SLEEPING:
        return 'sleeping';
      default:
        return 'idle';
    }
  }

  onStateChange(propName: string): void {
    void propName;
    if (this.engine) {
      this.engine.setState(this.mapState(this.state), false);
    }
  }

  aboutToAppear(): void {
    if (!this.engine) {
      this.engine = new MoMoEngine(new MoMoEngineOptions());
      this.engine.setState(this.mapState(this.state), true);
    }
    this.lastNs = 0;
    if (!this.ds) {
      this.ds = displaySync.create();
      this.ds.setExpectedFrameRateRange({ min: 60, max: 120, expected: 60 });
      this.ds.on('frame', (info: displaySync.IntervalInfo) => {
        this.onFrame(info);
      });
      this.ds.start();
    }
  }

  aboutToDisappear(): void {
    if (this.ds) {
      this.ds.stop();
      this.ds.off('frame');
      this.ds = null;
    }
    this.cvReady = false;
  }

  private onFrame(info: displaySync.IntervalInfo): void {
    const ns = info.timestamp;
    if (this.lastNs <= 0) {
      this.lastNs = ns;
      return;
    }
    let dtMs = (ns - this.lastNs) / 1e6;
    this.lastNs = ns;
    if (!Number.isFinite(dtMs) || dtMs < 0 || dtMs > 100) {
      dtMs = 16.67;
    }
    if (!this.cvReady) {
      return;
    }
    const nowMs = ns / 1e6;
    if (this.engine) {
      // 目标 = 组件当前尺寸（首页滚动时引擎弹簧跟随 → 惯性回弹观感）
      this.engine.setViewTarget(this.avatarSize);
      this.engine.tick(nowMs, dtMs / 1000);
      this.engine.paint(this.ctx, this.avatarSize);
    }
  }

  private onTouched(ev: TouchEvent): void {
    if (!this.interactive || !this.engine) {
      return;
    }
    if (ev.touches && ev.touches.length > 0) {
      const t = ev.touches[0];
      if (ev.type === TouchType.Down || ev.type === TouchType.Move) {
        this.engine.pointerTo(t.x, t.y, this.avatarSize);
      }
    }
    if (ev.type === TouchType.Up || ev.type === TouchType.Cancel) {
      this.engine.clearPointer();
    }
  }

  private onTap(): void {
    if (!this.interactive || !this.engine) {
      return;
    }
    this.engine.spinOnce(1);
  }

  private onLongPress(): void {
    if (!this.interactive || !this.engine) {
      return;
    }
    this.engine.bounceOnce();
  }

  build() {
    Canvas(this.ctx)
      .width(this.avatarSize)
      .height(this.avatarSize)
      .onReady(() => {
        this.cvReady = true;
        this.lastNs = 0;
        if (this.engine) {
          this.engine.paint(this.ctx, this.avatarSize);
        }
      })
      .onTouch((ev: TouchEvent) => {
        this.onTouched(ev);
      })
      .onClick(() => {
        this.onTap();
      })
      .gesture(
        LongPressGesture({ duration: 500 })
          .onAction(() => {
            this.onLongPress();
          })
      )
  }
}
