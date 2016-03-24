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



---------------------------------------------------------
-- Create a reporting section for the ConfDB
--

create or replace function inline_0 ()
returns integer as $body$
declare
	v_menu			integer;
	v_main_menu 		integer;
	v_employees		integer;
BEGIN
	select group_id into v_employees from groups where group_name = 'Employees';
	select menu_id into v_main_menu from im_menus where label='reporting';
	v_menu := im_menu__new (
		null,						-- p_menu_id
		'im_menu',					-- object_type
		now(),						-- creation_date
		null,						-- creation_user
		null,						-- creation_ip
		null,						-- context_id
		'intranet-confdb',				-- package_name
		'reporting-confdb', 				-- label
		'Configuration Database', 			-- name
		'/intranet-reporting/', 			-- url
		150,						-- sort_order
		v_main_menu,					-- parent_menu_id
		null						-- p_visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_menu, v_employees, 'read');
	return 0;
end;$body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();




-------------------------------------------------------
-- Export Conf Items to CSV


-- A report that shows activities per day
SELECT im_report_new (
	'Conf Items as CSV',							-- report_name
	'conf_item_export_csv',							-- report_code
	'intranet-confdb',							-- package_key
	100,									-- report_sort_order
	(select menu_id from im_menus where label = 'reporting-confdb'),	-- parent_menu_id
	'dummy - will be replaced below'    	    				-- SQL to execute
);

update im_reports 
set report_description = 'Export all configuration items in a format suitable for Excel pivot tables etc.'
where report_code = 'conf_item_export_csv';

SELECT acs_permission__grant_permission(
	(select menu_id from im_menus where label = 'conf_item_export_csv'),
	(select group_id from groups where group_name = 'Employees'),
	'read'
);


update im_reports 
set report_sql = '
select	conf_item_id,
	conf_item_name,
	conf_item_nr,
	conf_item_code,
	(select conf_item_nr from im_conf_items pc where pc.conf_item_id = ci.conf_item_parent_id) as parent_conf_item_nr,
	im_cost_center_code_from_id(conf_item_cost_center_id) as conf_item_cost_center_code,
	im_email_from_user_id(conf_item_owner_id) as conf_item_owner_email,
	im_category_from_id(conf_item_type_id) as conf_item_type,
	im_category_from_id(conf_item_status_id) as conf_item_status,
	conf_item_version,
	sort_order,
	description,
	note,
	ip_address,
	os_name,
	os_version,
	os_comments,
	win_workgroup,
	win_userdomain,
	win_company,
	win_owner,
	win_product_id,
	win_product_key,
	processor_text,
	processor_speed,
	processor_num,
	sys_memory,
	sys_swap
from	im_conf_items ci
order by tree_sortkey
'
where report_code = 'conf_item_export_csv';



-- Create a menu in the Conf Item admin section for CSV export
SELECT im_menu__new (
		null,			-- p_menu_id
		'im_menu',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		'intranet-confdb',	-- package_name
		'conf_item_csv_export',	-- label
		'Export Conf Items to CSV',	-- name
		'/intranet-reporting/view?report_code=conf_item_export_csv&format=csv',	-- url
		1,			-- sort_order
		(select menu_id from im_menus where label='conf_items'),	-- parent_menu_id
		null			-- p_visible_tcl
);
-- Permissions only for Admins, so we dont need to grant anything.


-- Create a menu in the Conf Item admin section for CSV export
SELECT im_menu__new (
		null,			-- p_menu_id
		'im_menu',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		'intranet-confdb',	-- package_name
		'conf_item_csv_import',	-- label
		'Import Conf Items from CSV',	-- name
		'/intranet-csv-import/index?object_type=im_conf_item',	-- url
		2,			-- sort_order
		(select menu_id from im_menus where label='conf_items'),	-- parent_menu_id
		null			-- p_visible_tcl
);
-- Permissions only for Admins, so we dont need to grant anything.

