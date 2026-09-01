/*
 * ============================================================================
 * 文件名：utils/TreeLayout.ets
 * ============================================================================
 * 【用途】“记忆树”布局算法工具：把一颗 MemoryTreeNode 树转成行列坐标
 *   （自顶向下 + 子树对齐），输出可绘制坐标供 MemoryTreeGraph 使用。
 * 【前置条件 / 假设】
 *   - 输入假设：树无环、节点含 children；坐标单位为 vp，原点在左上；
 *   - 依赖：MemoryTreeNode（模型）、GardenNodeMarker 尺寸常量（节点宽高/层级间距）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：root 节点、画布尺寸（可选最外层预算）；
 *   - 输出：Map<字符串节点key, {x,y}> 或节点列表携带 pos；纯函数无副作用。
 * 【关键类 / 算法】
 *   - 典型“tidy tree”简化版：
 *     1) 递归计算每棵子树的叶子数（宽度）；
 *     2) 后序分配：叶子按序排布，父节点取子节点中点；
 *     3) 层级 y = 深度 * 层高；最终整体平移居中。
 *   复杂度 O(N)。
 * 【参考源】
 *   - HarmonyLearn（树/图谱布局思路）；Reingold-Tilford 树布局经典算法（简化变体）
 * ============================================================================
 */
import { MemoryTreeNode } from '../model/Models';

// 布局算法：1)递归统计叶子数→2)后序分配 x（子节点取中点、叶子顺序排布）→3)y=深度*层高；复杂度 O(N)
export class TreePos {
  id: string = '';
  title: string = '';
  type: string = '';
  x: number = 0;
  y: number = 0;
  w: number = 96;
  h: number = 34;
  depth: number = 0;

  constructor(id: string, title: string, type: string, x: number, y: number, w: number, h: number, depth: number) {
    this.id = id;
    this.title = title;
    this.type = type;
    this.x = x;
    this.y = y;
    this.w = w;
    this.h = h;
    this.depth = depth;
  }
}

export class TreeLayoutUtil {
  static layout(root: MemoryTreeNode, spacingX: number, spacingY: number): TreePos[] {
    const result: TreePos[] = [];
    let slot = 0;
    const walk = (node: MemoryTreeNode, depth: number): number => {
      let x = 0;
      if (node.children.length === 0) {
        slot += 1;
        x = slot * spacingX;
      } else {
        let sum = 0;
        for (let i = 0; i < node.children.length; i++) {
          sum += walk(node.children[i], depth + 1);
        }
        x = sum / node.children.length;
      }
      const w = Math.max(84, Math.min(160, node.title.length * 14 + 30));
      result.push(new TreePos(node.id, node.title, node.type, x, depth * spacingY, w, 34, depth));
      return x;
    };
    walk(root, 0);
    return result;
  }
}