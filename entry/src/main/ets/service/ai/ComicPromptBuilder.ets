import { PersonalityProfile } from '../../model/Models';

export interface ComicStylePayload {
  tone: string;
  pace: string;
  visualStyle: string;
  focusTopics: string[];
  avoid: string[];
}

export class ComicPromptBuilder {
  static fromProfile(profile?: PersonalityProfile): ComicStylePayload {
    const value = profile || new PersonalityProfile();
    return {
      tone: value.tone || '温柔',
      pace: value.pace || '少打扰',
      visualStyle: value.comicStyle || '清新日常',
      focusTopics: value.focusTopics && value.focusTopics.length > 0 ? value.focusTopics : ['生活'],
      avoid: ['过度煽情', '敏感个人信息', '与事件无关的剧情']
    };
  }

  static styleKey(profile?: PersonalityProfile): string {
    const style = ComicPromptBuilder.fromProfile(profile);
    return `${style.visualStyle}|${style.tone}|${style.pace}`;
  }
}
