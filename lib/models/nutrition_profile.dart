class NutritionProfile {
  final double weightKg;
  final double heightCm;
  final int ageYears;
  final String activityFactor; // 'sedentary', 'light', 'moderate', 'active'
  final String goal; // 'muscle_building', 'fat_loss'

  NutritionProfile({
    required this.weightKg,
    required this.heightCm,
    required this.ageYears,
    required this.activityFactor,
    required this.goal,
  });

  // Default initial profile
  factory NutritionProfile.defaultProfile() {
    return NutritionProfile(
      weightKg: 70.0,
      heightCm: 175.0,
      ageYears: 25,
      activityFactor: 'moderate',
      goal: 'muscle_building',
    );
  }

  // BMR = 88.362 + (13.397 * Weight) + (4.799 * Height) - (5.677 * Age)
  double get bmr {
    return 88.362 + (13.397 * weightKg) + (4.799 * heightCm) - (5.677 * ageYears);
  }

  // TDEE = BMR * Activity Factor
  double get tdee {
    double factor;
    switch (activityFactor.toLowerCase()) {
      case 'sedentary':
        factor = 1.2;
        break;
      case 'light':
        factor = 1.375;
        break;
      case 'active':
        factor = 1.725;
        break;
      case 'moderate':
      default:
        factor = 1.55;
    }
    return bmr * factor;
  }

  // Dynamic caloric target based on goal setting
  double get targetCalories {
    if (goal.toLowerCase() == 'fat_loss') {
      return tdee - 500.0;
    } else {
      // Default: muscle_building
      return tdee + 300.0;
    }
  }

  // Macros splits calculations:
  // Protein: 2.0g per kg of body weight
  double get targetProteinGrams => weightKg * 2.0;

  // Fats: 25% of total calories (1g fat = 9 kcal)
  double get targetFatGrams => (targetCalories * 0.25) / 9.0;

  // Carbohydrates: Remaining calories (1g carb = 4 kcal)
  double get targetCarbGrams {
    final proteinKcal = targetProteinGrams * 4.0;
    final fatKcal = targetCalories * 0.25;
    final remainingKcal = targetCalories - proteinKcal - fatKcal;
    return remainingKcal > 0 ? remainingKcal / 4.0 : 0.0;
  }

  // Serialization mapping for Hive
  Map<String, dynamic> toJson() {
    return {
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'age_years': ageYears,
      'activity_factor': activityFactor,
      'goal': goal,
    };
  }

  factory NutritionProfile.fromJson(Map<String, dynamic> json) {
    return NutritionProfile(
      weightKg: (json['weight_kg'] as num).toDouble(),
      heightCm: (json['height_cm'] as num).toDouble(),
      ageYears: json['age_years'] as int,
      activityFactor: json['activity_factor'] as String,
      goal: json['goal'] as String,
    );
  }
}
