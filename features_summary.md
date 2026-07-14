# God's Plan - Personal Life Operating System (Detailed Feature Specification)

Welcome to the full feature specification for **God's Plan**. This document covers every single user-facing feature, mathematical calculation, XP reward metric, security control, and offline database synchronization rule implemented in the system.

---

## 1. Core Architecture & Database Engine
*   **Offline-First Strategy**: The application acts as a local-first client. All reads and writes happen instantly on the device, ensuring the UI is highly responsive and works offline without internet dependencies.
*   **SQLite Storage Layer (`sqflite`)**: Stores relational user logs:
    *   Workouts, Sleep logs, Food logs, Water intake logs, Addiction logs, Finance transactions, Study logs, Tasks, and Social contacts.
*   **Hive Key-Value Cache**: Manages settings, flags, and persistent configuration:
    *   `settingsBox`: Onboarding state (`is_onboarded`), goal period (`goal_start_date`, `goal_end_date`), theme preferences, passcode locks (`is_passcode_enabled`, `app_passcode`), and badge unlocks.
*   **Conflict-Resistant Synchronization (`SyncService`)**:
    *   Pipes local changes to a database mutation queue.
    *   Once a connection is established, changes are sent to **Supabase** via `upsert` queries with `onConflict` clauses to avoid duplicate constraints.
    *   Performs timestamp-based resolution to merge data updated across multiple devices.

---

## 2. Onboarding & Journey Management
*   **Goal Cycle Settings**:
    *   Allows you to establish a timeline (Start Date & End Date) for your self-improvement cycle.
    *   Restricts start and end dates dynamically: Start Date must be within a year, and End Date must be after the Start Date up to a maximum of 5 years.
*   **Journey Progress Gauge**:
    *   Displays progress dynamically: `(Days Elapsed / Total Days) * 100`.
    *   Calculates and showcases **Days Elapsed** and **Days Remaining** on the dashboard.
    *   Helps maintain user focus with a visual linear progress bar.

---

## 3. Gamification, Leveling & XP Engine
The gamification engine calculates actions and updates levels:
*   **Level Calculation Formula**: `Level = (Total XP / 1000) + 1`
*   **XP Earning Events**:
    *   **Tasks**: Complete Easy (+10 XP), Medium (+20 XP), Hard (+50 XP).
    *   **Workouts**: +1 XP per active minute, +5 XP per 100 calories burned.
    *   **Sleep**: +50 XP for sleeping > 7 hours with sleep score > 7.5.
    *   **Water**: +2 XP per glass logged (+20 XP bonus on hitting daily target of 8 glasses).
    *   **Nutrition**: +10 XP for logging a meal.
    *   **Addiction**: +10 XP for logging urges (successfully resisting triggers).
    *   **Finance**: +10 XP for logging transactions, +30 XP bonus if daily savings target is achieved.
    *   **Learning**: +2 XP per study minute logged.
    *   **Social**: +30 XP for reaching out to a neglected contact.

### Badges & Achievements
*   **Early Bird**: Unlocked by logging a sleep quality index > 8.5/10.
*   **Hydration Hero**: Unlocked by drinking 8 or more glasses of water in a single day.
*   **Saver Master**: Unlocked by hitting your daily savings goal.
*   **Clean Slate**: Unlocked by maintaining a 7-day clean streak in the Sobriety Tracker.

---

## 4. Modules Specification

### 📋 Tasks Checklist Module
*   **Task Creation**:
    *   Fields: Title, Priority dropdown (Low, Medium, High), Difficulty dropdown (Easy, Medium, Hard), and Recurring toggle.
*   **Priority Categorization**:
    *   Filter tasks in tabs: "All", "High", "Medium", "Low".
*   **Recurring Routines**:
    *   If marked recurring, tasks automatically reset daily at midnight to help you build consistency.
*   **Task Streaks**:
    *   Every consecutive day you complete a recurring task increments its streak.
*   **Multipliers & XP**: Completing higher difficulty tasks grants higher XP multipliers.
*   **Swipe to Delete**: Swipe a task left to instantly remove it from local cache and sync queue.

### 🏃 Exercise & Workout Tracker
*   **Workout Log Form**:
    *   Fields: Activity type (Running, Strength, Yoga, Sports, Walking), Duration (minutes), Weight (kg), and Calories Burned.
*   **Target Active Time Indicator**:
    *   Circular ring visualizer showing actual logged minutes today against the default 30-minute target.
*   **History Logs**:
    *   Displays list of recent exercises with calculated calories-per-minute statistics.

### 🛌 Sleep Tracker
*   **Sleep Log Form**:
    *   Fields: Sleep Date/Time, Wake Date/Time, reported subjective sleep quality (1-10 slider), and three hygiene checklist toggles.
*   **Sleep Quality Index (SQI) Formula**:
    *   Base Score: `(Hours Slept / 8.0) * 10` (capped at 10.0).
    *   Hygiene Penalties:
        *   Caffeine consumed after 3:00 PM: `-1.5 points`
        *   Used phone/screen in bed: `-2.0 points`
        *   Ate late dinner: `-1.0 points`
    *   Final Calculated SQI: `Base Score - Penalties` (bounded between 0.0 and 10.0).
*   **Logs**: Shows sleep duration, wake timing, and color-coded score circles (Green = Great, Amber = Medium, Red = Poor).

### 🍏 Nutrition & Water
*   **Food Logging**:
    *   Fields: Food Name, Calories (kcal), Protein (g), Carbs (g), and Fats (g).
*   **Calorie Target Visualizer**:
    *   Linear progress tracker showing total calories logged today vs. daily calorie budget.
*   **Macronutrient Bar Charts**:
    *   Individual bar meters showing protein, carbohydrate, and fat intakes compared against nutritional goals.
*   **Water Tracker Widget**:
    *   Tap `+` or `-` buttons to increment water intake by the glass.
    *   Displays target count (e.g., target 8 glasses) and tracks daily progress.

### 🔥 Sobriety & Addiction Tracker
*   **Urge/Relapse Log Form**:
    *   Fields: Current feeling, urge level (1-10 scale), trigger category tag (Stress, Boredom, Social, Routine, etc.), helper strategy used to bypass urge, notes, and a "Relapse" checkbox.
*   **Dynamic Streak Counters**:
    *   **Current Streak**: Computes days elapsed since the most recent relapse log (or since your goal start date if no relapse is logged).
    *   **Longest Streak**: Evaluates all historical relapse logs, calculates the gaps between them, and persists the maximum clean streak.
*   **Urge Index Chart**:
    *   Visual representation of recent urges to help you identify repeating trigger tags and patterns.

### 💰 Money & Finance
*   **Transaction Logging**:
    *   Fields: Type toggle (Income or Expense), Category dropdown (Salary, Food, Rent, Entertainment, Bills, Investment, etc.), Amount, and notes.
*   **Daily Savings Target**:
    *   Custom daily savings target input in options.
*   **Daily Surplus/Deficit Overview**:
    *   Displays `Daily Income - Daily Expenses` vs. your Savings Target.
    *   Alerts you with color indicators (Green for savings target met, Red for overspending).

### 📚 Learning & Skills
*   **Subject Creation**:
    *   Fields: Subject Name, daily study target (minutes), and lifetime study target (hours).
*   **Study Logs**:
    *   Select a subject and log the minutes studied.
*   **Progress Indicators**:
    *   Tracks daily completion percentages and counts total hours logged toward mastering a skill (e.g., *"10 hours logged of 100-hour goal"*).

### 🤝 Social Connections
*   **Contacts Logging**:
    *   Fields: Contact Name, Last Contacted Date/Time, and notes.
*   **Relationship Health Alert**:
    *   The app calculates: `Days Since Last Contact = Today - Last Contacted Date`.
    *   If the contact has not been contacted for more than **7 days**, they are highlighted in **Red** as a "Neglected Connection" on the UI to remind you to check in.

---

## 5. App Security & Settings
*   **Passcode Lock Screen**:
    *   Secures the app with a 4-digit passcode.
    *   If enabled in settings, the lock screen displays immediately on app startup, blocking access to all modules until the correct code is entered.
*   **Data Management**:
    *   **Clear Local Cache**: Wipes all local SQLite tables and Hive boxes, allowing you to start fresh.
