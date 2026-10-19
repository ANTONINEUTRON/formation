-- Feedback Managers send from the app: a bug, an idea or anything else,
-- with an optional 1-5 rating and screenshot. Read through the admin
-- endpoints (and the admin dashboard, once built).
--
-- reply_email is the profile email at the time of sending, so a reply goes
-- where the Manager asked even if they change it later. Screenshots live in
-- Postgres beside the custom avatars; there's no separate file store.
create table feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users (id) on delete cascade,
  kind text not null check (kind in ('bug', 'idea', 'other')),
  rating smallint check (rating between 1 and 5),
  message text not null check (length(message) between 1 and 2000),
  reply_email text,
  app_version text,
  platform text,
  screenshot bytea,
  screenshot_mime text,
  status text not null default 'new' check (status in ('new', 'read', 'done')),
  created_at timestamptz not null default now()
);
create index feedback_newest on feedback (created_at desc);
create index feedback_by_user on feedback (user_id, created_at desc);
