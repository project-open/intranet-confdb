-- upgrade-5.0.3.0.4-5.1.0.0.0.sql
SELECT acs_log__debug('/packages/intranet-confdb/sql/postgresql/upgrade/upgrade-5.0.3.0.4-5.1.0.0.0.sql','');



delete from im_view_columns where column_id = 94101;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (94101,941,NULL,
'"<input id=list_check_all_conf_items type=checkbox name=_dummy>"',
'"<input type=checkbox name=conf_item_id.$conf_item_id id=conf_item,$conf_item_id>"', 
'', '', 1, '');





delete from im_view_columns where column_id = 94001;
insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
extra_select, extra_where, sort_order, visible_for) values (94001,940,NULL,
'<input id=list_check_all_conf_items type=checkbox name=_dummy>',
'"<input type=checkbox name=conf_item_id.$conf_item_id id=conf_item,$conf_item_id>"', 
'', '', 1, '');




