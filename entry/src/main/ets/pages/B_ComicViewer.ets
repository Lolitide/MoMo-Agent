import { HdsNavDestination } from '@kit.UIDesignKit';
import { AppRouter } from '../router/AppRouter';
import { ComicRepository } from '../repository/Repositories';

@Component
export struct B_ComicViewer {
  @State idx: number = 0;
  @State vScale: number = 1;
  @State vTx: number = 0;
  @State vTy: number = 0;
  private pinchStart: number = 1;
  private panStartX: number = 0;
  private panStartY: number = 0;
  private viewW: number = 360;
  private viewH: number = 780;
  private imgW: number = 0;
  private imgH: number = 0;
  private fitScale: number = 1;
  @State contentW: number = 360;
  @State contentH: number = 780;

  aboutToAppear(): void {
    this.idx = AppRouter.viewerIndex;
  }

  // 真实尺寸 -> 贴合尺寸（vp，比例无密度依赖）
  private recomputeFit(): void {
    if (this.imgW <= 0 || this.viewW <= 0 || this.viewH <= 0) {
      return;
    }
    this.fitScale = Math.min(this.viewW / this.imgW, this.viewH / this.imgH);
    this.applyContent();
  }

  private applyContent(): void {
    this.contentW = this.imgW * this.fitScale * this.vScale;
    this.contentH = this.imgH * this.fitScale * this.vScale;
    this.clampBounds();
  }

  // 屏幕坐标边界：内容边缘不得进入视口（无 scale 属性，平移=屏幕位移，直观无歧义）
  private clampBounds(): void {
    const mx = Math.max((this.contentW - this.viewW) / 2, 0);
    const my = Math.max((this.contentH - this.viewH) / 2, 0);
    this.vTx = Math.min(Math.max(this.vTx, -mx), mx);
    this.vTy = Math.min(Math.max(this.vTy, -my), my);
  }

  private resetViewer(): void {
    animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
      this.vScale = 1;
      this.vTx = 0;
      this.vTy = 0;
      this.applyContent();
    });
  }

  build() {
    HdsNavDestination() {
      Stack({ alignContent: Alignment.Center }) {
        Image(ComicRepository.get().getToday().pages[this.idx].image)
          // 尺寸驱动：组件=内容实际显示尺寸（中心对齐 + 平移，无需 scale/translate 复合顺序）
          .width(this.contentW)
          .height(this.contentH)
          .objectFit(ImageFit.Cover)
          .sharedTransition('comicViewer', { duration: 340, curve: Curve.EaseOut })
          .translate({ x: this.vTx, y: this.vTy })
          .onComplete((event) => {
            if (!event) {
              return;
            }
            this.imgW = event.width;
            this.imgH = event.height;
            this.recomputeFit();
          })
          .gesture(
            GestureGroup(GestureMode.Exclusive,
              PinchGesture({ fingers: 2, distance: 2 })
                .onActionStart(() => {
                  this.pinchStart = this.vScale;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.vScale = Math.min(Math.max(this.pinchStart * event.scale, 1), 4);
                  this.applyContent();
                }),
              PanGesture({ fingers: 1, direction: PanDirection.All, distance: 3 })
                .onActionStart(() => {
                  this.panStartX = this.vTx;
                  this.panStartY = this.vTy;
                })
                .onActionUpdate((event: GestureEvent) => {
                  // 屏幕位移 = 手指位移（直接、跟手）
                  this.vTx = this.panStartX + event.offsetX;
                  this.vTy = this.panStartY + event.offsetY;
                  this.clampBounds();
                }),
              TapGesture({ count: 2 })
                .onAction(() => {
                  if (this.vScale > 1.05) {
                    this.resetViewer();
                  } else {
                    // 双击：2x + 居中（内容重新对齐中心）
                    animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
                      this.vScale = 2;
                      this.vTx = 0;
                      this.vTy = 0;
                      this.applyContent();
                    });
                  }
                })
            )
          )

        // 顶部信息条：页码（左）+ 关闭按钮（右）
        Row() {
          Text((this.idx + 1).toString() + ' / ' + ComicRepository.get().getToday().pages.length.toString())
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.9)')
            .backgroundColor('rgba(0,0,0,0.35)')
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .borderRadius(14)
          Blank()
          Column() {
            Stack() {
              Column().width(44).height(44).borderRadius(999).backgroundColor('rgba(255,255,255,0.22)')
              SymbolGlyph($r('sys.symbol.xmark')).fontSize(19).fontColor(['#FFFFFF'])
            }
          }
          .width(44)
          .height(44)
          .onClick(() => {
            AppRouter.back();
          })
          .gesture(
            TapGesture({ count: 1 })
              .onAction(() => {
                AppRouter.back();
              })
          )
          .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
        }
        .width('100%')
        .padding({ left: 22, right: 16 })
        .position({ y: 104 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#000000')
      .onAreaChange((oldValue: Area, newValue: Area) => {
        this.viewW = Number(newValue.width);
        this.viewH = Number(newValue.height);
        this.recomputeFit();
      })
    }
    .hideTitleBar(true)
    .backgroundColor('#000000')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}
