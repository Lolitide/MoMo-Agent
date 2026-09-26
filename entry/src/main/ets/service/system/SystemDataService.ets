/*
 * ============================================================================
 * 文件名：service/system/SystemDataService.ets
 * ============================================================================
 * 【用途】系统数据服务：读取日历、待办、备忘录等系统数据，供 EventRepository 调用
 * 【前置条件 / 假设】
 *   - 依赖：@kit.CalendarKit、@kit.ReminderAgentKit；
 *   - 假设：权限已在 module.json5 声明且用户已授权；首次调用时请求权限。
 * 【输入 / 输出（后置条件）】
 *   - 输入：日期范围（起止时间戳）；
 *   - 输出：标准化的事件对象数组（含标题、时间、分类、描述）；
 *   - 后置：权限被拒时返回空数组（优雅降级）。
 * 【关键类 / 算法】
 *   - calendarManager: 查询指定日期的日历事件；
 *   - reminderAgent: 查询待办提醒（ReminderType.TIMER/ALARM）；
 *   - 数据归一化：将不同来源的数据转换为统一的 SystemEvent 格式。
 * 【参考源】
 *   - HarmonyOS CalendarKit 文档、ReminderAgentKit 文档
 * ============================================================================
 */

import { calendarManager } from '@kit.CalendarKit';
import { reminderAgentManager } from '@kit.BackgroundTasksKit';
import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

export interface SystemEvent {
  id: string;
  title: string;
  time: string;
  category: string;
  description: string;
  source: 'calendar' | 'reminder' | 'memo';
}

export class SystemDataService {
  private static instance: SystemDataService | null = null;
  private calendarMgr: calendarManager.CalendarManager | null = null;
  private hasCalendarPermission: boolean = false;
  private hasReminderPermission: boolean = false;

  static get(): SystemDataService {
    if (SystemDataService.instance === null) {
      SystemDataService.instance = new SystemDataService();
    }
    return SystemDataService.instance;
  }

  /**
   * 初始化服务（请求权限）
   */
  async initialize(context: Context): Promise<void> {
    await this.requestPermissions(context);

    if (this.hasCalendarPermission) {
      try {
        this.calendarMgr = calendarManager.getCalendarManager(context);
      } catch (err) {
        const error = err as BusinessError;
        console.error(`初始化日历管理器失败: ${error.message}`);
      }
    }
  }

  /**
   * 请求必要的系统权限
   */
  private async requestPermissions(context: Context): Promise<void> {
    const atManager = abilityAccessCtrl.createAtManager();
    const permissions: Permissions[] = [
      'ohos.permission.READ_CALENDAR',
      'ohos.permission.READ_WHOLE_CALENDAR',
      'ohos.permission.PUBLISH_AGENT_REMINDER'
    ];

    try {
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
        context,
        permissions
      );

      // 检查每个权限的授权结果
      for (let i = 0; i < result.permissions.length; i++) {
        const perm = result.permissions[i];
        const granted = result.authResults[i] === 0;

        if (perm.includes('CALENDAR')) {
          this.hasCalendarPermission = this.hasCalendarPermission || granted;
        } else if (perm.includes('REMINDER')) {
          this.hasReminderPermission = granted;
        }
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`权限请求失败: ${error.message}`);
    }
  }

  /**
   * 获取指定日期的所有系统事件
   * @param date 目标日期（默认今天）
   * @returns Promise<SystemEvent[]> 系统事件数组
   */
  async getTodayEvents(date: Date = new Date()): Promise<SystemEvent[]> {
    const events: SystemEvent[] = [];

    // 1. 读取日历事件
    const calendarEvents = await this.getCalendarEvents(date);
    events.push(...calendarEvents);

    // 2. 读取待办提醒
    const reminders = await this.getReminders(date);
    events.push(...reminders);

    // 3. 按时间排序
    events.sort((a, b) => {
      if (a.time < b.time) return -1;
      if (a.time > b.time) return 1;
      return 0;
    });

    return events;
  }

  /**
   * 读取日历事件
   */
  private async getCalendarEvents(date: Date): Promise<SystemEvent[]> {
    if (!this.hasCalendarPermission || !this.calendarMgr) {
      return [];
    }

    try {
      // 获取默认日历账户
      const calendars = await this.calendarMgr.getAllCalendars();
      if (calendars.length === 0) {
        return [];
      }

      const events: SystemEvent[] = [];

      // 查询当天的事件（00:00 - 23:59）
      const startOfDay = new Date(date);
      startOfDay.setHours(0, 0, 0, 0);
      const endOfDay = new Date(date);
      endOfDay.setHours(23, 59, 59, 999);

      for (const calendar of calendars) {
        try {
          const filter = calendarManager.EventFilter.filterByTime(
            startOfDay.getTime(),
            endOfDay.getTime()
          );
          const calendarEvents = await calendar.getEvents(filter);

          for (const event of calendarEvents) {
            events.push({
              id: `cal_${event.id}`,
              title: event.title || '无标题事件',
              time: this.formatTime(new Date(event.startTime)),
              category: this.categorizeCalendarEvent(event),
              description: event.description || '',
              source: 'calendar'
            });
          }
        } catch (err) {
          const error = err as BusinessError;
          console.error(`查询日历失败: ${error.message}`);
        }
      }

      return events;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`读取日历事件失败: ${error.message}`);
      return [];
    }
  }

  /**
   * 读取待办提醒
   */
  private async getReminders(date: Date): Promise<SystemEvent[]> {
    if (!this.hasReminderPermission) {
      return [];
    }

    try {
      const reminders = await reminderAgentManager.getValidReminders();
      const events: SystemEvent[] = [];

      const targetDay = this.formatDate(date);

      for (const reminder of reminders) {
        // 只获取当天的提醒
        const reminderTime = this.getReminderTime(reminder);
        if (reminderTime && this.formatDate(reminderTime) === targetDay) {
          events.push({
            id: `rem_${reminder.notificationId || 0}`,
            title: reminder.title || '待办事项',
            time: this.formatTime(reminderTime),
            category: 'todo',
            description: reminder.content || '',
            source: 'reminder'
          });
        }
      }

      return events;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`读取提醒失败: ${error.message}`);
      return [];
    }
  }

  /**
   * 从提醒对象中提取时间
   */
  private getReminderTime(reminder: reminderAgentManager.ReminderRequest): Date | null {
    try {
      if (reminder.reminderType === reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR) {
        const calendarReminder = reminder as reminderAgentManager.ReminderRequestCalendar;
        const dt = calendarReminder.dateTime;
        return new Date(
          dt.year,
          dt.month - 1,
          dt.day,
          dt.hour,
          dt.minute
        );
      } else if (reminder.reminderType === reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER) {
        const timerReminder = reminder as reminderAgentManager.ReminderRequestTimer;
        return new Date(timerReminder.triggerTimeInSeconds * 1000);
      } else if (reminder.reminderType === reminderAgentManager.ReminderType.REMINDER_TYPE_ALARM) {
        const alarmReminder = reminder as reminderAgentManager.ReminderRequestAlarm;
        const alarmTime = new Date();
        alarmTime.setHours(alarmReminder.hour, alarmReminder.minute, 0, 0);
        return alarmTime;
      }
    } catch (err) {
      const error = err as BusinessError;
      console.error(`解析提醒时间失败: ${error.message}`);
    }
    return null;
  }

  /**
   * 分类日历事件
   */
  private categorizeCalendarEvent(event: calendarManager.Event): string {
    const title = (event.title || '').toLowerCase();
    const desc = (event.description || '').toLowerCase();
    const text = title + ' ' + desc;

    if (text.includes('会议') || text.includes('meeting')) {
      return 'work';
    } else if (text.includes('学习') || text.includes('课程') || text.includes('study')) {
      return 'study';
    } else if (text.includes('运动') || text.includes('健身') || text.includes('锻炼')) {
      return 'health';
    } else if (text.includes('生日') || text.includes('纪念') || text.includes('anniversary')) {
      return 'important';
    }
    return 'life';
  }

  /**
   * 格式化时间为 HH:mm
   */
  private formatTime(date: Date): string {
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return `${h}:${m}`;
  }

  /**
   * 格式化日期为 YYYY-MM-DD
   */
  private formatDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

  /**
   * 检查是否有日历权限
   */
  hasPermissions(): boolean {
    return this.hasCalendarPermission || this.hasReminderPermission;
  }
}
