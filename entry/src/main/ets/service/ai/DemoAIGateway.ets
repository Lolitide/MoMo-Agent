/*
 * ============================================================================
 * 文件名：service/ai/DemoAIGateway.ets
 * ============================================================================
 * 【用途】演示模式与真实模式的 AI 统一网关。
 *   页面层只依赖本类，不再直接持有 AIServiceCloud，从而获得两个能力：
 *     1. 演示模式下一律秒回预制内容（不联网），保证现场演示不被网络打断；
 *     2. 真实模式（含游客）走云端 AI，失败时自动降级并明确告知用户。
 *
 * 【为什么需要这一层】
 *   AIServiceCloud 本身不要求登录（云函数只把 userId 当作关联字段，不作鉴权），
 *   所以「游客能用 AI」这件事不需要改动 AIServiceCloud。需要补齐的是：
 *   - 演示态不能因为一次网络超时就把现场演示卡在错误页；
 *   - 演示态不能因为调用真实接口而在演示界面留下「真实但不可控」的内容；
 *   - 失败必须让用户看得见（toast），不能静默伪装成功。
 *
 * 【前置条件 / 假设】
 *   - 依赖：DemoModeService（判断是否演示态）、DemoMockData（预制返回）、
 *     AIServiceCloud（真实云端）、PromptUtil（降级提示）、Logger；
 *   - 假设：真实分支的错误由本类统一处理为「降级 + 提示」，不向上抛；
 *   - 假设：不改变 AIServiceCloud 的任何行为，仅在其外面包一层分流。
 *
 * 【输入 / 输出（后置条件）】
 *   - 输入：事件/总结/漫画分镜/纠正文本等业务参数；
 *   - 输出：Promise<string> / Promise<Comic> / Promise<ComicPanel[]>；
 *   - 后置：演示态下不产生任何网络请求；真实分支失败时返回预制内容并发出提示。
 *
 * 【关键类 / 算法】
 *   - 分流 + 降级（try real / catch -> demo + toast）；
 *   - 预制内容全部取自 DemoMockData，避免与 mock 层耦合在本类内。
 *
 * 【参考源】
 *   - service/ai/AIServiceCloud.ets（真实云端能力，本类不改动它）
 *   - MVP与复赛材料清单.md §4.4 降级策略表
 * ============================================================================
 */
import { Logger } from '../../utils/Logger';
import { PromptUtil } from '../../utils/PromptUtil';
import { Comic, ComicPage, EventItem, PersonalityProfile } from '../../model/Models';
import { ComicPanel } from '../cloud/CloudFunctionService';
import { AIServiceCloud } from './AIServiceCloud';
import { DemoModeService } from '../DemoModeService';
import { DemoMockData } from '../../mock/DemoMockData';

export class DemoAIGateway {
  private static readonly TAG = 'DemoAIGateway';

  /**
   * 生成今日总结。
   * 演示态：秒回预制文案；真实态：云端生成，失败降级为预制文案并提示。
   */
  static async dailySummary(events: EventItem[], mood?: string): Promise<string> {
    if (DemoModeService.get().isDemo()) {
      return DemoMockData.demoDailySummaryText();
    }
    try {
      return await AIServiceCloud.get().generateDailySummary(events, mood);
    } catch (err) {
      Logger.error(DemoAIGateway.TAG, `云端总结失败，降级为内置内容: ${err}`);
      PromptUtil.toast('云端总结未完成，已使用内置内容');
      return DemoMockData.demoDailySummaryText();
    }
  }

  /**
   * 仅生成漫画分镜脚本（用于预览，不出图）。
   * 演示态：秒回预制分镜；真实态：云端生成，失败返回空数组（与仓库原有语义一致）。
   */
  static async comicScript(summary: string, events: EventItem[],
    profile?: PersonalityProfile): Promise<ComicPanel[]> {
    if (DemoModeService.get().isDemo()) {
      return DemoAIGateway.demoPanels();
    }
    try {
      return await AIServiceCloud.get().generateComicScript(summary, events, profile);
    } catch (err) {
      Logger.error(DemoAIGateway.TAG, `云端分镜生成失败: ${err}`);
      const empty: ComicPanel[] = [];
      return empty;
    }
  }

  /**
   * 生成今日漫画（脚本 + 出图一起完成），返回可直接展示的 Comic。
   * 演示态：秒回预制漫画（含占位图）；
   * 真实态：云端脚本 + 云端出图，任一步失败都降级为预制漫画并提示。
   */
  static async comic(summary: string, events: EventItem[], profile?: PersonalityProfile): Promise<Comic> {
    if (DemoModeService.get().isDemo()) {
      return DemoMockData.buildComic();
    }
    try {
      const panels = await AIServiceCloud.get().generateComicScript(summary, events, profile);
      const imageUrls = await AIServiceCloud.get().generateComicImages(panels);

      const comic = new Comic();
      comic.id = `comic-${Date.now()}`;
      comic.date = DemoAIGateway.todayDot();
      comic.sourceDate = comic.date;
      comic.title = `默默的一天 vol.${Date.now() % 100}`;
      comic.message = '今天也有好好陪你，明天见面的路上记得看一眼窗外的云。';
      comic.profileVersion = profile ? profile.version : 0;
      comic.styleKey = profile ? profile.comicStyle : '';
      comic.generationStatus = 'success';

      for (let i = 0; i < panels.length; i++) {
        const panel = panels[i];
        const page = new ComicPage();
        page.index = i;
        page.title = panel.description || `分镜 ${i + 1}`;
        page.image = imageUrls[i];
        comic.pages.push(page);
      }
      return comic;
    } catch (err) {
      Logger.error(DemoAIGateway.TAG, `云端漫画失败，降级为内置漫画: ${err}`);
      PromptUtil.toast('云端漫画未完成，已展示内置内容');
      return DemoMockData.buildComic();
    }
  }

  /**
   * 处理记忆纠正。
   * 演示态：秒回预制纠正结果；真实态：云端纠正，失败降级为预制文案并提示。
   */
  static async correction(originalSummary: string, userCorrection: string): Promise<string> {
    if (DemoModeService.get().isDemo()) {
      return DemoMockData.demoCorrectionResult();
    }
    try {
      return await AIServiceCloud.get().processMemoryCorrection(originalSummary, userCorrection);
    } catch (err) {
      Logger.error(DemoAIGateway.TAG, `云端纠正失败，降级为内置内容: ${err}`);
      PromptUtil.toast('云端纠正未完成，已使用内置结果');
      return DemoMockData.demoCorrectionResult();
    }
  }

  /**
   * 演示态反馈确认文案，供页面直接调用（避免页面依赖 mock 层）
   */
  static feedbackAck(score: number): string {
    return DemoMockData.demoFeedbackAck(score);
  }

  /**
   * 今日漫画的预制内容（首次打卡引导等场景需要「立刻拿到一整套漫画」）
   */
  static demoComic(): Comic {
    return DemoMockData.buildComic();
  }

  // ==================== 内部工具 ====================

  /**
   * 把 DemoMockData 的分镜结构收敛为云函数契约要求的 ComicPanel[]。
   * 结构已在 DemoMockData 侧对齐，这里只做类型收敛，避免在 mock 层引入
   * service/cloud 的 import 依赖。
   */
  private static demoPanels(): ComicPanel[] {
    const src = DemoMockData.buildComicPanels();
    const out: ComicPanel[] = [];
    for (let i = 0; i < src.length; i++) {
      const item = src[i];
      out.push({
        index: item.index,
        description: item.description,
        prompt: item.prompt,
        dialogue: item.dialogue
      });
    }
    return out;
  }

  private static todayDot(): string {
    const now = new Date();
    const mm = now.getMonth() + 1;
    const dd = now.getDate();
    return `${now.getFullYear()}.${mm < 10 ? '0' : ''}${mm}.${dd < 10 ? '0' : ''}${dd}`;
  }
}
