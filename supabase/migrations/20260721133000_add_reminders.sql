-- Create reminders table
CREATE TABLE IF NOT EXISTS public.reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    task_id UUID NOT NULL REFERENCES public.tasks(id) ON DELETE CASCADE,
    goal_id UUID REFERENCES public.goals(id) ON DELETE CASCADE,
    scheduled_time TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL DEFAULT 'REMINDER',
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    category TEXT,
    repeat_pattern TEXT NOT NULL DEFAULT 'ONCE',
    is_completed BOOLEAN NOT NULL DEFAULT FALSE,
    is_snoozed BOOLEAN NOT NULL DEFAULT FALSE,
    snooze_until TIMESTAMPTZ,
    deep_link TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Enable RLS
ALTER TABLE public.reminders ENABLE ROW LEVEL SECURITY;

-- Policies for reminders
CREATE POLICY "Users can view their own reminders"
    ON public.reminders FOR SELECT
    USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own reminders"
    ON public.reminders FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own reminders"
    ON public.reminders FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete their own reminders"
    ON public.reminders FOR DELETE
    USING (auth.uid() = user_id);
