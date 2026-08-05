import { describe, it, expect } from '@ohos/hypium';
import { FoodCalories, ThemeColors, ThemeManager } from '../main/ets/common/Constants';

export default function coreLogicTest() {
  describe('FoodCaloriesTest', () => {
    it('lookupKnownFood', 0, () => {
      const per100 = FoodCalories.lookupCaloriesPer100g('米饭');
      expect(per100).assertEqual(116);
    });

    it('lookupUnknownFoodReturnZero', 0, () => {
      const per100 = FoodCalories.lookupCaloriesPer100g('不存在的食物XYZ');
      expect(per100).assertEqual(0);
    });

    it('calcCaloriesByGrams', 0, () => {
      // 米饭 116 千卡/100g，200g 应为 232
      const cal = FoodCalories.calcCalories('米饭', 200);
      expect(cal).assertEqual(232);
    });

    it('calcCaloriesZeroGrams', 0, () => {
      const cal = FoodCalories.calcCalories('苹果', 0);
      expect(cal).assertEqual(0);
    });
  });

  describe('ThemeTest', () => {
    it('darkThemeColors', 0, () => {
      expect(ThemeColors.text('dark')).assertEqual('#FFFFFF');
      expect(ThemeColors.bg('dark')).assertEqual('#121212');
    });

    it('lightThemeColors', 0, () => {
      expect(ThemeColors.text('light')).assertEqual('#1A1A1A');
      expect(ThemeColors.bg('light')).assertEqual('#F5F5F5');
    });

    it('themeManagerConsistency', 0, () => {
      expect(ThemeManager.txt('dark')).assertEqual(ThemeColors.textPrimary('dark'));
      expect(ThemeManager.sub('light')).assertEqual(ThemeColors.textSecondary('light'));
    });
  });
}
