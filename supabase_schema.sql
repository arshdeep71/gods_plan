-- ==========================================
-- GOD'S PLAN - DATABASE SCHEMA SCHEMA INITIALIZATION
-- Run this script in your Supabase SQL Editor
-- ==========================================

-- 1. Create Public Profiles Table (Stores user metadata linked to Auth)
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT NOT NULL,
    email TEXT NOT NULL,
    xp INTEGER DEFAULT 0,
    streak_restores INTEGER DEFAULT 3,
    restored_dates TEXT[] DEFAULT '{}',
    last_restore_reset TEXT,
    app_lock_pin TEXT,
    daily_savings_target NUMERIC DEFAULT 500,
    monthly_savings_target NUMERIC DEFAULT 15000,
    big_savings_target NUMERIC DEFAULT 5000,
    nutrition_profile JSONB,
    xp_awarded_dates JSONB DEFAULT '{}',
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row-Level Security for profiles
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Allow users to view their own profile" 
ON public.profiles FOR SELECT 
TO authenticated 
USING (auth.uid() = id);

CREATE POLICY "Allow users to update their own profile" 
ON public.profiles FOR UPDATE 
TO authenticated 
USING (auth.uid() = id) 
WITH CHECK (auth.uid() = id);

CREATE POLICY "Allow users to insert their own profile" 
ON public.profiles FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = id);


-- 2. Create Goals Table (Stores start/end dates for user journey)
CREATE TABLE IF NOT EXISTS public.goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row-Level Security for goals
ALTER TABLE public.goals ENABLE ROW LEVEL SECURITY;

-- Goals Policies
CREATE POLICY "Allow users to select their own goals" 
ON public.goals FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Allow users to insert their own goals" 
ON public.goals FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to update their own goals" 
ON public.goals FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to delete their own goals" 
ON public.goals FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);


-- 3. Create Tasks Table (Stores checklist task items)
CREATE TABLE IF NOT EXISTS public.tasks (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_recurring BOOLEAN NOT NULL DEFAULT FALSE,
    repeat_type TEXT DEFAULT 'daily' CHECK (repeat_type IN ('never', 'daily', 'weekly', 'monthly')),
    reminder_time TEXT,
    order_index INTEGER DEFAULT 0,
    streak_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row-Level Security for tasks
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;

-- Tasks Policies
CREATE POLICY "Allow users to select their own tasks" 
ON public.tasks FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Allow users to insert their own tasks" 
ON public.tasks FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to update their own tasks" 
ON public.tasks FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to delete their own tasks" 
ON public.tasks FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- 3.1 Create Task Completions Table (Permanent History)
CREATE TABLE IF NOT EXISTS public.task_completions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    completed_date TEXT NOT NULL, -- Format: YYYY-MM-DD
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.task_completions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Select own task completions" ON public.task_completions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Insert own task completions" ON public.task_completions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Delete own task completions" ON public.task_completions FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- 3.2 Create Task Exceptions Table (Deleted occurrences)
CREATE TABLE IF NOT EXISTS public.task_exceptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    exception_date TEXT NOT NULL, -- Format: YYYY-MM-DD
    is_deleted BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.task_exceptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Select own task exceptions" ON public.task_exceptions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Insert own task exceptions" ON public.task_exceptions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Delete own task exceptions" ON public.task_exceptions FOR DELETE TO authenticated USING (auth.uid() = user_id);



-- 4. Create Workouts Table (Stores training logs)
CREATE TABLE IF NOT EXISTS public.workouts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_type TEXT NOT NULL CHECK (activity_type IN ('running', 'strength', 'yoga', 'sports', 'walking')),
    duration INTEGER NOT NULL,
    weight_kg NUMERIC NOT NULL,
    calories_burned NUMERIC NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row-Level Security for workouts
ALTER TABLE public.workouts ENABLE ROW LEVEL SECURITY;

-- Workouts Policies
CREATE POLICY "Allow users to select their own workouts" 
ON public.workouts FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Allow users to insert their own workouts" 
ON public.workouts FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to update their own workouts" 
ON public.workouts FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to delete their own workouts" 
ON public.workouts FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);


-- 5. Create Sleep Logs Table (Stores sleep telemetry)
CREATE TABLE IF NOT EXISTS public.sleep_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sleep_time TIMESTAMP WITH TIME ZONE NOT NULL,
    wake_time TIMESTAMP WITH TIME ZONE NOT NULL,
    reported_quality NUMERIC NOT NULL,
    caffeine_after_3pm BOOLEAN NOT NULL DEFAULT FALSE,
    screen_time_in_bed BOOLEAN NOT NULL DEFAULT FALSE,
    late_dinner BOOLEAN NOT NULL DEFAULT FALSE,
    calculated_quality NUMERIC NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Enable Row-Level Security for sleep logs
ALTER TABLE public.sleep_logs ENABLE ROW LEVEL SECURITY;

-- Sleep Logs Policies
CREATE POLICY "Allow users to select their own sleep logs" 
ON public.sleep_logs FOR SELECT 
TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Allow users to insert their own sleep logs" 
ON public.sleep_logs FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to update their own sleep logs" 
ON public.sleep_logs FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id) 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Allow users to delete their own sleep logs" 
ON public.sleep_logs FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);


-- 6. Create Food Logs Table
CREATE TABLE IF NOT EXISTS public.food_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    food_name TEXT NOT NULL,
    calories NUMERIC NOT NULL,
    protein NUMERIC NOT NULL,
    carbs NUMERIC NOT NULL,
    fats NUMERIC NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.food_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own food logs" ON public.food_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own food logs" ON public.food_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own food logs" ON public.food_logs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own food logs" ON public.food_logs FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 7. Create Water Logs Table
CREATE TABLE IF NOT EXISTS public.water_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    glasses INTEGER NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.water_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own water logs" ON public.water_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own water logs" ON public.water_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own water logs" ON public.water_logs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own water logs" ON public.water_logs FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 8. Create Addiction Logs Table
CREATE TABLE IF NOT EXISTS public.addiction_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    feeling TEXT NOT NULL,
    urge_level INTEGER NOT NULL,
    trigger_tag TEXT NOT NULL,
    helper_strategy TEXT NOT NULL,
    is_relapse BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.addiction_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own addiction logs" ON public.addiction_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own addiction logs" ON public.addiction_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own addiction logs" ON public.addiction_logs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own addiction logs" ON public.addiction_logs FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 9. Create Finance Transactions Table
CREATE TABLE IF NOT EXISTS public.finance_transactions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense')),
    category TEXT NOT NULL,
    amount NUMERIC NOT NULL,
    notes TEXT,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.finance_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own transactions" ON public.finance_transactions FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own transactions" ON public.finance_transactions FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own transactions" ON public.finance_transactions FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own transactions" ON public.finance_transactions FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 10. Create Learning Subjects Table
CREATE TABLE IF NOT EXISTS public.learning_subjects (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    daily_target_minutes INTEGER NOT NULL,
    total_target_hours INTEGER NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.learning_subjects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own learning subjects" ON public.learning_subjects FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own learning subjects" ON public.learning_subjects FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own learning subjects" ON public.learning_subjects FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own learning subjects" ON public.learning_subjects FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 11. Create Study Logs Table
CREATE TABLE IF NOT EXISTS public.study_logs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    subject_id UUID NOT NULL REFERENCES public.learning_subjects(id) ON DELETE CASCADE,
    duration_minutes INTEGER NOT NULL,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.study_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own study logs" ON public.study_logs FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own study logs" ON public.study_logs FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own study logs" ON public.study_logs FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own study logs" ON public.study_logs FOR DELETE TO authenticated USING (auth.uid() = user_id);


-- 12. Create Social Contacts Table
CREATE TABLE IF NOT EXISTS public.social_contacts (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    last_contacted TIMESTAMP WITH TIME ZONE NOT NULL,
    notes TEXT,
    logged_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.social_contacts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow users to select their own social contacts" ON public.social_contacts FOR SELECT TO authenticated USING (auth.uid() = user_id);
CREATE POLICY "Allow users to insert their own social contacts" ON public.social_contacts FOR INSERT TO authenticated WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to update their own social contacts" ON public.social_contacts FOR UPDATE TO authenticated USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Allow users to delete their own social contacts" ON public.social_contacts FOR DELETE TO authenticated USING (auth.uid() = user_id);

-- ==========================================
-- 13. Enable Realtime Publications for all Tables
-- ==========================================
alter publication supabase_realtime add table public.profiles;
alter publication supabase_realtime add table public.goals;
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.task_completions;
alter publication supabase_realtime add table public.task_exceptions;
alter publication supabase_realtime add table public.workouts;
alter publication supabase_realtime add table public.sleep_logs;
alter publication supabase_realtime add table public.food_logs;
alter publication supabase_realtime add table public.water_logs;
alter publication supabase_realtime add table public.addiction_logs;
alter publication supabase_realtime add table public.finance_transactions;
alter publication supabase_realtime add table public.social_contacts;
alter publication supabase_realtime add table public.learning_subjects;
alter publication supabase_realtime add table public.study_logs;

-- ==========================================
-- 14. Migration queries to alter existing profiles table
-- ==========================================
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp INTEGER DEFAULT 0;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS streak_restores INTEGER DEFAULT 3;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS restored_dates TEXT[] DEFAULT '{}';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS last_restore_reset TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS app_lock_pin TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS daily_savings_target NUMERIC DEFAULT 500;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS monthly_savings_target NUMERIC DEFAULT 15000;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS big_savings_target NUMERIC DEFAULT 5000;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS nutrition_profile JSONB;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS xp_awarded_dates JSONB DEFAULT '{}';

-- ==========================================
-- 15. Migration queries to alter existing tasks table
-- ==========================================
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS order_index INTEGER DEFAULT 0;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS streak_count INTEGER DEFAULT 0;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS is_paused BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS due_time TEXT;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS scheduled_date TEXT;
ALTER TABLE public.tasks ADD COLUMN IF NOT EXISTS last_completed_date TEXT;
