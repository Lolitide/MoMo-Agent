/*
 * ============================================================================
 * 文件名：components/MoMoBasePage.ets
 * ============================================================================
 * 【用途】二级页通用封装（HdsNavDestination 容器）：沉浸标题栏（渐变模糊 +
 *   系统材质）+ 返回键 + 右上“···”菜单（bindMenu 弹出 MenuElement 列表）。
 *   —— 该模拟器上 HdsNavDestination 内容层渲染异常，当前子页采用
 *   ImmersiveTitleBar + 页面路由实现；本组件作为标准封装留存备用/参考。
 * 【前置条件 / 假设】
 *   - 依赖：@kit.UIDesignKit（hdsMaterial/HdsNavDestination/ScrollEffectType）、Theme；
 *   - 假设：作为 navDestination 的直接根组件使用。
 * 【输入 / 输出（后置条件）】
 *   - 输入：title/showBack/bgColor/menuItems + content Builder；
 *   - 输出：HdsNavDestination 渲染；菜单项点击 -> action 回调。
 * 【关键类 / 算法】
 *   - menuBuilder: 白圆钮 + bindMenu(数组) + clickEffect；titleBar style 双层
 *     （original 透明 / scrollEffect 深色玻璃）。
 * 【参考源】
 *   - 废案 components/BasePage.ets；Examples/hdsNavigation Examples.md
 * ============================================================================
 */
import { hdsMaterial, HdsNavDestination, ScrollEffectType } from '@kit.UIDesignKit';
import { Theme } from '../utils/Theme';

export interface MenuElement {
  value: string;
  action: () => void;
}

@Component
export struct MoMoBasePage {
  @Prop title: string = '';
  @Prop showBack: boolean = true;
  @Prop bgColor: ResourceColor = Theme.BG;
  @Prop menuItems: MenuElement[] = [];
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
    Column() {
    }
  }

  @Builder
  menuBuilder() {
    if (this.menuItems.length > 0) {
      Column() {
        Stack() {
          SymbolGlyph($r('sys.symbol.ellipsis_circle'))
            .fontSize(18)
            .fontColor([Theme.TEXT_MAIN])
        }
      }
      .width(40)
      .height(40)
      .borderRadius(20)
      .backgroundColor(Theme.CARD)
      .border({ width: 1, color: Theme.CARD_BORDER })
      .bindMenu(this.menuItems)
      .clickEffect({ level: ClickEffectLevel.LIGHT, scale: 0.9 })
    }
  }

  build() {
    HdsNavDestination() {
      this.content()
    }
    .titleBar({
      content: {
        title: {
          mainTitle: this.title
        },
        stackBuilder: (): void => this.menuBuilder()
      },
      style: {
        scrollEffectOpts: {
          scrollEffectType: ScrollEffectType.IMMERSIVE_GRADIENT_BLUR
        },
        originalStyle: {
          contentStyle: {
            titleStyle: {
              mainTitleColor: Theme.TEXT_MAIN
            },
            backIconStyle: {
              backgroundColor: '#FFFFFF',
              iconColor: Theme.TEXT_MAIN
            }
          }
        },
        scrollEffectStyle: {
          backgroundStyle: {
            backgroundColor: '#99000000'
          },
          contentStyle: {
            titleStyle: {
              mainTitleColor: '#FFFFFF'
            },
            backIconStyle: {
              backgroundColor: $r('sys.color.comp_background_tertiary'),
              iconColor: '#FFFFFF'
            }
          }
        },
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.IMMERSIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      },
      avoidLayoutSafeArea: true
    })
    .hideBackButton(!this.showBack)
    .backgroundColor(this.bgColor)
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
  }
}