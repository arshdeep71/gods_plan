# God's Plan - Business Rules, Sync Logic, & Security Policies

This document details all business rules, mathematical calculations, database validation checks, cloud synchronization models, and security rules governing **God's Plan**.

---

## 1. Goal Setting & Timeline Rules

* **Goal Period Constraints**:
  * On initial setup, users must set a `StartDate` and `EndDate`.
  * **Constraint**: `EndDate` must be strictly after `StartDate`.
  * **Constraint**: `EndDate` cannot exceed 5 years from `StartDate`.
* **Progression Calculations**:
  * `TotalDays` = $EndDate - StartDate$ (in days).
  * `DaysElapsed` = $CurrentDate - StartDate$ (in days).
  * `DaysRemaining` = $EndDate - CurrentDate$ (in days).
  * `ProgressPercentage` = $\left( \frac{DaysElapsed}{TotalDays} \right) \times 100$.

---

## 2. Supabase Security & Row-Level Security (RLS) Rules

To secure user data on Supabase Free Tier, the database must enforce the following authorization rules:

1. **User Identity Isolation**:
   - Every cloud-backed table must contain a `user_id` column of type `uuid` pointing to `auth.users.id`.
   - **Constraint**: The `user_id` field must be set automatically on insert using the authenticated session context (`auth.uid()`).
2. **Access Control Policies**:
   - Read/Write policies must be enforced using Row-Level Security (RLS):
     ```sql
     ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
     
     CREATE POLICY "CRUD Operations Restricted to Owner" ON public.tasks
     FOR ALL TO authenticated
     USING (auth.uid() = user_id)
     WITH CHECK (auth.uid() = user_id);
     ```
   - These rules apply to all user-owned tables: `goals`, `tasks`, `workouts`, `sleep_logs`, `nutrition_logs`, `custom_foods`, `recipes`, `finance_ledger`, `learning_logs`, `social_interactions`.

---

## 3. Data Synchronization & Conflict Resolution Rules

Since the application is designed to be fully functional offline, data must sync automatically when network access returns.

### A. Offline Mutations Queue
* When the client performs a database write (Insert, Update, Delete) while offline:
  1. The client executes the action directly against the **Local Cache** (SQLite/Hive) immediately.
  2. The action is formatted as a SQL command or JSON transaction object and appended to the local `offline_sync_queue` table with a timestamp, transaction ID, and sequence number.
* When the internet connection is restored:
  1. The client reads the `offline_sync_queue` in ascending sequence order.
  2. Executes each query against the Supabase backend database sequentially.
  3. Once successful, removes the entry from `offline_sync_queue`.

### B. Conflict Resolution (Last-Write-Wins)
* Every table contains `created_at` (UTC) and `updated_at` (UTC) columns.
* When merging local records with remote Supabase records:
  - Compare the `updated_at` timestamp of the local cached record with the remote record.
  - If $\text{updated\_at}_{\text{local}} > \text{updated\_at}_{\text{remote}}$, write the local record to Supabase.
  - If $\text{updated\_at}_{\text{remote}} > \text{updated\_at}_{\text{local}}$, overwrite the local cache with the remote record.
  - If both are equal, do nothing.

---

## 4. User Authentication Rules

* **Sign Up Validation Rules**:
  * Email must match a valid regex pattern (`^[a-zA-Z0-9+_.-]+@[a-zA-Z0-9.-]+$`).
  * Password must be a minimum of 8 characters, containing at least one digit and one letter.
  * Username must be unique and between 3 and 20 characters.
* **Authentication Persistence**:
  * After a successful login, the Supabase JWT token is encrypted using a local AES key and saved in a Hive secure box.
  * On launch, the client reads the encrypted token. If the token is valid, it bypasses the login screen. If expired, it triggers a background refresh request. If the refresh token is also invalid, the user is redirected to log in.

---

## 5. Daily Tasks & Rewards System

* **Task Difficulty & Scoring Rules**:
  Completing a task awards Points and Coins:
  | Difficulty | Points Awarded | Coins Awarded |
  | :--- | :--- | :--- |
  | **Easy** | +10 pts | +10 coins |
  | **Medium** | +25 pts | +25 coins |
  | **Hard** | +50 pts | +50 coins |

* **Task Streak Calculation**:
  * A task streak increases by +1 for every consecutive day the user completes 100% of their "Daily Recurring" or "Must-Do" tasks.
  * If a user fails to complete a daily recurring task by 11:59 PM (local time), the task streak resets to `0`.

---

## 6. Fitness & Energy Calculation Rules

* **Daily Target Rule**: Default daily target is 30 minutes of active exercise.
* **MET Calorie Burn formula**:
  $$\text{Calories Burned} = \text{Duration (mins)} \times \left( \frac{\text{MET} \times 3.5 \times \text{Weight (kg)}}{200} \right)$$
  *MET baselines*: Running: 9.8 | Gym (Strength): 6.0 | Yoga: 2.5 | Sports: 8.0 | Walking: 3.5.

---

## 7. Nutrition & Water Intake Rules

* **Daily Caloric Target (BMR & TDEE Calculations)**:
  $$\text{BMR} = 88.362 + (13.397 \times \text{Weight}_{\text{kg}}) + (4.799 \times \text{Height}_{\text{cm}}) - (5.677 \times \text{Age}_{\text{years}})$$
  $$\text{TDEE} = \text{BMR} \times \text{Activity Factor (Sedentary: 1.2 | Light: 1.375 | Moderate: 1.55 | Active: 1.725)}$$
* **Goal-Based Adjustments**:
  * Muscle Building: $\text{Target Calories} = \text{TDEE} + 300\text{ kcal}$.
  * Fat Loss: $\text{Target Calories} = \text{TDEE} - 500\text{ kcal}$.
* **Default Macronutrient Split (Muscle Building)**:
  * Protein: $2.0\text{g per kg of body weight}$ (approx. $0.9\text{g per lb}$).
  * Fats: $25\%$ of total calories.
  * Carbohydrates: Remaining calories.
* **Water Targets**: Default target is 8 glasses ($2.4\text{L}$). Add +1 glass ($300\text{ml}$) for every 30 minutes of active exercise logged.

---

## 8. Sleep & Lifestyle Rules

* **Sleep Target**: Default is 8 hours of sleep per night.
* **Sleep Quality Index (1-10)**:
  User self-reports quality, modified by these factors:
  * Caffeine logged after 3:00 PM: $-1.5$ points.
  * Screen time logged in bed ($<30$ mins before sleep): $-1$ point.
  * Dinner logged within 2 hours of Bedtime: $-0.5$ points.
  * Exercise logged during the day: $+0.5$ points.

---

## 9. Local Deterministic AI Coach Rules (100% Free)

To eliminate the need for paid AI API costs, the **AI Coach** operates entirely locally using a deterministic heuristics engine. It scans local SQLite/Hive database aggregates daily to trigger advice blocks:

* **Trigger (Protein Low)**:
  * *Condition*: Protein logged yesterday $< 80\%$ of target.
  * *Heuristic Tip*: `"Your protein intake was low yesterday (Xg logged vs Yg target). Consider adding eggs, Greek yogurt, or chicken breast to your meals today."`
* **Trigger (Sleep Quality Decline)**:
  * *Condition*: Average sleep quality score drops $\ge 2$ points over 3 days.
  * *Heuristic Tip*: `"Your sleep quality has declined. The data shows screen time was logged close to bedtime on these days. Try placing your phone away 30 minutes before sleep tonight."`
* **Trigger (Urge Window warning)**:
  * *Condition*: Urge logs show clusters between 3:00 PM and 5:00 PM.
  * *Heuristic Tip*: `"You commonly experience cravings between 3:00 PM and 5:00 PM. Plan a workout session or call a friend during this window today to stay strong."`
