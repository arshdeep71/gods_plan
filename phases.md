# God's Plan - Implementation Phases & Build Timeline

This document defines the 10 implementation phases spanning a 12-week build plan to develop, synchronize, compile, and sideload **God's Plan** for iOS using **Supabase** and **GitHub Actions**.

---

```mermaid
gantt
    title God's Plan 12-Week Build Timeline (Supabase & Sideloadly)
    dateFormat  YYYY-MM-DD
    section Backend & Core
    Phase 1: Project Setup & Auth  :active, p1, 2026-07-13, 14d
    section Core Features & Sync
    Phase 2: Tasks & Sync Engine   : p2, after p1, 7d
    Phase 3: Exercise, Sleep & Sync: p3, after p2, 7d
    Phase 4: Nutrition & Local DB  : p4, after p3, 14d
    Phase 5: No Fap, Finance & Sync: p5, after p4, 7d
    Phase 6: Social & Learning     : p6, after p5, 7d
    section Offline Systems
    Phase 7: Heuristic AI & Notify : p7, after p6, 7d
    Phase 8: Charts & Analytics    : p8, after p7, 7d
    Phase 9: Performance Polish     : p9, after p8, 7d
    section Deployment
    Phase 10: CI/CD & Sideloading  : p10, after p9, 7d
```

---

## Phase 1: Project Setup & Auth (Weeks 1-2)

Initialize the Flutter project environment, integrate database dependencies, and construct user authentication interfaces linked to Supabase.

### Key Deliverables
* Flutter project skeleton.
* Packages integrated: `supabase_flutter`, `provider`, `hive_flutter`, `uuid`, and `intl`.
* Supabase project setup, SQL database tables schema configuration, and Row-Level Security (RLS) policies.
* User Sign Up, Login, and onboarding Goal Date Setup screen flows.
* App logo configuration: Setup app launcher icon using the 1:1 ratio square logo sourced from the `assets/` directory (`app_logo_1.jpg` or `app_logo_2.jpg`).

### Core Files
* `lib/main.dart`
* `lib/services/supabase_service.dart`
* `lib/services/database_service.dart`
* `lib/providers/auth_provider.dart`
* `lib/screens/auth/login_screen.dart`
* `lib/screens/auth/signup_screen.dart`
* `lib/screens/goal_setup.dart`

### Verification Criteria
* **Automated Tests**: Confirm email validation and password constraint parsing functions.
* **Manual Verification**: Run simulator, sign up a test account, confirm that RLS fields map user IDs accurately in Supabase Dashboard, and check that local tokens persist across app restarts.

---

## Phase 2: Tasks & Sync Engine (Weeks 2-3)

Build the task logging interface and implement the core bi-directional sync and offline transaction queue engine.

### Key Deliverables
* SQLite task table creation.
* Offline queue table (`offline_sync_queue`) managing mutations when network connection is severed.
* Task checklist UI allowing task completions, priority categorization, and difficulty mapping.
* Sync logic flushing pending mutations to Supabase when network is detected.

### Core Files
* `lib/models/task.dart`
* `lib/models/sync_item.dart`
* `lib/services/sync_service.dart`
* `lib/providers/task_provider.dart`
* `lib/screens/tasks/tasks_view.dart`

### Verification Criteria
* **Automated Tests**: Mock network failures and verify updates queue correctly locally. Test LWW conflict merges.
* **Manual Verification**: Disconnect device from internet, add and complete tasks, reconnect to internet, and check that local updates sync to the Supabase database automatically.

---

## Phase 3: Exercise & Sleep (Weeks 3-4)

Implement physical training logs, sleep tracking calculators, and sync their states with Supabase remote tables.

### Key Deliverables
* Exercise metrics, duration calculators, and MET energy calculations.
* Sleep duration boundary logic with midnight-rollover corrections.
* Self-reporting forms for sleep factors.
* Setup exercise and sleep databases on SQLite cache and mirror schemas in Supabase.

### Core Files
* `lib/models/exercise.dart`
* `lib/models/sleep.dart`
* `lib/providers/fitness_provider.dart`
* `lib/providers/sleep_provider.dart`
* `lib/screens/exercise/exercise_view.dart`
* `lib/screens/sleep/sleep_view.dart`

### Verification Criteria
* **Automated Tests**: Assert MET calculations evaluate correct active calories burned under moderate/high intensities.
* **Manual Verification**: Log workout sessions and sleep profiles, verifying data registers locally and remote rows populate correctly in Supabase.

---

## Phase 4: Nutrition & Food (Weeks 4-6)

Populate the local food library database, write meal recorders, and configure custom recipes.

### Key Deliverables
* Seed local SQLite instance with 4000+ foods.
* Macro target calculator based on weight, height, age, activity level, and goals.
* Meal search engine interface, custom food creator, and multi-ingredient recipe builder.
* Database synchronization mappings for food logs and custom entries.

### Core Files
* `lib/models/nutrition.dart`
* `lib/providers/nutrition_provider.dart`
* `lib/screens/nutrition/nutrition_view.dart`
* `lib/screens/nutrition/recipe_builder.dart`

### Verification Criteria
* **Automated Tests**: Benchmark local database search speed (ensure query results execute in under 100ms).
* **Manual Verification**: Search for foods, save customized recipes, and verify total calorie/macro metrics display correctly.

---

## Phase 5: No Fap & Money (Weeks 6-7)

Create temptation logs, clean streak counters, and financial ledgers synced with cloud tables.

### Key Deliverables
* Temptation/Urge trackers logging timing patterns, triggers, and relief tactics.
* Financial ledger recording Income/Expense transactions.
* Daily budget metrics automatically computing adjusted savings targets.

### Core Files
* `lib/models/addiction.dart`
* `lib/models/finance.dart`
* `lib/providers/addiction_provider.dart`
* `lib/providers/finance_provider.dart`
* `lib/screens/addiction/addiction_view.dart`
* `lib/screens/finance/finance_view.dart`

### Verification Criteria
* **Automated Tests**: Confirm relapses reset the streak to `0` and record history correctly. Verify daily savings logic updates if budget targets are altered.
* **Manual Verification**: Input logs for expenses and urges, verifying clean streaks update and net savings indicators adjust accordingly.

---

## Phase 6: Social & Learning (Weeks 7-8)

Record academic goals, study hours, and track friend contact frequencies.

### Key Deliverables
* Subject setup cards and study duration trackers.
* Friend log recording contact dates and displaying status alerts for cooling/neglected contacts.
* SQLite schemas and Supabase table sync for learning and social contacts.

### Core Files
* `lib/models/social.dart`
* `lib/models/learning.dart`
* `lib/providers/learning_provider.dart`
* `lib/screens/social/social_view.dart`
* `lib/screens/learning/learning_view.dart`

### Verification Criteria
* **Automated Tests**: Assert social alerts trigger on contacts exceeding 10 days of zero contact.
* **Manual Verification**: Edit contact histories to simulate a 12-day silence and confirm red warnings display on the dashboard.

---

## Phase 7: Heuristic AI & Reminders (Weeks 8-9)

Deploy the local heuristic rules engine and schedule native local reminders.

### Key Deliverables
* Local rules engine scans database summaries to trigger advice items without external API costs.
* Local scheduler managing reminder alerts (6:00 AM, 5:00 PM, 6:00 PM, 7:00 PM, 8:00 PM, 9:00 PM).

### Core Files
* `lib/services/ai_service.dart`
* `lib/services/notification_service.dart`
* `lib/screens/widgets/ai_coach_card.dart`

### Verification Criteria
* **Automated Tests**: Confirm rules engine produces matching outputs under bad sleep or low protein mock states.
* **Manual Verification**: Induce artificial low protein/sleep stats in user cache and confirm the AI Coach displays correct advice cards.

---

## Phase 8: Charts & Analytics (Weeks 9-10)

Build graphical compliance summaries, XP counters, and level progression trackers.

### Key Deliverables
* Weekly/monthly compliance reports rendering via `fl_chart`.
* XP and Badge managers checking achievements against database totals.
* Level progression widgets.

### Core Files
* `lib/services/analytics_service.dart`
* `lib/screens/widgets/charts.dart`
* `lib/screens/dashboard/badges_view.dart`

### Verification Criteria
* **Automated Tests**: Confirm XP increases trigger correct level advancement equations.
* **Manual Verification**: Achieve badge conditions and check that success modals display.

---

## Phase 9: Performance Polish (Weeks 10-11)

Verify absolute offline stability and polish layout transitions.

### Key Deliverables
* Offline mode verification (validate entire application behaves without active connections, showing zero exceptions).
* Performance tracing to verify smooth 60fps widget rendering.
* Accessibility styling check.

### Core Files
* `lib/utils/colors.dart`
* `lib/utils/constants.dart`

### Verification Criteria
* **Manual Verification**: Toggle phone to airplane mode, run every application module, write logs, and confirm no app lockups occur.

---

## Phase 10: CI/CD & Sideloading (Weeks 11-12)

Automate compilation via GitHub Actions and deploy unsigned IPA files via Windows Sideloadly.

### Key Deliverables
* Configure `.github/workflows/build_ios_ipa.yml` to trigger builds on repository changes.
* Complete unsigned compilation using Apple virtual runners.
* Sideload the unsigned binary directly to an iOS device.

### Detailed Deployment Workflow
1. **GitHub Commit**: Commit project code to a GitHub repository, ensuring the `.github/workflows/build_ios_ipa.yml` is present in the root.
2. **Auto Compilation**: On push, GitHub Actions spins up a virtual `macos-14` cloud runner to compile the unsigned IPA (`app.ipa`) as a project artifact.
3. **Artifact Download**: Visit the **Actions** tab in the GitHub repo, select the successful run, and download the `iptv-ios-app` folder containing the `app.ipa` file to your Windows PC.
4. **Sideloadly Preparation**: Install official Apple iTunes and iCloud drivers on Windows. Open Sideloadly.
5. **Install on iOS**:
   * Connect the iPhone to the PC via USB and trust the computer.
   * Drag the downloaded `app.ipa` into Sideloadly.
   * Input your Apple ID email.
   * Click **Start** and input your Apple ID password to sign the application.
   * Wait for Sideloadly to display `Done`.
6. **Trust Profile**: On the iPhone, navigate to `Settings > General > VPN & Device Management`, select your Apple ID under Developer App, and tap **Trust**.
7. **Launch & Use**: Open the application! Refresh via Sideloadly every 7 days (free Apple account limit) to preserve local cache data.
