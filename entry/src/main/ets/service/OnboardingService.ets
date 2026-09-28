/*
 * ============================================================================
 * 文件名：service/OnboardingService.ets
 * ============================================================================
 * 【用途】首次体验相关的本地持久化（Preferences 'momo_onboarding_v1'）：
 *   - 陪伴档案（PersonalityProfile）读写，按用户 ID 分键存储；
 *   - 「重新体验首次打卡」所需的重置与强制登录标记（FORCE_LOGIN_KEY）。
 * 【前置条件 / 假设】
 *   - 依赖：@ohos.data.preferences、AuthService、model/Models；
 *   - 假设：userId 为空时所有写操作安全跳过、读操作返回默认值；
 *   - 打卡引导（CheckInGuideStep）已随首次教程一起移除，档案之外不再有引导状态。
 * 【输入 / 输出（后置条件）】
 *   - 输入：getCurrentUserId / loadProfile / saveProfile / restartFirstExperience /
 *     consumeForceLogin / profileToUser；
 *   - 输出：档案读写成败；restartFirstExperience 后档案被删除且下次启动强制登录页。
 * 【关键类 / 算法】
 *   - 单例；profile 以 JSON 字符串存入 Preferences，读取时逐字段兜底默认值。
 * 【参考源】
 *   - DevEco Preferences 文档；repository/Repositories.ets 的 UserRepository
 * ============================================================================
 */
import preferences from '@ohos.data.preferences';
import { PersonalityProfile, User } from '../model/Models';
import { AuthService } from './auth/AuthService';

export class OnboardingService {
  private static instance: OnboardingService | null = null;
  private static readonly PREFS_NAME = 'momo_onboarding_v1';
  private static readonly PROFILE_PREFIX = 'profile_';
  private static readonly FORCE_LOGIN_KEY = 'force_login';
  private authService: AuthService = AuthService.get();

  static get(): OnboardingService {
    if (OnboardingService.instance === null) {
      OnboardingService.instance = new OnboardingService();
    }
    return OnboardingService.instance;
  }

  async getCurrentUserId(): Promise<string> {
    const user = await this.authService.getCurrentUser();
    return user ? user.userId : '';
  }

  async loadProfile(userId: string): Promise<PersonalityProfile | null> {
    if (!userId) {
      return null;
    }
    try {
      const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
      const raw = await prefs.get(OnboardingService.PROFILE_PREFIX + userId, '') as string;
      if (!raw) {
        return null;
      }
      const value = JSON.parse(raw) as PersonalityProfile;
      const profile = new PersonalityProfile();
      profile.tone = value.tone || profile.tone;
      profile.pace = value.pace || profile.pace;
      profile.comicStyle = value.comicStyle || profile.comicStyle;
      profile.focusTopics = value.focusTopics && value.focusTopics.length > 0 ? value.focusTopics : profile.focusTopics;
      profile.version = value.version || 1;
      return profile;
    } catch (err) {
      console.error('读取默默档案失败', err);
      return null;
    }
  }

  async saveProfile(userId: string, profile: PersonalityProfile): Promise<void> {
    if (!userId) {
      throw new Error('未找到当前用户');
    }
    const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
    await prefs.put(OnboardingService.PROFILE_PREFIX + userId, JSON.stringify(profile));
    await prefs.flush();
  }

  // 清空档案与登录态：下次进入时从登录页重新走一遍首次体验
  async restartFirstExperience(userId: string): Promise<void> {
    const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
    if (userId) {
      await prefs.delete(OnboardingService.PROFILE_PREFIX + userId);
    }
    await prefs.put(OnboardingService.FORCE_LOGIN_KEY, true);
    await prefs.flush();
    try {
      await this.authService.logout();
    } catch (err) {
      console.error('重启首次体验时退出登录失败', err);
    }
  }

  async consumeForceLogin(): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
      const forced = await prefs.get(OnboardingService.FORCE_LOGIN_KEY, false) as boolean;
      if (forced) {
        await prefs.delete(OnboardingService.FORCE_LOGIN_KEY);
        await prefs.flush();
      }
      return forced;
    } catch (err) {
      console.error('读取首次体验重启标记失败', err);
      return false;
    }
  }

  profileToUser(userId: string, nickname: string, profile: PersonalityProfile | null): User {
    const user = new User();
    user.userId = userId;
    user.name = nickname || user.name;
    if (profile) {
      user.profile = profile;
      user.profileCompleted = true;
      user.profileVersion = profile.version;
    }
    return user;
  }
}
