-- roger schema migration: all 12 tables from spec section 15
-- Supabase Auth provides auth.users; public.users references it.

-- ============================================================
-- 1. users
-- ============================================================
create table public.users (
  id                      uuid primary key references auth.users(id) on delete cascade,
  phone_number            text not null unique,
  display_name            text not null,
  avatar_color            text not null,
  email                   text,
  recovery_email_verified boolean not null default false,
  last_active_at          timestamptz,
  created_at              timestamptz not null default now()
);

-- ============================================================
-- 2. conversations
-- ============================================================
create table public.conversations (
  id         uuid primary key default gen_random_uuid(),
  name       text,
  created_at timestamptz not null default now()
);

-- ============================================================
-- 3. conversation_members
-- ============================================================
create table public.conversation_members (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid not null references public.users(id) on delete set null,
  joined_at       timestamptz not null default now(),
  left_at         timestamptz,
  custom_emoji    jsonb,
  wildcard_emoji  text,
  muted           boolean not null default false,

  unique (conversation_id, user_id)
);

create index idx_conversation_members_conversation on public.conversation_members(conversation_id);
create index idx_conversation_members_user on public.conversation_members(user_id);

-- ============================================================
-- 4. messages
-- ============================================================
create table public.messages (
  id                    uuid primary key default gen_random_uuid(),
  conversation_id       uuid not null references public.conversations(id) on delete restrict,
  sender_id             uuid references public.users(id) on delete set null,
  type                  text not null check (type in ('video', 'photo', 'note', 'call_chunk')),
  r2_key                text,
  voice_overlay_r2_key  text,
  encrypted_text        text,
  call_session_id       uuid,
  r2_expires_at         timestamptz,
  nudge_sent_at         timestamptz,
  created_at            timestamptz not null default now()
);

create index idx_messages_conversation on public.messages(conversation_id, created_at);
create index idx_messages_sender on public.messages(sender_id);

-- ============================================================
-- 5. message_views
-- ============================================================
create table public.message_views (
  id            uuid primary key default gen_random_uuid(),
  message_id    uuid not null references public.messages(id) on delete cascade,
  user_id       uuid not null references public.users(id) on delete set null,
  downloaded_at timestamptz not null default now(),
  viewed_at     timestamptz,

  unique (message_id, user_id)
);

create index idx_message_views_message on public.message_views(message_id);

-- ============================================================
-- 6. reactions_emoji
-- ============================================================
create table public.reactions_emoji (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid references public.users(id) on delete set null,
  emoji      text not null,
  created_at timestamptz not null default now()
);

create index idx_reactions_emoji_message on public.reactions_emoji(message_id);

-- ============================================================
-- 7. reactions_video
-- ============================================================
create table public.reactions_video (
  id                uuid primary key default gen_random_uuid(),
  parent_message_id uuid not null references public.messages(id) on delete cascade,
  sender_id         uuid references public.users(id) on delete set null,
  r2_key            text not null,
  created_at        timestamptz not null default now()
);

create index idx_reactions_video_parent on public.reactions_video(parent_message_id);

-- ============================================================
-- 8. pending_invites
-- ============================================================
create table public.pending_invites (
  id               uuid primary key default gen_random_uuid(),
  phone_number     text not null,
  inviting_user_id uuid references public.users(id) on delete set null,
  conversation_id  uuid not null references public.conversations(id) on delete cascade,
  message_id       uuid not null references public.messages(id) on delete cascade,
  expires_at       timestamptz not null,
  nudge_sent_at    timestamptz,
  created_at       timestamptz not null default now(),

  unique (inviting_user_id, phone_number)
);

create index idx_pending_invites_phone on public.pending_invites(phone_number);

-- ============================================================
-- 9. user_keys
-- ============================================================
create table public.user_keys (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  public_key text not null,
  created_at timestamptz not null default now(),
  retired_at timestamptz
);

create index idx_user_keys_user on public.user_keys(user_id);

-- ============================================================
-- 10. conversation_keys
-- ============================================================
create table public.conversation_keys (
  id                         uuid primary key default gen_random_uuid(),
  conversation_id            uuid not null references public.conversations(id) on delete cascade,
  user_id                    uuid not null references public.users(id) on delete cascade,
  encrypted_conversation_key text not null,
  created_at                 timestamptz not null default now(),
  retired_at                 timestamptz
);

create index idx_conversation_keys_conversation on public.conversation_keys(conversation_id);
create index idx_conversation_keys_user on public.conversation_keys(user_id);

-- ============================================================
-- 11. user_settings
-- ============================================================
create table public.user_settings (
  id                     uuid primary key default gen_random_uuid(),
  user_id                uuid not null unique references public.users(id) on delete cascade,
  message_limit          integer not null default 100 check (message_limit between 10 and 500),
  disappearing_messages  boolean not null default false,
  pre_disappearing_limit integer,
  notifications_enabled  boolean not null default true,
  notify_videos          boolean not null default true,
  notify_photos          boolean not null default true,
  notify_notes           boolean not null default true,
  notify_expirations     boolean not null default true,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

-- ============================================================
-- 12. device_tokens
-- ============================================================
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_device_tokens_user on public.device_tokens(user_id);
