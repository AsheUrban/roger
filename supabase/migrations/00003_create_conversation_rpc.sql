-- Atomic conversation + memberships creation.
--
-- Why: the conversations table SELECT policy requires the caller to already
-- be a member (`is_conversation_member(id)`). A two-step client flow of
-- `INSERT conversations` then `INSERT conversation_members` fails the
-- moment the client uses `.select()` on the conversation insert to read
-- back its id — Postgres evaluates the SELECT policy on the just-inserted
-- row, no membership exists yet, and the entire statement aborts with a
-- 42501 RLS violation.
--
-- This function performs both inserts in a single statement under
-- `security definer`, returning the new conversation id without ever
-- needing a client-side SELECT on the conversations table.
--
-- Spec §9: groups capped at 5 members. Creator must be a member. Single
-- entry point for all conversation creation (1:1, group, invite).

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

grant execute on function public.create_conversation(text, uuid[]) to authenticated;
