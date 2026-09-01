/*
 * ============================================================================
 * 文件名：components/MiniCalendar.ets
 * ============================================================================
 * 【用途】迷你日历浮窗组件：月份标题 + 上/下月按钮 + 星期行 + 6 行日期网格；
 *   支持今日/选中高亮，点选回调 onPick，关闭按钮 onClose。
 * 【前置条件 / 假设】
 *   - 依赖：DateUtil（工作日/天数/补零）；selectedKey 形如 "2026-11-28"；
 *   - 假设：一次构建月份网格（<32 格），无需分页/滑动。
 * 【输入 / 输出（后置条件）】
 *   - 输入：selectedKey、点击日期、翻月、关闭；
 *   - 输出：onPick(Date)、onClose()；内部 year/month 状态维护当前月份。
 * 【关键类 / 算法】
 *   - buildCells：计算当月 1 号星期偏移，前置 -1 占位，再排 1..days；
 *   - isToday/isSelected：按日期键精确比较。
 * 【参考源】
 *   - iBest-UI 日历样式；ArkUI Flex+ForEach 网格示例
 * ============================================================================
 */
import { DateUtil } from '../utils/DateUtil';
import { Theme } from '../utils/Theme';

@Component
export struct MiniCalendar {
  @Prop monthDate: Date = new Date();
  @Prop selectedKey: string = '';
  onPick: (d: Date) => void = (d: Date) => {};
  onClose: () => void = () => {};
  @State month: number = new Date().getMonth();
  @State year: number = new Date().getFullYear();

  private weekNames: string[] = ['日', '一', '二', '三', '四', '五', '六'];

  // 生成当月网格：先填星期偏移个 -1 占位，再 1..days 顺序填充（按周日为起点的星期排列）
  private buildCells(): number[] {
    const cells: number[] = [];
    const firstW = DateUtil.firstWeekday(this.year, this.month);
    for (let i = 0; i < firstW; i++) {
      cells.push(-1);
    }
    const days = DateUtil.daysInMonth(this.year, this.month);
    for (let d = 1; d <= days; d++) {
      cells.push(d);
    }
    return cells;
  }

  private prevMonth(): void {
    if (this.month === 0) {
      this.month = 11;
      this.year -= 1;
    } else {
      this.month -= 1;
    }
  }

  private nextMonth(): void {
    if (this.month === 11) {
      this.month = 0;
      this.year += 1;
    } else {
      this.month += 1;
    }
  }

  @Builder
  roundBtn(icon: Resource, cb: () => void, ml: number = 0) {
    Column() {
      Stack() {
        Column().width(30).height(30).borderRadius(999).backgroundColor('rgba(0,0,0,0.05)')
        SymbolGlyph(icon).fontSize(14).fontColor([Theme.SECONDARY])
      }
    }
    .width(30)
    .height(30)
    .margin({ left: ml })
    .onClick(() => {
      cb();
    })
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        this.roundBtn($r('sys.symbol.chevron_left'), () => {
          this.prevMonth();
        })
        Text(this.year.toString() + ' 年 ' + (this.month + 1).toString() + ' 月')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.PRIMARY)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        this.roundBtn($r('sys.symbol.chevron_right'), () => {
          this.nextMonth();
        })
        this.roundBtn($r('sys.symbol.xmark'), () => {
          this.onClose();
        }, 8)
      }
      .width('100%')

      Row() {
        ForEach(this.weekNames, (w: string) => {
          Text(w)
            .fontSize(11)
            .fontColor(Theme.TERTIARY)
            .width('14.2%')
            .textAlign(TextAlign.Center)
        }, (w: string) => w)
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.buildCells(), (d: number) => {
          if (d < 0) {
            Column().width('14.2%').height(36)
          } else {
            Column() {
              Text(d.toString())
                .fontSize(13)
                .fontWeight(this.isSelected(d) ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.isSelected(d) ? '#FFFFFF' : (this.isToday(d) ? Theme.BRAND_DEEP : Theme.PRIMARY))
            }
            .width('14.2%')
            .height(36)
            .borderRadius(18)
            .justifyContent(FlexAlign.Center)
            .backgroundColor(this.isSelected(d) ? Theme.BRAND_DEEP : (this.isToday(d) ? '#E8FBEC' : 'rgba(0,0,0,0)'))
            .onClick(() => {
              this.onPick(new Date(this.year, this.month, d));
            })
          }
        }, (d: number) => d.toString())
      }
      .width('100%')
    }
    .width(316)
    .padding(18)
    .borderRadius(24)
    .backgroundColor('rgba(252,254,251,0.97)')
    .backgroundBlurStyle(BlurStyle.COMPONENT_ULTRA_THICK)
    .border({ width: 1, color: 'rgba(255,255,255,0.8)' })
    .shadow({ radius: 30, color: 'rgba(26,48,32,0.20)', offsetY: 8 })
  }

  private isToday(d: number): boolean {
    const now = new Date();
    return now.getFullYear() === this.year && now.getMonth() === this.month && now.getDate() === d;
  }

  private isSelected(d: number): boolean {
    return this.selectedKey === this.year.toString() + '-' + DateUtil.pad(this.month + 1) + '-' + DateUtil.pad(d);
  }
}