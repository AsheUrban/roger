-- Atomic account creation.
--
-- Why: AuthService.createAccount previously did two sequential client-side
-- inserts — public.users, then public.user_settings. A failure between them
-- left an orphaned users row with no settings row. Worse, the onboarding
-- retry path (verifyOtp) then reads that orphan via getCurrentUser as a
-- complete existing user and proceeds, silently skipping the missing settings.
--
-- This function performs both inserts in a single statement under
-- `security definer`. A plpgsql function runs in one transaction, so either
-- both rows commit or neither does — there is never a partial account.
--
-- Mirrors create_conversation (00003): security definer, validates the
-- caller, returns the new row so the client never needs a follow-up SELECT.
-- Insert order (users before user_settings) preserves the FK from
-- user_settings.user_id → users.id within the transaction.

create or replace function public.create_account(
  p_phone_number text,
  p_avatar_color text
)
returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_caller uuid := auth.uid();
  v_now timestamptz := now();
  v_user public.users;
begin
  if v_caller is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  insert into public.users (id, phone_number, avatar_color, created_at)
  values (v_caller, p_phone_number, p_avatar_color, v_now)
  returning * into v_user;

  insert into public.user_settings (user_id, created_at, updated_at)
  values (v_caller, v_now, v_now);

  return v_user;
end;
$$;

grant execute on function public.create_account(text, text) to authenticated;
