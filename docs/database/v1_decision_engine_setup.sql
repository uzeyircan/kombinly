-- Kombinly V1 decision engine database setup.
-- Run this in the Supabase SQL editor.
--
-- This script is intentionally repeatable:
-- - columns/tables/indexes use "if not exists"
-- - policies are dropped and recreated because PostgreSQL does not support
--   "create policy if not exists"

-- 1) Extend wardrobe items with V1 styling metadata.
alter table public.clothes
add column if not exists gender_target text,
add column if not exists style_tags text[] default '{}',
add column if not exists layer_order int,
add column if not exists target_slot text,
add column if not exists anchor_x numeric,
add column if not exists anchor_y numeric,
add column if not exists fit_strategy text,
add column if not exists notes text;

create index if not exists clothes_user_category_idx
on public.clothes (user_id, category);

create index if not exists clothes_user_created_idx
on public.clothes (user_id, created_at desc);

-- 2) Store generated wardrobe/shop recommendations.
create table if not exists public.outfit_recommendations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source_type text not null default 'wardrobe',
  scenario text not null,
  style text,
  environment text,
  gender text,
  selected_items jsonb not null default '{}'::jsonb,
  ai_reason text,
  score numeric,
  missing_items text[] default '{}',
  created_at timestamptz not null default now()
);

create index if not exists outfit_recommendations_user_created_idx
on public.outfit_recommendations (user_id, created_at desc);

alter table public.outfit_recommendations enable row level security;

drop policy if exists "outfit_recommendations_select_own"
on public.outfit_recommendations;

create policy "outfit_recommendations_select_own"
on public.outfit_recommendations
for select
using (auth.uid() = user_id);

drop policy if exists "outfit_recommendations_insert_own"
on public.outfit_recommendations;

create policy "outfit_recommendations_insert_own"
on public.outfit_recommendations
for insert
with check (auth.uid() = user_id);

drop policy if exists "outfit_recommendations_delete_own"
on public.outfit_recommendations;

create policy "outfit_recommendations_delete_own"
on public.outfit_recommendations
for delete
using (auth.uid() = user_id);

-- 3) Future shop/product catalog scaffold.
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  category text not null,
  gender_target text,
  style_tags text[] default '{}',
  occasion_tags text[] default '{}',
  season text,
  price numeric,
  currency text,
  affiliate_url text,
  image_url text,
  processed_image_url text,
  created_at timestamptz not null default now()
);

create index if not exists products_category_idx
on public.products (category);

create index if not exists products_created_idx
on public.products (created_at desc);

alter table public.products enable row level security;

drop policy if exists "products_select_public"
on public.products;

create policy "products_select_public"
on public.products
for select
using (true);
