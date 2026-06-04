-- roger — consolidated baseline schema (privacy-hardened).
--
-- Single baseline migration. Squashes the pre-launch migration history (former
-- 00001_create_schema / 00002_rls_policies / 00003_create_conversation_rpc /
-- 00004_create_account_rpc) into the hardened target state with the privacy
-- patch baked in. Pre-launch, no production data — future real migrations stack
-- on top as 00002+.
--
-- Privacy posture baked in (Roger_Spec §18 Cross-Cutting Privacy Invariants +
-- TODO §1):
--   * App tables hold only a peppered `phone_hash`, never a raw phone number.
--     Raw phone lives only in auth.users (the OTP login credential).
--   * users / user_keys SELECT narrowed to "self OR shares an active
--     conversation with me" — no enumerable user directory.
--   * No client INSERT/DELETE on users: account creation goes only through the
--     create_account RPC (atomic, writes the hash); account deletion goes only
--     through the delete-account Edge Function (later slice), so auth.users and
--     public.users can never drift.
--   * pending_invites holds invite_token + invited_phone_hash, never a raw
--     number.
--   * discovery_rate_limit backs the per-user discovery cap (enforced in the
--     discovery Edge Function — later slice; cap = 20/day per Spec §18).
--
-- OPERATIONAL PREREQUISITE — the discovery pepper (NEVER commit its value):
--   Seed once, out of band, in the SQL editor:
--     select vault.create_secret('<32+ bytes of random>', 'discovery_pepper');
--   peppered_phone_hash() reads it by name. The pepper value must never appear
--   in this file, the repo, or any log.

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension if not exists pgcrypto with schema extensions; -- digest() for the hash

-- ============================================================
-- TABLES
-- ============================================================

-- 1. users — app-side identity. No raw phone; peppered hash only.
create table public.users (
  id              uuid primary key references auth.users(id) on delete cascade,
  phone_hash      text not null unique, -- peppered hash; raw phone lives only in auth.users
  avatar_color    text not null,
  recovery_email  text unique,
  last_active_at  timestamptz,
  created_at      timestamptz not null default now()
);

-- 2. conversations
create table public.conversations (
  id         uuid primary key default gen_random_uuid(),
  name       text,
  created_at timestamptz not null default now()
);

-- 3. conversation_members
create table public.conversation_members (
  id              uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id         uuid references public.users(id) on delete set null, -- null = deleted user
  joined_at       timestamptz not null default now(),
  left_at         timestamptz,
  custom_emoji    jsonb,
  wildcard_emoji  text,
  muted           boolean not null default false,

  unique (conversation_id, user_id)
);

create index idx_conversation_members_conversation on public.conversation_members(conversation_id);
create index idx_conversation_members_user on public.conversation_members(user_id);

-- 4. messages
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

-- 5. message_views
create table public.message_views (
  id            uuid primary key default gen_random_uuid(),
  message_id    uuid not null references public.messages(id) on delete cascade,
  user_id       uuid references public.users(id) on delete set null,
  downloaded_at timestamptz not null default now(),
  viewed_at     timestamptz,

  unique (message_id, user_id)
);

create index idx_message_views_message on public.message_views(message_id);

-- 6. reactions_emoji
create table public.reactions_emoji (
  id         uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.messages(id) on delete cascade,
  user_id    uuid references public.users(id) on delete set null,
  emoji      text not null,
  created_at timestamptz not null default now()
);

create index idx_reactions_emoji_message on public.reactions_emoji(message_id);

-- 7. reactions_video
create table public.reactions_video (
  id                uuid primary key default gen_random_uuid(),
  parent_message_id uuid not null references public.messages(id) on delete cascade,
  sender_id         uuid references public.users(id) on delete set null,
  r2_key            text not null,
  created_at        timestamptz not null default now()
);

create index idx_reactions_video_parent on public.reactions_video(parent_message_id);

-- 8. pending_invites — token + peppered hash of the invited number, no raw phone.
create table public.pending_invites (
  id                 uuid primary key default gen_random_uuid(),
  invite_token       text not null unique,   -- opaque token in the client-sent link
  invited_phone_hash text not null,          -- peppered hash, computed at the discovery pick
  inviting_user_id   uuid references public.users(id) on delete set null,
  conversation_id    uuid not null references public.conversations(id) on delete cascade,
  message_id         uuid not null references public.messages(id) on delete cascade,
  expires_at         timestamptz not null,
  nudge_sent_at      timestamptz,
  created_at         timestamptz not null default now(),

  unique (inviting_user_id, invited_phone_hash)
);

create index idx_pending_invites_hash on public.pending_invites(invited_phone_hash);

-- 9. user_keys
create table public.user_keys (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  public_key text not null,
  created_at timestamptz not null default now(),
  retired_at timestamptz
);

create index idx_user_keys_user on public.user_keys(user_id);

-- 10. conversation_keys
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

-- 11. user_settings
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

-- 12. device_tokens
create table public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.users(id) on delete cascade,
  token      text not null,
  platform   text not null check (platform in ('ios', 'android')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index idx_device_tokens_user on public.device_tokens(user_id);

-- 13. discovery_rate_limit — per-user, per-day counter for the discovery endpoint.
create table public.discovery_rate_limit (
  user_id uuid not null references public.users(id) on delete cascade,
  day     date not null,
  count   integer not null default 0,
  primary key (user_id, day)
);

-- ============================================================
-- FUNCTIONS
-- ============================================================

-- Is the caller an active member of the given conversation?
create or replace function public.is_conversation_member(conv_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv_id
      and user_id = auth.uid()
      and left_at is null
  );
$$;

-- Does the caller share an active conversation with target_user_id?
-- Backs the narrowed users / user_keys SELECT policies. SECURITY DEFINER so it
-- reads conversation_members without recursing into that table's own RLS.
create or replace function public.shares_active_conversation(target_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.conversation_members me
    join public.conversation_members them
      on them.conversation_id = me.conversation_id
    where me.user_id = auth.uid() and me.left_at is null
      and them.user_id = target_user_id and them.left_at is null
  );
$$;

-- Peppered SHA-256 of an already-normalized E.164 phone number. The pepper is
-- held in Vault (seeded out of band — see header) and never leaves the server.
-- Not granted to clients: only create_account and the discovery Edge Function
-- (both server-side) call it. The single source of the hashing logic, so the
-- on-join invite match (invited_phone_hash == joiner phone_hash) stays consistent.
--
-- NOTE (verify on first apply): the Vault read below uses the documented
-- vault.decrypted_secrets view. Confirm against the current Supabase Vault API
-- when this is first run; it can't be validated without the secret seeded.
create or replace function public.peppered_phone_hash(p_phone text)
returns text
language plpgsql
stable
security definer
set search_path = public, vault, extensions
as $$
declare
  v_pepper text;
begin
  select decrypted_secret into v_pepper
  from vault.decrypted_secrets
  where name = 'discovery_pepper'
  limit 1;

  if v_pepper is null then
    raise exception 'discovery_pepper is not configured in Vault';
  end if;

  return encode(digest(v_pepper || p_phone, 'sha256'), 'hex');
end;
$$;

-- Atomic conversation + memberships creation. Avoids the RLS chicken-and-egg
-- where a client .select() on the conversation insert would fail before the
-- caller is a member. Spec §9: groups capped at 5; creator must be a member.
create or replace function public.create_conversation(
  p_name text,
  p_member_ids uuid[]
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_conv_id uuid;
  v_now timestamptz := now();
begin
  if v_caller is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  if not (v_caller = any(p_member_ids)) then
    raise exception 'Creator must be a member of the conversation'
      using errcode = '42501';
  end if;

  if array_length(p_member_ids, 1) > 5 then
    raise exception 'Conversation exceeds maximum of 5 members'
      using errcode = '23514';
  end if;

  insert into public.conversations (name, created_at)
  values (p_name, v_now)
  returning id into v_conv_id;

  insert into public.conversation_members (conversation_id, user_id, joined_at)
  select v_conv_id, m, v_now from unnest(p_member_ids) as m;

  return v_conv_id;
end;
$$;

-- Atomic account creation — the ONLY write path into public.users (no client
-- INSERT policy exists). Reads the caller's verified phone from auth.users
-- (canonical E.164, can't be spoofed), stores only its peppered hash, and
-- writes users + user_settings in one transaction. Returns the new user id.
create or replace function public.create_account(
  p_avatar_color text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_phone text;
  v_now timestamptz := now();
begin
  if v_caller is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  select phone into v_phone from auth.users where id = v_caller;
  if v_phone is null then
    raise exception 'No verified phone on the auth account' using errcode = '42501';
  end if;

  insert into public.users (id, phone_hash, avatar_color, created_at)
  values (v_caller, public.peppered_phone_hash(v_phone), p_avatar_color, v_now);

  insert into public.user_settings (user_id, created_at, updated_at)
  values (v_caller, v_now, v_now);

  return v_caller;
end;
$$;

-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

-- 1. users — narrowed: self OR shares an active conversation. No client
--    INSERT (create_account RPC only) and no client DELETE (delete-account
--    Edge Function only, so auth.users/public.users stay in sync).
alter table public.users enable row level security;

create policy "users: select self or shared conversation"
  on public.users for select
  to authenticated
  using (id = auth.uid() or public.shares_active_conversation(id));

create policy "users: update own"
  on public.users for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- 2. conversations
alter table public.conversations enable row level security;

create policy "conversations: select for members"
  on public.conversations for select
  to authenticated
  using (public.is_conversation_member(id));

create policy "conversations: insert for authenticated"
  on public.conversations for insert
  to authenticated
  with check (true);

create policy "conversations: update for members"
  on public.conversations for update
  to authenticated
  using (public.is_conversation_member(id))
  with check (public.is_conversation_member(id));

-- 3. conversation_members
alter table public.conversation_members enable row level security;

create policy "conversation_members: select for members"
  on public.conversation_members for select
  to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "conversation_members: insert for authenticated"
  on public.conversation_members for insert
  to authenticated
  with check (true);

create policy "conversation_members: update own"
  on public.conversation_members for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "conversation_members: delete own"
  on public.conversation_members for delete
  to authenticated
  using (user_id = auth.uid());

-- 4. messages
alter table public.messages enable row level security;

create policy "messages: select for members"
  on public.messages for select
  to authenticated
  using (public.is_conversation_member(conversation_id));

create policy "messages: insert for members"
  on public.messages for insert
  to authenticated
  with check (
    public.is_conversation_member(conversation_id)
    and sender_id = auth.uid()
  );

create policy "messages: update own"
  on public.messages for update
  to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

create policy "messages: delete own"
  on public.messages for delete
  to authenticated
  using (sender_id = auth.uid());

-- 5. message_views
alter table public.message_views enable row level security;

create policy "message_views: select for members"
  on public.message_views for select
  to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and public.is_conversation_member(m.conversation_id)
    )
  );

create policy "message_views: insert own"
  on public.message_views for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "message_views: update own"
  on public.message_views for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 6. reactions_emoji
alter table public.reactions_emoji enable row level security;

create policy "reactions_emoji: select for members"
  on public.reactions_emoji for select
  to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = message_id
        and public.is_conversation_member(m.conversation_id)
    )
  );

create policy "reactions_emoji: insert for members"
  on public.reactions_emoji for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (
      select 1 from public.messages m
      where m.id = message_id
        and public.is_conversation_member(m.conversation_id)
    )
  );

create policy "reactions_emoji: delete own"
  on public.reactions_emoji for delete
  to authenticated
  using (user_id = auth.uid());

-- 7. reactions_video
alter table public.reactions_video enable row level security;

create policy "reactions_video: select for members"
  on public.reactions_video for select
  to authenticated
  using (
    exists (
      select 1 from public.messages m
      where m.id = parent_message_id
        and public.is_conversation_member(m.conversation_id)
    )
  );

create policy "reactions_video: insert for members"
  on public.reactions_video for insert
  to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.messages m
      where m.id = parent_message_id
        and public.is_conversation_member(m.conversation_id)
    )
  );

create policy "reactions_video: delete own"
  on public.reactions_video for delete
  to authenticated
  using (sender_id = auth.uid());

-- 8. pending_invites — inviter sees own; recipient matches on their phone_hash.
alter table public.pending_invites enable row level security;

create policy "pending_invites: select for inviter or recipient"
  on public.pending_invites for select
  to authenticated
  using (
    inviting_user_id = auth.uid()
    or invited_phone_hash = (select phone_hash from public.users where id = auth.uid())
  );

create policy "pending_invites: insert for authenticated"
  on public.pending_invites for insert
  to authenticated
  with check (inviting_user_id = auth.uid());

create policy "pending_invites: update own"
  on public.pending_invites for update
  to authenticated
  using (inviting_user_id = auth.uid())
  with check (inviting_user_id = auth.uid());

create policy "pending_invites: delete own"
  on public.pending_invites for delete
  to authenticated
  using (inviting_user_id = auth.uid());

-- 9. user_keys — narrowed like users: self OR shares an active conversation.
--    (New-conversation key lookups for not-yet-conversation-mates route through
--    the discovery path at Step 10 — see TODO "Tracked for later steps".)
alter table public.user_keys enable row level security;

create policy "user_keys: select self or shared conversation"
  on public.user_keys for select
  to authenticated
  using (user_id = auth.uid() or public.shares_active_conversation(user_id));

create policy "user_keys: insert own"
  on public.user_keys for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "user_keys: update own"
  on public.user_keys for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 10. conversation_keys
alter table public.conversation_keys enable row level security;

create policy "conversation_keys: select own"
  on public.conversation_keys for select
  to authenticated
  using (user_id = auth.uid());

create policy "conversation_keys: insert for members"
  on public.conversation_keys for insert
  to authenticated
  with check (public.is_conversation_member(conversation_id));

create policy "conversation_keys: update own"
  on public.conversation_keys for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 11. user_settings
alter table public.user_settings enable row level security;

create policy "user_settings: select own"
  on public.user_settings for select
  to authenticated
  using (user_id = auth.uid());

create policy "user_settings: insert own"
  on public.user_settings for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "user_settings: update own"
  on public.user_settings for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- 12. device_tokens
alter table public.device_tokens enable row level security;

create policy "device_tokens: select own"
  on public.device_tokens for select
  to authenticated
  using (user_id = auth.uid());

create policy "device_tokens: insert own"
  on public.device_tokens for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "device_tokens: update own"
  on public.device_tokens for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "device_tokens: delete own"
  on public.device_tokens for delete
  to authenticated
  using (user_id = auth.uid());

-- 13. discovery_rate_limit — RLS on, NO client policies. Only the discovery
--     Edge Function (SECURITY DEFINER / service path) touches it; clients can
--     never read or write the per-user counters directly.
alter table public.discovery_rate_limit enable row level security;

-- ============================================================
-- GRANTS — only the two client-callable RPCs. peppered_phone_hash is NOT
-- granted (server-side hashing only).
-- ============================================================
grant execute on function public.create_conversation(text, uuid[]) to authenticated;
grant execute on function public.create_account(text) to authenticated;
