# God's Plan - Personal Life Operating System

Welcome to **God's Plan**, a premium personal tracker and life operating system. The app is built as an offline-first mobile and web application using **Flutter**, powered by a local database (SQLite + Hive) and synced in the background to a secure cloud database (**Supabase**).

Below is the complete list of features and modules currently implemented in your application:

---

## 1. Gamification & Progression System
*   **XP (Experience Points) Engine**: Earn XP automatically by logging workouts, hitting sleep targets, drinking water, completing tasks, saving money, and studying.
*   **Leveling System**: Level up (`LVL 1`, `LVL 2`, etc.) based on your accumulated XP. 
*   **Badges Showcase**: An achievements panel displaying earned badges like:
    *   *Early Bird* (Sleep quality > 85%)
    *   *Hydration Hero* (Drank target water glasses)
    *   *Saver Master* (Achieved daily savings targets)
    *   *Clean Slate* (Addiction-free streaks)

---

## 2. Onboarding & Goal Period
*   **Goal Cycle Settings**: Set a dynamic start and end date for your current self-improvement journey.
*   **Journey Progress**: Visual timeline progress bar on the dashboard showing the elapsed vs. remaining days (e.g., *"Day 15 of 90"*).

---

## 3. Core Tracking Modules

### 📋 Tasks Checklist
*   **Multi-Priority Tasks**: Create tasks categorized by **Priority** (Low, Medium, High) and **Difficulty** (Easy, Medium, Hard).
*   **Difficulty Multipliers**: Harder tasks reward you with more XP.
*   **Recurring Tasks**: Toggle tasks to reset daily for establishing routines.
*   **Streak Tracking**: Real-time streak tracking for recurring tasks to maintain momentum.

### 🏃 Exercise Tracker
*   **Activity Logging**: Log different activity types (Running, Strength training, Yoga, Sports, Walking).
*   **Telemetry**: Track duration (minutes), weight (kg), and calories burned.
*   **Progress Indicators**: Circular progress widget tracking active minutes against the daily 30-minute target.

### 🛌 Sleep Tracker
*   **Sleep Quality Index (SQI)**: Calculate sleep quality based on sleep duration and sleep hygiene factors.
*   **Hygiene Checklists**: Log factors that negatively affect sleep:
    *   Caffeine consumption after 3:00 PM
    *   Screen time/phone usage in bed
    *   Late dinner/eating close to bedtime
*   **Analytics**: View sleep duration and calculated sleep score from the previous night.

### 🍏 Nutrition & Water
*   **Calorie Counter**: Log food items, calories, and macronutrient distributions (Protein, Carbs, Fats).
*   **Macronutrient Progress**: Visual bar gauges showing your protein, carb, and fat intake compared to targets.
*   **Hydration Tracker**: Easy click-to-log water glasses tracking target completion.

### 🔥 Sobriety & Addiction Tracker
*   **Urge Logging**: Log triggers, feelings, urge levels (1-10), and helpful coping strategies.
*   **Clean Counter**: Tracks your current and longest streak of sober days.
*   **Relapse Analysis**: Flag entries as relapses to reset streaks and analyze triggers.

### 💰 Money & Finance
*   **Transaction Logging**: Quick income and expense logger with custom category tags and notes.
*   **Daily Savings Target**: Set a daily savings goal.
*   **Savings Progress**: Real-time daily savings tracker showing if you are in surplus or deficit.

### 📚 Learning & Skills
*   **Subject Creation**: Add subjects you are studying with custom daily study minutes and total target hours.
*   **Study Session Timer**: Log minutes studied for each subject.
*   **Progress Gauges**: Tracks actual study time against daily and lifetime goals.

### 🤝 Social Connections
*   **Contact Management**: Add friends, family members, or professional contacts.
*   **Last Contacted Tracker**: Logs the exact timestamp when you last reached out.
*   **Neglected Friend Alert**: Flags contacts you haven't reached out to in a while to help you maintain relationships.

---

## 4. Settings & Security
*   **Passcode App Lock**: Turn on an optional security passcode lock screen to protect your logs from prying eyes.
*   **Data Control**: Clear local caches and reset onboarding settings directly from the settings menu.
