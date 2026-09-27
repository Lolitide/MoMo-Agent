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
    Column({ space: 5 }) {
      Stack() {
        if (this.selected) {
          Column().width(82).height(82).borderRadius(999).backgroundColor(MemoryTypeUtil.colorOf(this.memory.type) + '28')
            .border({ width: 2, color: MemoryTypeUtil.colorOf(this.memory.type) })
        }
        Stack() {
          Column()
            .width(62)
            .height(62)
            .borderRadius(999)
            .backgroundColor('#FCFFFA')
            .border({ width: 1, color: 'rgba(255,255,255,0.95)' })
            .shadow({ radius: 14, color: 'rgba(47,76,53,0.18)', offsetY: 4 })
          SymbolGlyph(this.iconOf(this.memory.type))
            .fontSize(29)
            .fontColor([MemoryTypeUtil.colorOf(this.memory.type), MemoryTypeUtil.colorOf(this.memory.type)])
        }
        .width(64)
        .height(64)

        // Importance is shown as a small crown of dots above the flower.
        Row({ space: 3 }) {
          ForEach([1, 2, 3, 4, 5], (n: number) => {
            Column()
              .width(n <= this.memory.importance ? 6 : 4)
              .height(n <= this.memory.importance ? 6 : 4)
              .borderRadius(4)
              .backgroundColor(n <= this.memory.importance
                ? MemoryTypeUtil.colorOf(this.memory.type) : '#DCE7DD')
          }, (n: number) => n.toString())
        }
        .position({ x: 28, y: 2 })
      }
      .width(88)
      .height(82)

      Text(this.memory.date)
        .fontSize(10)
        .fontColor('#4F6755')
        .fontWeight(FontWeight.Medium)
        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        .backgroundColor('rgba(250,255,249,0.88)')
        .borderRadius(10)
        .border({ width: 1, color: 'rgba(255,255,255,0.88)' })

      Text(this.memory.title)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#29402F')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width(108)
        .textAlign(TextAlign.Center)
    }
    .width(110)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.onTap(this.memory);
    })
    .scale(this.selected ? { x: 1.06, y: 1.06 } : { x: 1, y: 1 })
    .animation({ duration: 180, curve: Curve.EaseOut })
  }
}
