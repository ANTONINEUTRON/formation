-- A daily check-in streak (domain/visit-streak.ts): days in a row a Manager
-- opened the app, counted in their own time zone. It replaces the market
-- streak in classic_scores.streak, which was never computed for real
-- Managers; seeds keep theirs.
alter table users add column visit_streak int not null default 0;
alter table users add column best_visit_streak int not null default 0;
-- The last day they visited, in their time zone.
alter table users add column last_visit_day date;

-- Notifications for streak milestones (and the evening "ends at midnight"
-- reminder) and for weekly badges.
alter table notifications drop constraint if exists notifications_kind_check;
alter table notifications
  add constraint notifications_kind_check
  check (kind in (
    'points',
    'league_started',
    'league_settled',
    'league_joined',
    'new_follower',
    'manager_move',
    'match_week',
    'transfer_window',
    'season_final',
    'goal',
    'streak',
    'badge'
  ));
