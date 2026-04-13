-- Hybrid AI Try-On database setup for Kombinly.
-- Run this in Supabase SQL editor.

-- 1) Storage bucket (public for quick MVP iteration).
insert into storage.buckets (id, name, public)
values ('ai-try-on', 'ai-try-on', true)
on conflict (id) do nothing;

-- 2) AI Try-On results table.
create table if not exists public.ai_try_on_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null default 'gemini',
  status text not null default 'succeeded',
  prompt text not null,
  mannequin_image_url text,
  garment_image_url text,
  garment_title text,
  result_image_url text not null,
  created_at timestamptz not null default now()
);

create index if not exists ai_try_on_results_user_created_idx
on public.ai_try_on_results (user_id, created_at desc);

-- 3) RLS
alter table public.ai_try_on_results enable row level security;

create policy if not exists "ai_try_on_select_own"
on public.ai_try_on_results
for select
using (auth.uid() = user_id);

create policy if not exists "ai_try_on_insert_own"
on public.ai_try_on_results
for insert
with check (auth.uid() = user_id);

-- 4) Storage RLS policies for ai-try-on bucket.
create policy if not exists "ai_try_on_storage_read_own"
on storage.objects
for select
using (
  bucket_id = 'ai-try-on'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "ai_try_on_storage_insert_own"
on storage.objects
for insert
with check (
  bucket_id = 'ai-try-on'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "ai_try_on_storage_update_own"
on storage.objects
for update
using (
  bucket_id = 'ai-try-on'
  and auth.uid()::text = (storage.foldername(name))[1]
)
with check (
  bucket_id = 'ai-try-on'
  and auth.uid()::text = (storage.foldername(name))[1]
);

create policy if not exists "ai_try_on_storage_delete_own"
on storage.objects
for delete
using (
  bucket_id = 'ai-try-on'
  and auth.uid()::text = (storage.foldername(name))[1]
);
