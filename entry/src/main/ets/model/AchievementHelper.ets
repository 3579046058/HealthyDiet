import { PreferenceHelper } from './PreferenceHelper';

// 成就等级定义
export class AchievementLevel {
  days: number = 0;
  name: string = '';
  description: string = '';
  icon: string = '';
  
  constructor(days: number, name: string, description: string, icon: string) {
    this.days = days;
    this.name = name;
    this.description = description;
    this.icon = icon;
  }
}

export const ACHIEVEMENT_LEVELS: AchievementLevel[] = [
  new AchievementLevel(7, '坚持一周', '连续7天健康生活', 'achievement_7'),
  new AchievementLevel(30, '坚持一月', '连续30天健康生活', 'achievement_30'),
  new AchievementLevel(100, '百日达人', '连续100天健康生活', 'achievement_100'),
  new AchievementLevel(200, '双百英雄', '连续200天健康生活', 'achievement_200'),
  new AchievementLevel(365, '年度冠军', '连续365天健康生活', 'achievement_365'),
  new AchievementLevel(500, '传奇人物', '连续500天健康生活', 'achievement_500'),
  new AchievementLevel(1000, '千日传奇', '连续1000天健康生活', 'achievement_1000')
];

export class AchievementInfo {
  days: number = 0;
  name: string = '';
  description: string = '';
  icon: string = '';
  unlocked: boolean = false;
  unlockDate: string = '';
  
  constructor(days: number, name: string, description: string, icon: string, unlocked: boolean, unlockDate: string = '') {
    this.days = days;
    this.name = name;
    this.description = description;
    this.icon = icon;
    this.unlocked = unlocked;
    this.unlockDate = unlockDate;
  }
}

export class AchievementHelper {
  private prefHelper: PreferenceHelper;

  constructor(prefHelper: PreferenceHelper) {
    this.prefHelper = prefHelper;
  }

  // 检查是否达到新的成就（返回新解锁的成就列表）
  async checkAchievements(currentStreak: number): Promise<AchievementInfo[]> {
    const unlockedDays = await this.prefHelper.getAchievementDays();
    const newAchievements: AchievementInfo[] = [];

    for (let i = 0; i < ACHIEVEMENT_LEVELS.length; i++) {
      const level = ACHIEVEMENT_LEVELS[i];
      // 如果当前连续天数达到该等级，且该等级尚未解锁
      if (currentStreak >= level.days && !unlockedDays.includes(level.days)) {
        // 解锁该成就
        unlockedDays.push(level.days);
        const today = new Date().toISOString().split('T')[0];
        
        // 保存解锁日期
        await this.prefHelper.setAchievementDate(level.days, today);
        
        newAchievements.push(new AchievementInfo(
          level.days,
          level.name,
          level.description,
          level.icon,
          true,
          today
        ));
      }
    }

    // 保存更新后的解锁列表
    if (newAchievements.length > 0) {
      await this.prefHelper.setAchievementDays(unlockedDays);
    }

    return newAchievements;
  }

  // 获取所有成就信息（包含解锁状态）
  async getAllAchievements(): Promise<AchievementInfo[]> {
    const unlockedDays = await this.prefHelper.getAchievementDays();
    const achievementDates = await this.prefHelper.getAchievementDates();
    const achievements: AchievementInfo[] = [];
    
    for (let i = 0; i < ACHIEVEMENT_LEVELS.length; i++) {
      const level = ACHIEVEMENT_LEVELS[i];
      const unlocked = unlockedDays.includes(level.days);
      const unlockDate = unlocked ? (achievementDates.get(level.days) || '') : '';
      achievements.push(new AchievementInfo(
        level.days,
        level.name,
        level.description,
        level.icon,
        unlocked,
        unlockDate
      ));
    }
    
    return achievements;
  }

  // 获取已解锁的成就数量
  async getUnlockedCount(): Promise<number> {
    const unlockedDays = await this.prefHelper.getAchievementDays();
    return unlockedDays.length;
  }

  // 获取下一个未解锁的成就
  async getNextAchievement(currentStreak: number): Promise<AchievementInfo | null> {
    const unlockedDays = await this.prefHelper.getAchievementDays();
    
    for (let i = 0; i < ACHIEVEMENT_LEVELS.length; i++) {
      const level = ACHIEVEMENT_LEVELS[i];
      if (!unlockedDays.includes(level.days)) {
        return new AchievementInfo(
          level.days,
          level.name,
          level.description,
          level.icon,
          false
        );
      }
    }
    
    return null; // 所有成就都已解锁
  }

  // 计算进度百分比
  async getProgressPercentage(currentStreak: number): Promise<number> {
    const nextAchievement = await this.getNextAchievement(currentStreak);
    if (!nextAchievement) {
      return 100; // 所有成就都已解锁
    }
    
    // 找到上一个已解锁的成就
    const unlockedDays = await this.prefHelper.getAchievementDays();
    let previousDays = 0;
    for (let i = 0; i < ACHIEVEMENT_LEVELS.length; i++) {
      const level = ACHIEVEMENT_LEVELS[i];
      if (unlockedDays.includes(level.days)) {
        previousDays = level.days;
      } else {
        break;
      }
    }
    
    const progress = ((currentStreak - previousDays) / (nextAchievement.days - previousDays)) * 100;
    return Math.min(Math.max(progress, 0), 100);
  }
}
