-- upgrade-5.0.0.0.0-5.0.0.0.1.sql

SELECT acs_log__debug('/packages/intranet-confdb/sql/postgresql/upgrade/upgrade-5.0.0.0.0-5.0.0.0.1.sql','');

-- Make sure there is no direct loop.
-- ToDo: Check that the parent is not "below" conf_item_id
-- in terms of tree_sortkey

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS $BODY$

declare
        v_count                 integer;
begin
	select count(*) into v_count from pg_constraint where lower(conname) = 'im_conf_items_parent_noloop_ck';

        IF      0 != v_count
        THEN
                RAISE NOTICE 'intranet-confdb/sql/postgresql/upgrade/upgrade-5.0.0.0.0-5.0.0.0.1.sql - im_conf_items_parent_noloop_ck already exists';
                return 0;
        END IF;

	alter table im_conf_items add constraint im_conf_items_parent_noloop_ck check(conf_item_parent_id != conf_item_id);

        return 1;

end;$BODY$ LANGUAGE 'plpgsql';

SELECT inline_0 ();
DROP FUNCTION inline_0 ();
