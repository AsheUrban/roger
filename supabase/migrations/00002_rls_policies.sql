-- roger RLS policies: every table locked down
-- auth.uid() returns the current authenticated user's UUID

-- ============================================================
-- Helper: check if current user is an active member of a conversation
-- ============================================================
create or replace function public.is_conversation_member(conv_id uuid)
returns boolean
language sql
stable
security definer
as $$
  select exists (
    select 1 from public.conversation_members
    where conversation_id = conv_id
      and user_id = auth.uid()
      and left_at is null
  );
$$;

-- ============================================================
-- 1. users
-- ============================================================
alter table public.users enable row level security;

-- Any authenticated user can read any user row (needed for avatars, presence, contact discovery)
create policy "users: select for authenticated"
  on public.users for select
  to authenticated
  using (true);

-- Users can only insert their own row (during onboarding)
create policy "users: insert own"
  on public.users for insert
  to authenticated
  with check (id = auth.uid());

-- Users can only update their own row
create policy "users: update own"
  on public.users for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

-- Users can only delete their own row (account deletion)
create policy "users: delete own"
  on public.users for delete
  to authenticated
  using (id = auth.uid());

-- ============================================================
-- 2. conversations
-- ============================================================
alter table public.conversations enable row level security;

-- Members can see conversations they belong to
create policy "conversations: select for members"
  on public.conversations for select
  to authenticated
  using (public.is_conversation_member(id));

-- Any authenticated user can create a conversation
create policy "conversations: insert for authenticated"
  on public.conversations for insert
  to authenticated
  with check (true);

-- Active members can update (e.g. rename) the conversation
create policy "conversations: update for members"
  on public.conversations for update
  to authenticated
  using (public.is_conversation_member(id))
  with check (public.is_conversation_member(id));

-- ============================================================
-- 3. conversation_members
-- ============================================================
alter table public.conversation_members enable row level security;

-- Members can see all memberships in their conversations
create policy "conversation_members: select for members"
  on public.conversation_members for select
  to authenticated
  using (public.is_conversation_member(conversation_id));

-- Authenticated users can insert memberships (creating/joining conversations)
create policy "conversation_members: insert for authenticated"
  on public.conversation_members for insert
  to authenticated
  with check (true);

-- Users can only update their own membership (emoji customization, mute)
create policy "conversation_members: update own"
  on public.conversation_members for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Users can only delete their own membership (leaving)
create policy "conversation_members: delete own"
  on public.conversation_members for delete
  to authenticated
  using (user_id = auth.uid());

-- ============================================================
-- 4. messages
-- ============================================================
alter table public.messages enable row level security;

-- Members can see messages in their conversations
create policy "messages: select for members"
  on public.messages for select
  to authenticated
  using (public.is_conversation_member(conversation_id));

-- Members can insert messages in their conversations
create policy "messages: insert for members"
  on public.messages for insert
  to authenticated
  with check (
    public.is_conversation_member(conversation_id)
    and sender_id = auth.uid()
  );

-- Sender can update their own messages (nudge_sent_at, r2_expires_at)
create policy "messages: update own"
  on public.messages for update
  to authenticated
  using (sender_id = auth.uid())
  with check (sender_id = auth.uid());

-- Sender can delete their own messages
create policy "messages: delete own"
  on public.messages for delete
  to authenticated
  using (sender_id = auth.uid());

-- ============================================================
-- 5. message_views
-- ============================================================
alter table public.message_views enable row level security;

-- Members can see views for messages in their conversations
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

-- Users can insert their own view records
create policy "message_views: insert own"
  on public.message_views for insert
  to authenticated
  with check (user_id = auth.uid());

-- Users can update their own view records (viewed_at)
create policy "message_views: update own"
  on public.message_views for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- 6. reactions_emoji
-- ============================================================
alter table public.reactions_emoji enable row level security;

-- Members can see emoji reactions in their conversations
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

-- Members can insert emoji reactions in their conversations
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

-- Users can delete their own emoji reactions
create policy "reactions_emoji: delete own"
  on public.reactions_emoji for delete
  to authenticated
  using (user_id = auth.uid());

-- ============================================================
-- 7. reactions_video
-- ============================================================
alter table public.reactions_video enable row level security;

-- Members can see video reactions in their conversations
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

-- Members can insert video reactions in their conversations
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

-- Users can delete their own video reactions
create policy "reactions_video: delete own"
  on public.reactions_video for delete
  to authenticated
  using (sender_id = auth.uid());

-- ============================================================
-- 8. pending_invites
-- ============================================================
alter table public.pending_invites enable row level security;

-- Inviter can see their own invites; recipient can see invites to their phone number
create policy "pending_invites: select for inviter or recipient"
  on public.pending_invites for select
  to authenticated
  using (
    inviting_user_id = auth.uid()
    or phone_number = (select phone_number from public.users where id = auth.uid())
  );

-- Authenticated users can create invites
create policy "pending_invites: insert for authenticated"
  on public.pending_invites for insert
  to authenticated
  with check (inviting_user_id = auth.uid());

-- Inviter can update their own invites (nudge_sent_at)
create policy "pending_invites: update own"
  on public.pending_invites for update
  to authenticated
  using (inviting_user_id = auth.uid())
  with check (inviting_user_id = auth.uid());

-- Inviter can delete their own invites
create policy "pending_invites: delete own"
  on public.pending_invites for delete
  to authenticated
  using (inviting_user_id = auth.uid());

-- ============================================================
-- 9. user_keys
-- ============================================================
alter table public.user_keys enable row level security;

-- Any authenticated user can read public keys (needed for encryption)
create policy "user_keys: select for authenticated"
  on public.user_keys for select
  to authenticated
  using (true);

-- Users can only insert their own keys
create policy "user_keys: insert own"
  on public.user_keys for insert
  to authenticated
  with check (user_id = auth.uid());

-- Users can only update their own keys (retire)
create policy "user_keys: update own"
  on public.user_keys for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- 10. conversation_keys
-- ============================================================
alter table public.conversation_keys enable row level security;

-- Users can only read their own encrypted conversation keys
create policy "conversation_keys: select own"
  on public.conversation_keys for select
  to authenticated
  using (user_id = auth.uid());

-- Members can insert conversation keys (key distribution)
create policy "conversation_keys: insert for members"
  on public.conversation_keys for insert
  to authenticated
  with check (public.is_conversation_member(conversation_id));

-- Users can update their own keys (retire)
create policy "conversation_keys: update own"
  on public.conversation_keys for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- 11. user_settings
-- ============================================================
alter table public.user_settings enable row level security;

-- Users can only read their own settings
create policy "user_settings: select own"
  on public.user_settings for select
  to authenticated
  using (user_id = auth.uid());

-- Users can only insert their own settings
create policy "user_settings: insert own"
  on public.user_settings for insert
  to authenticated
  with check (user_id = auth.uid());

-- Users can only update their own settings
create policy "user_settings: update own"
  on public.user_settings for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ============================================================
-- 12. device_tokens
-- ============================================================
alter table public.device_tokens enable row level security;

-- Users can only read their own device tokens
create policy "device_tokens: select own"
  on public.device_tokens for select
  to authenticated
  using (user_id = auth.uid());

-- Users can only insert their own device tokens
create policy "device_tokens: insert own"
  on public.device_tokens for insert
  to authenticated
  with check (user_id = auth.uid());

-- Users can only update their own device tokens
create policy "device_tokens: update own"
  on public.device_tokens for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Users can only delete their own device tokens
create policy "device_tokens: delete own"
  on public.device_tokens for delete
  to authenticated
  using (user_id = auth.uid());
