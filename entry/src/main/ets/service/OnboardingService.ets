import preferences from '@ohos.data.preferences';
import { CheckInGuideState, CheckInGuideStep, PersonalityProfile, User } from '../model/Models';
import { AuthService } from './auth/AuthService';

export class OnboardingService {
  private static instance: OnboardingService | null = null;
  private static readonly PREFS_NAME = 'momo_onboarding_v1';
  private static readonly PROFILE_PREFIX = 'profile_';
  private static readonly GUIDE_PREFIX = 'guide_';
  private static readonly PENDING_PREFIX = 'pending_';
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

  async loadGuide(userId: string): Promise<CheckInGuideState> {
    const state = new CheckInGuideState();
    if (!userId) {
      return state;
    }
    try {
      const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
      const raw = await prefs.get(OnboardingService.GUIDE_PREFIX + userId, '') as string;
      if (!raw) {
        return state;
      }
      const value = JSON.parse(raw) as CheckInGuideState;
      state.guideVersion = value.guideVersion || 1;
      state.currentStep = value.currentStep || CheckInGuideStep.CHECKIN_READY;
      state.completedAt = value.completedAt || 0;
      return state;
    } catch (err) {
      console.error('读取打卡引导状态失败', err);
      return state;
    }
  }

  async saveGuide(userId: string, state: CheckInGuideState): Promise<void> {
    if (!userId) {
      return;
    }
    const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
    await prefs.put(OnboardingService.GUIDE_PREFIX + userId, JSON.stringify(state));
    await prefs.flush();
  }

  async savePendingCheckIn(userId: string, text: string): Promise<void> {
    if (!userId) {
      return;
    }
    const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
    await prefs.put(OnboardingService.PENDING_PREFIX + userId, text);
    await prefs.flush();
  }

  async loadPendingCheckIn(userId: string): Promise<string> {
    if (!userId) {
      return '';
    }
    try {
      const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
      return await prefs.get(OnboardingService.PENDING_PREFIX + userId, '') as string;
    } catch (err) {
      console.error('读取待生成打卡失败', err);
      return '';
    }
  }

  async clearPendingCheckIn(userId: string): Promise<void> {
    if (!userId) {
      return;
    }
    const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
    await prefs.delete(OnboardingService.PENDING_PREFIX + userId);
    await prefs.flush();
  }

  async setGuideStep(userId: string, step: CheckInGuideStep): Promise<CheckInGuideState> {
    const state = await this.loadGuide(userId);
    state.currentStep = step;
    state.completedAt = step === CheckInGuideStep.COMPLETED ? Date.now() : 0;
    await this.saveGuide(userId, state);
    return state;
  }

  async resetGuide(userId: string): Promise<void> {
    const state = new CheckInGuideState();
    state.currentStep = CheckInGuideStep.CHECKIN_READY;
    await this.saveGuide(userId, state);
  }

  async restartFirstExperience(userId: string): Promise<void> {
    const prefs = await preferences.getPreferences(getContext(this), OnboardingService.PREFS_NAME);
    if (userId) {
      await prefs.delete(OnboardingService.PROFILE_PREFIX + userId);
      await prefs.delete(OnboardingService.GUIDE_PREFIX + userId);
      await prefs.delete(OnboardingService.PENDING_PREFIX + userId);
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
