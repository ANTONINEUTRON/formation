-- Custom Assistant Managers, drawn from a photo the Manager uploads.
--
-- Only the drawn character is kept: one image per pose, the same four poses
-- the preset characters have. The photo itself is never stored. A custom
-- character borrows the voice and leaning of one of the presets
-- (`personality`) and can have its own name.
alter table assistant_profiles
  add column personality text,
  add column custom_name text,
  add column free_avatar_used boolean not null default false;

create table assistant_avatars (
  user_id uuid not null references users (id) on delete cascade,
  pose text not null check (pose in ('neutral', 'thinking', 'celebrating', 'concerned')),
  mime text not null,
  image bytea not null,
  created_at timestamptz not null default now(),
  primary key (user_id, pose)
);
