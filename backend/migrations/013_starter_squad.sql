-- The free starter squad a new Manager's Assistant Manager drafts for them.
--
-- It's free, so it's rationed: a Manager can have it drafted once and
-- regenerated once (two drafts). Choosing to build the team themselves uses it
-- up. A draft is claimed before the model is called and handed back if the
-- call fails, so an error never costs the Manager their go.
alter table users add column starter_drafts int not null default 0;
