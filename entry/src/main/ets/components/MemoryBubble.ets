/*
 * ============================================================================
 * 文件名：components/MemoryBubble.ets
 * ============================================================================
 * 【用途】「气泡花园」的花瓣/花心圆：一颗直径由外部传入的圆形记忆节点。
 *   圆内固定为「类型图标（深色）+ 一行紧凑日期（MM.DD）」，不向外溢出任何文字。
 *
 * 【方形裁切/方形阴影的成因与修法（真机实测两轮）】
 *   ArkUI 的 shadow 与 border 都按组件的**外接矩形**绘制，不会跟随 borderRadius。
 *   因此只要在圆形之外再叠任何一层"有边框的正方形"（例如把描边画在未裁剪的
 *   同尺寸 Column 上），矩形的四条边就会露出来——视觉上就是圆圈四周被方形裁切。
 *   修法（本文件的层级结构，顺序不可颠倒）：
 *     ① CLIP 层：装底圆并 clip(true) → 阴影被裁进圆内，退化为圆环柔光；
 *     ② OUTLINE 层：描边圆**单独一层、且必须裁剪**，否则露出方形四边；
 *     ③ CONTENT 层：图标与日期，尺寸略小于圆以免触边。
 *   三层都是同一个直径的圆，因此任何一层都不会露出矩形边。
 *
 * 【前置条件 / 假设】
 *   - 依赖：Memory（模型）、MemoryTypeUtil（配色）、Theme；
 *   - 假设：位置 (x,y) 由父级（A_Garden.bubbleView）按 BubbleLayoutUtil 结果绝对定位，
 *     本组件自身不做定位、不感知屏宽；
 *   - 假设：只承载「完整圆圈」；溢出的小圆点由 A_Garden 直接画实心圆，不经此处。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：memory、d（直径）、selected、onPick 回调；
 *   - 输出：onPick(memory) 回调；无副作用、不写任何仓库；
 *   - 后置：按压反馈结束后恢复 scale(1)。
 *
 * 【关键类 / 算法】
 *   - 尺寸派生：图标/字号/描边宽度全部由 d 按比例算出并设保底；
 *   - 重要度用「描边粗细」表达（importance >= 4 加粗），不占用圆外空间；
 *   - 只用 scale 做按压/选中反馈，**不做透明度动画**（原因见 build 内注释）。
 *
 * 【参考源】
 *   - 用户提供的两张手绘草图（花心居中 + 花瓣围绕）
 * ============================================================================
 */
import { Memory, MemoryType, MemoryTypeUtil } from '../model/Models';
import { Theme } from '../utils/Theme';

@Component
export struct MemoryBubble {
  @Prop memory: Memory = new Memory('x', '', new Date(), MemoryType.LIFE, 1);
  @Prop d: number = 48;
  @Prop selected: boolean = false;
  onPick: (memory: Memory) => void = (memory: Memory) => {};

  @State private pressing: boolean = false;

  private iconOf(type: MemoryType): Resource {
    if (type === MemoryType.STUDY) {
      return $r('sys.symbol.pencil_tip');
    } else if (type === MemoryType.INTEREST) {
      return $r('sys.symbol.flower');
    } else if (type === MemoryType.GOAL) {
      return $r('sys.symbol.sun_max');
    }
    return $r('sys.symbol.leaf');
  }

  /**
   * 从 "YYYY.MM.DD" 取出 "MM.DD" 并补零。
   * 历史种子里日期不补零（"2026.11.4" 表示 11 月 4 日），直接用会与 24 日混淆。
   */
  private shortDate(): string {
    const parts = this.memory.date.split('.');
    if (parts.length === 3) {
      const mm: string = parts[1].length < 2 ? '0' + parts[1] : parts[1];
      const dd: string = parts[2].length < 2 ? '0' + parts[2] : parts[2];
      return mm + '.' + dd;
    }
    return this.memory.date;
  }

  private onTouched(ev: TouchEvent): void {
    if (ev.type === TouchType.Down) {
      if (!this.pressing) {
        this.pressing = true;
      }
    } else if (ev.type === TouchType.Up || ev.type === TouchType.Cancel) {
      if (this.pressing) {
        this.pressing = false;
      }
    }
  }

  build() {
    Stack() {
      // 【不要用 .shadow() 做柔和阴影】ArkUI 的 shadow 按外接矩形绘制：即使外面套 clip(true)，
      // 圆的直线段处仍会透出矩形栅格的边；换成两层半透明同心圆又会叠出脏色描边（都实测过）。
      // Apple Watch 的图标本身就是扁平的，这里改成「浅色底 + 干净的描边」，观感更对、也没有任何矩形来源。
      Column()
        .width(this.d)
        .height(this.d)
        .borderRadius(Theme.RADIUS_PILL)
        .backgroundColor(MemoryTypeUtil.bubbleBgOf(this.memory.type))
        .border({
          width: this.selected
            ? 2.6
            : (this.memory.importance >= 4 ? 1.8 : 1.2),
          color: this.selected
            ? MemoryTypeUtil.colorOf(this.memory.type)
            : MemoryTypeUtil.borderOf(this.memory.type)
        })

      // 圆内内容：深色图标 + 简短日期。
      // 宽度留 88% 余量，避免触到圆边而显得"被裁"；字号设保底，Ø40 时仍可读。
      Column({ space: 1 }) {
        SymbolGlyph(this.iconOf(this.memory.type))
          .fontSize(Math.max(14, this.d * 0.30))
          .fontColor([MemoryTypeUtil.iconColorOf(this.memory.type),
            MemoryTypeUtil.iconColorOf(this.memory.type)])
        Text(this.shortDate())
          .fontSize(Math.max(9, this.d * 0.19))
          .fontWeight(FontWeight.Medium)
          .fontColor(MemoryTypeUtil.iconColorOf(this.memory.type))
          .maxLines(1)
      }
      .width(this.d * 0.88)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
    .width(this.d)
    .height(this.d)
    .alignContent(Alignment.Center)
    // 【不要在这里加 .opacity(entered?1:0) + .animation()】
    // aboutToAppear 里才把 entered 置 true，运行时一旦重建就会先渲染成透明再淡入，
    // 视觉上就是"当前按钮与目标按钮一起闪一下"；而且每个气泡各挂一份 .animation() 会明显拖慢点击响应。
    // 只保留按压/选中的缩放过渡（由 .animation 提供平滑，但不涉及透明度）。
    .scale(this.scaleValue())
    .animation({ duration: 140, curve: Curve.EaseOut })
    .onClick(() => {
      this.onPick(this.memory);
    })
    .onTouch((ev: TouchEvent) => {
      this.onTouched(ev);
    })
  }

  /** 优先级：按压 > 选中 > 默认 */
  private scaleValue(): ScaleOptions {
    if (this.pressing) {
      return { x: 0.94, y: 0.94 };
    }
    if (this.selected) {
      return { x: 1.06, y: 1.06 };
    }
    return { x: 1, y: 1 };
  }
}
