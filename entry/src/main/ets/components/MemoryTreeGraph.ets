/*
 * ============================================================================
 * 文件名：components/MemoryTreeGraph.ets
 * ============================================================================
 * 【用途】记忆树绘制组件：把 MemoryTreeNode 树结构按 TreeLayout 的布局结果绘制到 Canvas，
 *   支持节点圆点/连线/标签、点击选中（回调 onPick）与整体缩放(zoom)。
 * 【前置条件 / 假设】
 *   - 依赖：TreeLayout（布局算法工具）、MemoryTreeNode（模型）、GardenNodeMarker；
 *   - 假设：树深度有限（Mock 4-5 层），一次全量绘制；zoom 由外部传入（0.5~2.4）。
 * 【输入 / 输出（后置条件）】
 *   - 输入：nodes(树)、zoom(缩放)、selectedId(选中节点)；
 *   - 输出：Canvas 绘制树；onPick(id) 回调通知上层选中。
 * 【关键类 / 算法】
 *   - 绘制：先按 TreeLayout 计算的 (x,y) 画连线（贝塞尔/直线），再画节点圆+文字；
 *   - 命中检测：点击坐标与节点包围盒距离判定（简单最近节点）。
 * 【参考源】
 *   - HarmonyLearn（知识图谱绘制思路）；Examples/ArkUISample Canvas 样例
 * ============================================================================
 */
import { MemoryTreeNode } from '../model/Models';
import { TreePos, TreeLayoutUtil } from '../utils/TreeLayout';

@Component
export struct MemoryTreeGraph {
  @Prop root: MemoryTreeNode = new MemoryTreeNode();
  @Prop selectedId: string = '';
  @Prop zoom: number = 1;
  onSelect: (nodeId: string) => void = (nodeId: string) => {};
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private laid: TreePos[] = [];
  private map: Map<string, TreePos> = new Map();
  private panX: number = 0;
  private panY: number = 0;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private canvasW: number = 0;
  private canvasH: number = 0;

  aboutToAppear(): void {
    this.recompute();
  }

  private recompute(): void {
    this.laid = TreeLayoutUtil.layout(this.root, 170, 130);
    this.map = new Map();
    for (let i = 0; i < this.laid.length; i++) {
      this.map.set(this.laid[i].id, this.laid[i]);
    }
    // 初始定位：根节点居中
    let minX = 99999;
    let maxX = -99999;
    for (let i = 0; i < this.laid.length; i++) {
      minX = Math.min(minX, this.laid[i].x - this.laid[i].w / 2);
      maxX = Math.max(maxX, this.laid[i].x + this.laid[i].w / 2);
    }
    this.panX = this.canvasW / 2 - (minX + maxX) / 2 * this.zoom;
    this.panY = 86;
  }

  private draw(): void {
    if (this.canvasW <= 0 || this.canvasH <= 0 || this.laid.length === 0) {
      return;
    }
    const ctx = this.ctx;
    ctx.clearRect(0, 0, this.canvasW, this.canvasH);
    ctx.save();
    ctx.setTransform(this.zoom, 0, 0, this.zoom, this.panX, this.panY);

    // edges
    for (let i = 0; i < this.laid.length; i++) {
      const node = this.laid[i];
      if (node.id === 'root') {
        continue;
      }
      const parent = this.findParent(node.id);
      if (parent !== null) {
        ctx.beginPath();
        ctx.moveTo(parent.x, parent.y + parent.h);
        ctx.bezierCurveTo(parent.x, parent.y + parent.h + 46, node.x, node.y - 46, node.x, node.y);
        ctx.strokeStyle = 'rgba(124, 180, 139, 0.55)';
        ctx.lineWidth = 1.6;
        ctx.stroke();
      }
    }

    // nodes
    for (let i = 0; i < this.laid.length; i++) {
      const node = this.laid[i];
      const isSel = node.id === this.selectedId;
      const isGroup = node.type === 'group';
      ctx.beginPath();
      this.roundRect(node.x - node.w / 2, node.y, node.w, node.h, 12);
      if (isSel) {
        ctx.fillStyle = '#97FFAB';
        ctx.strokeStyle = '#2C9C4E';
        ctx.lineWidth = 2;
      } else if (isGroup) {
        ctx.fillStyle = '#F0F8F2';
        ctx.strokeStyle = '#B9D9C2';
        ctx.lineWidth = 1.4;
      } else {
        ctx.fillStyle = '#FFFFFF';
        ctx.strokeStyle = '#CDE3D3';
        ctx.lineWidth = 1.4;
      }
      ctx.fill();
      ctx.stroke();

      ctx.fillStyle = isSel ? '#1C3322' : '#33413A';
      ctx.font = '12vp HarmonyOS Sans';
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillText(node.title, node.x, node.y + node.h / 2);

      if (isGroup) {
        const col = '#6FA97E';
        ctx.beginPath();
        ctx.arc(node.x + node.w / 2 + 12, node.y + node.h / 2, 4, 0, Math.PI * 2);
        ctx.fillStyle = col;
        ctx.fill();
      }
    }
    ctx.restore();
  }

  private findParent(id: string): TreePos | null {
    if (id === 'root') {
      return null;
    }
    const node = this.findNode(this.root, id);
    if (node === null || node.parentId === '') {
      return null;
    }
    return this.map.get(node.parentId) ?? null;
  }

  private findNode(node: MemoryTreeNode | null, id: string): MemoryTreeNode | null {
    if (node === null) {
      return null;
    }
    if (node.id === id) {
      return node;
    }
    for (let i = 0; i < node.children.length; i++) {
      const found = this.findNode(node.children[i], id);
      if (found !== null) {
        return found;
      }
    }
    return null;
  }

  private roundRect(x: number, y: number, w: number, h: number, r: number): void {
    const ctx = this.ctx;
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
  }

  private hitTest(x: number, y: number): string {
    const wx = (x - this.panX) / this.zoom;
    const wy = (y - this.panY) / this.zoom;
    for (let i = 0; i < this.laid.length; i++) {
      const n = this.laid[i];
      if (wx >= n.x - n.w / 2 && wx <= n.x + n.w / 2 && wy >= n.y - 6 && wy <= n.y + n.h + 6) {
        return n.id;
      }
    }
    return '';
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.canvasW = this.ctx.width;
        this.canvasH = this.ctx.height;
        this.recompute();
        this.draw();
      })
      .onAreaChange(() => {
        this.canvasW = this.ctx.width;
        this.canvasH = this.ctx.height;
        this.draw();
      })
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
            .onActionStart(() => {
              this.panStartX = this.panX;
              this.panStartY = this.panY;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.panX = this.panStartX + event.offsetX;
              this.panY = this.panStartY + event.offsetY;
              this.draw();
            })
        )
      )
      .onClick((event: ClickEvent) => {
        const id = this.hitTest(event.x, event.y);
        if (id !== '') {
          this.onSelect(id);
        }
      })
  }

  private reDrawWithZoom(scale: number): void {
    // 占位：缩放由页面 zoom 控制，防止手势冲突
    this.draw();
  }
}