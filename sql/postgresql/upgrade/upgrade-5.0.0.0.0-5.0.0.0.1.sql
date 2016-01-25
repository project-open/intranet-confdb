-- upgrade-5.0.0.0.0-5.0.0.0.1.sql

SELECT acs_log__debug('/packages/intranet-confdb/sql/postgresql/upgrade/upgrade-5.0.0.0.0-5.0.0.0.1.sql','');

-- Make sure there is no direct loop.
-- ToDo: Check that the parent is not "below" conf_item_id
-- in terms of tree_sortkey
alter table im_conf_items
add constraint im_conf_items_parent_noloop_ck
check(conf_item_parent_id != conf_item_id);

