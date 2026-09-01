/*
 * ============================================================================
 * 文件名：components/GardenNodeMarker.ets
 * ============================================================================
 * 【用途】花园节点标记组件：“花园”视图里每个记忆节点的小标记列：
 *   图标 + 年份 + 关键摘要（可点击 onPick）、被选中的描边高亮。
 * 【前置条件 / 假设】
 *   - 依赖：Memory(GardenNodeItem)、Theme、DateUtil；position 由父级（花园场景）传坐标；
 *   - 假设：标记按 (x,y) 绝对定位摆放，图标来自 sys.symbol。
 * 【输入 / 输出（后置条件）】
 *   - 输入：node(数据)、selected(是否选中)、点击；
 *   - 输出：onPick(node) 回调；高亮描边切换。
 * 【关键类 / 算法】
 *   - build：图标圆 + 年份胶囊 + 标题单行省略；“选中态”用 Theme 主色描边。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（花园场景节点标注）
 * ============================================================================
 */
import { Memory, MemoryType, MemoryTypeUtil } from '../model/Models';
import { Theme } from '../utils/Theme';

@Component
export struct GardenNodeMarker {
  @Prop memory: Memory = new Memory('x', '', new Date(), MemoryType.LIFE, 1);
  @Prop selected: boolean = false;
  onTap: (memory: Memory) => void = (memory: Memory) => {};

  private iconOf(type: MemoryType): Resource {
    if (type === MemoryType.STUDY) {
      return $r('sys.symbol.pencil_tip');
    } else if (type === MemoryType.INTEREST) {
      return $r('sys.symbol.flower');
    } else if (type === MemoryType.GOAL) {
      return $r('sys.symbol.sun_max');
    } else if (type === MemoryType.IMPORTANT) {
      return $r('sys.symbol.crown');
    }
    return $r('sys.symbol.leaf');
  }

  build() {
    Column({ space: 4 }) {
      Stack() {
        if (this.selected) {
          Column().width(66).height(66).borderRadius(999).backgroundColor('rgba(151,255,171,0.45)')
            .border({ width: 2, color: Theme.BRAND_DEEP })
        }
        Column().width(56).height(56).borderRadius(999).backgroundColor('#FFFFFF')
          .shadow({ radius: 10, color: 'rgba(47,76,53,0.16)', offsetY: 3 })
        SymbolGlyph(this.iconOf(this.memory.type))
          .fontSize(26)
          .fontColor([MemoryTypeUtil.colorOf(this.memory.type), MemoryTypeUtil.colorOf(this.memory.type)])
        // importance dots
        Column({ space: 2 }) {
          ForEach([1, 2, 3, 4, 5], (n: number) => {
            Row()
              .width(4).height(4).borderRadius(2)
              .backgroundColor(n <= this.memory.importance ? MemoryTypeUtil.colorOf(this.memory.type) : '#E3EAE4')
          }, (n: number) => n.toString())
        }
        .position({ x: 58, y: 34 })
      }
      .width(70)
      .height(70)

      Text(this.memory.date)
        .fontSize(9)
        .fontColor(Theme.SECONDARY)
        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .backgroundColor('rgba(255,255,255,0.88)')
        .borderRadius(8)
    }
    .onClick(() => {
      this.onTap(this.memory);
    })
    .scale(this.selected ? { x: 1.1, y: 1.1 } : { x: 1, y: 1 })
    .animation({ duration: 180, curve: Curve.EaseOut })
  }
}