/*
 * ============================================================================
 * 文件名：components/BottomNavBar.ets
 * ============================================================================
 * 【用途】自绘底部导航栏（备用组件）：悬浮胶囊（首页/花园/设置）+ 分离加号按钮，
 *   clickEffect 反馈；当前已由 HdsTabs + miniBar（MainPage）替代为本组件备用保留。
 * 【前置条件 / 假设】
 *   - 依赖：Theme、DeviceUtil（底部安全区）；tab 高亮色为品牌绿；
 *   - 假设：面板宽 250-320vp、底部边距 12-20。
 * 【输入 / 输出（后置条件）】
 *   - 输入：点击 Tab/加号；
 *   - 输出：onSelect(index)/onAdd() 回调。
 * 【关键类 / 算法】
 *   - 胶囊 = 半透明底 + 全圆角 + 微阴影；加号独立圆钮（与胶囊分离）。
 * 【参考源】
 *   - MoMo_DOC/UI 参考图（底部导航）；ArkUI Row/clickEffect 示例
 * ============================================================================
 */
import { Theme } from '../utils/Theme';
import { DeviceUtil } from '../utils/DeviceUtil';

interface NavItemModel {
  icon: Resource;
  iconSelected: Resource;
  label: string;
}

@Component
export struct BottomNavBar {
  @Prop current: number = 0;
  onSelect: (index: number) => void = (index: number) => {};
  onAdd: () => void = () => {};

  private items: NavItemModel[] = [
    { icon: $r('sys.symbol.house'), iconSelected: $r('sys.symbol.house_fill'), label: '首页' },
    { icon: $r('sys.symbol.leaf'), iconSelected: $r('sys.symbol.leaf_fill'), label: '花园' },
    { icon: $r('sys.symbol.gearshape'), iconSelected: $r('sys.symbol.gearshape_fill'), label: '设置' }
  ];

  private bottomH: number = 16;

  aboutToAppear(): void {
    DeviceUtil.initFromUi(this.getUIContext());
    this.bottomH = DeviceUtil.bottomBarH;
  }

  build() {
    Row() {
      Row() {
        ForEach(this.items, (item: NavItemModel, index: number) => {
          Column({ space: 2 }) {
            Stack() {
              SymbolGlyph(this.current === index ? item.iconSelected : item.icon)
                .fontSize(26)
                .fontColor([
                  this.current === index ? Theme.BRAND_DEEP : '#8CA089',
                  this.current === index ? Theme.BRAND_DEEP : '#8CA089'
                ])
            }
            .width(52)
            .height(44)
            .borderRadius(22)
            .backgroundColor(this.current === index ? 'rgba(151,255,171,0.30)' : 'rgba(0,0,0,0)')
            .animation({ duration: 220, curve: Curve.EaseOut })
          }
          .onClick(() => {
            this.onSelect(index);
          })
          .padding({ left: 6, right: 6 })
        }, (item: NavItemModel) => item.label)
      }
      .layoutWeight(1)
      .height(64)
      .borderRadius(32)
      .padding({ left: 8, right: 8 })
      .backgroundColor('rgba(250,252,249,0.86)')
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({ width: 1, color: 'rgba(255,255,255,0.86)' })
      .shadow({ radius: 26, color: Theme.SHADOW, offsetY: 8 })
      .justifyContent(FlexAlign.SpaceEvenly)

      Stack() {
        SymbolGlyph($r('sys.symbol.plus')).fontSize(26).fontColor([Theme.PRIMARY])
      }
      .width(58)
      .height(58)
      .borderRadius(29)
      .backgroundColor('#F2FFFFFF')
      .backdropBlur(20)
      .backgroundBlurStyle(BlurStyle.COMPONENT_THICK)
      .border({ width: 1, color: 'rgba(255,255,255,0.9)' })
      .shadow({ radius: 14, color: '#22000000', offsetX: 0, offsetY: 4 })
      .onClick(() => {
        this.onAdd();
      })
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.92 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 10, bottom: this.bottomH + 6 })
    .justifyContent(FlexAlign.Center)
  }
}