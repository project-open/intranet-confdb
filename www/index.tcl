# /packages/intranet-confdb/www/index.tcl
#
# Copyright (c) 2003-2007 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    @author frank.bergmann@project-open.com
} {
    { project_id ""}
    { cost_center_id ""}
    { status_id ""}
    { type_id ""}
    { owner_id ""}
    { treelevel "0" }
    { order_by "" }
    { view_name "" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set current_user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set page_focus "im_header_form.keywords"
set page_title [lang::message::lookup "" intranet-confdb.Configuration_Items "Configuration Items"]
set context_bar [im_context_bar $page_title]
set return_url [im_url_with_query]

set date_format "YYYY-MM-DD"

# Unprivileged users can only see their own conf_items
set view_conf_items_p [im_permission $current_user_id "view_conf_items"]
set view_conf_items_all_p [im_permission $current_user_id "view_conf_items_all"]
set add_conf_items_p [im_permission $current_user_id "add_conf_items"]


# ---------------------------------------------------------------
# Admin Links
# ---------------------------------------------------------------

set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
set delete_conf_item_p $user_admin_p


set admin_links [im_menu_ul_list -no_uls 1 "conf_items" {}]

set object_type_admin_links [im_menu_conf_items_admin_links]
foreach link_entry $object_type_admin_links {
    set html ""
    for {set i 0} {$i < [llength $link_entry]} {incr i 2} {
        set name [lindex $link_entry $i]
        set url [lindex $link_entry $i+1]
        append html "<a href='$url'>$name</a>"
    }
    append admin_links "<li>$html</li>\n"
}

if {"" != $admin_links} {
    set admin_links "<ul>\n$admin_links\n</ul>\n"
}


# ---------------------------------------------------------------
# Filter with Dynamic Fields
# ---------------------------------------------------------------

# set project_options [im_project_options -project_status_id [im_project_status_open]]
#     	{project_id:text(select),optional { label "[lang::message::lookup {} intranet-confdb.Project {Project}]" } {options $project_options }}


set owner_options [util_memoize [list im_employee_options] 3600]
set cost_center_options [im_cost_center_options -include_empty 1]
set treelevel_options [list \
	[list [lang::message::lookup "" intranet-confdb.Top_Items "Only Top Items"] 0] \
	[list [lang::message::lookup "" intranet-confdb.2nd_Level_Items "2nd Level Items"] 1] \
	[list [lang::message::lookup "" intranet-confdb.All_Items "All Items"] ""] \
]

set form_id "conf_item_filter"
set object_type "im_conf_item"
set action_url "/intranet-confdb/index"
set form_mode "edit"

ad_form \
    -name $form_id \
    -action $action_url \
    -mode $form_mode \
    -method GET \
    -export { order_by how_many view_name} \
    -form {
	{treelevel:text(select),optional {label "[lang::message::lookup {} intranet-core.Treelevel {Treelevel}]"} {options $treelevel_options } }
	{type_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-core.Conf_Item_Type {Type}]"} {custom {category_type "Intranet Conf Item Type" translate_p 1 package_key "intranet-confdb"} } }
	{status_id:text(im_category_tree),optional {label "[lang::message::lookup {} intranet-core.Conf_Item_Status {Status}]"} {custom {category_type "Intranet Conf Item Status" translate_p 1 package_key "intranet-confdb"}} }
    	{cost_center_id:text(select),optional {label "[lang::message::lookup {} intranet-confdb.Cost_Center {Cost Center}]"} {options $cost_center_options }}
    	{owner_id:text(select),optional {label "[lang::message::lookup {} intranet-confdb.Owner {Owner}]"} {options $owner_options }}
    }

    im_dynfield::append_attributes_to_form \
        -object_type $object_type \
        -form_id $form_id \
        -object_id 0 \
	-advanced_filter_p 1

    # Set the form values from the HTTP form variable frame
    im_dynfield::set_form_values_from_http -form_id $form_id
    im_dynfield::set_local_form_vars_from_http -form_id $form_id

    array set extra_sql_array [im_dynfield::search_sql_criteria_from_form \
	-form_id $form_id \
	-object_type $object_type
    ]




# ---------------------------------------------------------------
# Defined Table Fields
# ---------------------------------------------------------------

# Define the column headers and column contents that 
# we want to show:
#
if {"" == $view_name || "standard" == $view_name} { set view_name "im_conf_item_list" }
set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
if {!$view_id } {
    ad_return_complaint 1 "<b>Unknown View Name</b>:<br> The view '$view_name' is not defined.<br> 
    Maybe you need to upgrade the database. <br> Please notify your system administrator."
    return
}


# ---------------------------------------------------------------
# Format the List Table Header
# ---------------------------------------------------------------

set column_headers [list]
set column_vars [list]
set extra_selects [list]
set extra_froms [list]
set extra_wheres [list]
set view_order_by_clause ""

set column_sql "
	select	vc.*
	from	im_view_columns vc
	where	view_id = :view_id
		and group_id is null
	order by sort_order
"
set table_header_html ""
db_foreach column_list_sql $column_sql {
    if {"" == $visible_for || [eval $visible_for]} {
	lappend column_headers "$column_name"
	lappend column_vars "$column_render_tcl"
	if {"" != $extra_select} { lappend extra_selects $extra_select }
	if {"" != $extra_from} { lappend extra_froms $extra_from }
	if {"" != $extra_where} { lappend extra_wheres $extra_where }
	if {"" != $order_by_clause && [string tolower $order_by] == [string tolower $column_name]} {
	    set view_order_by_clause $order_by_clause
	}

	# Build the column header
	regsub -all " " $column_name "_" col_txt
	set col_txt [lang::message::lookup "" "intranet-confdb.Column_$col_txt" $column_name]
	set col_url [export_vars -base "index" {{order_by $column_name}}]

	# Append the DynField values from the Filter as pass-through variables
	# so that sorting won't alter the selected tickets
	set dynfield_sql "
		select	aa.attribute_name
		from	im_dynfield_attributes a,
			acs_attributes aa
		where	a.acs_attribute_id = aa.attribute_id
			and aa.object_type = 'im_ticket'
		UNION select 'mine_p'
		UNION select 'start_date'
		UNION select 'end_date'
	"
	db_foreach pass_through_vars $dynfield_sql {
	    set value [im_opt_val $attribute_name]
	    if {"" != $value} {
		append col_url "&$attribute_name=$value"
	    }
	}

	set admin_link "<a href=[export_vars -base "/intranet/admin/views/new-column" {return_url column_id {form_mode display}}]>[im_gif wrench]</a>"
	if {!$user_is_admin_p} { set admin_link "" }
	set checkbox_p [regexp {<input} $column_name match]
	
	if { $order_by eq $column_name  || $checkbox_p } {
	    append table_header_html "<td class=rowtitle>$col_txt$admin_link</td>\n"
	} else {
	    append table_header_html "<td class=rowtitle><a href=\"$col_url\">$col_txt</a>$admin_link</td>\n"
	}
    }
}
set table_header_html "
	<thead>
	<tr>
	$table_header_html
	</tr>
	</thead>
"


# Set up colspan to be the number of headers + 1 for the # column
set colspan [expr {[llength $column_headers] + 1}]



# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

set bulk_actions_list "[list]"
if {$delete_conf_item_p} {
    lappend bulk_actions_list "[lang::message::lookup "" intranet-confdb.Delete "Delete"]" "conf-item-del" "[lang::message::lookup "" intranet-confdb.Remove_checked_items "Remove Checked Items"]"
}


# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

set order_by_clause ""
switch [string tolower $order_by] {
    "type" { set order_by_clause "order by conf_item_type_id" }
    "status" { set order_by_clause "order by conf_item_staus_id" }
    "nr" { set order_by_clause "order by lower(conf_item_nr)" }
    "name" { set order_by_clause "order by lower(conf_item_name)" }
}
# order_by_clause from view configuration overrides default
if {"" != $view_order_by_clause} { set order_by_clause $view_order_by_clause }
if {"" == $order_by_clause} { set order_by_clause "order by i.tree_sortkey" }



# ---------------------------------------------------------------
# Dashboard column
# ---------------------------------------------------------------

set dashboard_column_html [string trim [im_component_bay "right"]]
if {"" == $dashboard_column_html} {
    set dashboard_column_width "0"
} else {
    set dashboard_column_width "250"
}


# ---------------------------------------------------------------
# Compose SQL
# ---------------------------------------------------------------

set conf_item_sql [im_conf_item_select_sql \
	-project_id $project_id \
	-type_id $type_id \
	-status_id $status_id \
	-owner_id $owner_id \
	-cost_center_id $cost_center_id \
	-treelevel $treelevel \
]



#ad_return_complaint 1 "<pre>$conf_item_sql</pre>"

set sql "
	select --DISTINCT on (i.tree_sortkey,conf_item_id)
		i.*,
		tree_level(i.tree_sortkey)-1 as indent_level,
		p.project_id,
		project_name
	from	($conf_item_sql) i
		LEFT OUTER JOIN acs_rels r ON (i.conf_item_id = r.object_id_two)
		LEFT OUTER JOIN im_projects p ON (p.project_id = r.object_id_one)
	$order_by_clause
"





# ---------------------------------------------------------------
# Format the Result Data
# ---------------------------------------------------------------

set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "
set ctr 0
set idx 0
set table_body_html ""
db_foreach conf_db_query $sql {

    # L10n
    regsub -all {[^0-9a-zA-Z]} $conf_item_type "_" conf_item_type_key
    set conf_item_type_l10n [lang::message::lookup "" intranet-core.$conf_item_type_key $conf_item_type]
    regsub -all {[^0-9a-zA-Z]} $conf_item_status "_" conf_item_status_key
    set conf_item_status_l10n [lang::message::lookup "" intranet-core.$conf_item_status_key $conf_item_status]

    set conf_item_cost_center_name [im_cost_center_name $conf_item_cost_center_id]

    # Bulk Action Checkbox
    set action_checkbox "<input type=checkbox name=conf_item value=$conf_item_id id=conf_item,$conf_item_id>\n"

    set processor "${processor_num}x$processor_speed"
    set conf_item_url [export_vars -base new {conf_item_id {form_mode "display"}}]

    set indent ""
    for {set i 0} {$i < $indent_level} {incr i} {
	append indent "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
    }
    set indent_short_html $indent

    # Append together a line of data based on the "column_vars" parameter list
    set row_html "<tr$bgcolor([expr {$ctr % 2}])>\n"
    foreach column_var $column_vars {
	append row_html "<td>"
	set cmd "append row_html $column_var"
	eval "$cmd"
	append row_html "</td>\n"
    }
    append row_html "</tr>\n"
    append table_body_html $row_html

    incr ctr
    incr idx
}

# Show a reasonable message when there are no result rows:
if { $table_body_html eq "" } {
    set table_body_html "
	<tr><td colspan=$colspan><ul><li><b>
	[lang::message::lookup "" intranet-core.lt_There_are_currently_n "There are currently no entries matching the selected criteria"]
	</b></ul></td></tr>
    "
}

set table_continuation_html "
	<tr>
	  <td align=center colspan=$colspan>
	  </td>
	</tr>
"
#	    [im_maybe_insert_link $prev_page $next_page]
#	    $viewing_msg &nbsp;


set conf_db_action_customize_html "<a href=[export_vars -base "/intranet/admin/categories/index" {{select_category_type "Intranet Conf Item Action"}}]>[im_gif -translate_p 1 wrench "Custom Actions"]</a>"
if {!$user_is_admin_p} { set conf_db_action_customize_html "" }


set table_submit_html "
  <tfoot>
	<tr valign=top>
	  <td align=left colspan=[expr {$colspan-1}] valign=top>
		<table cellspacing=1 cellpadding=1 border=0>
		<tr valign=top>
		<td>
			[im_category_select \
			     -translate_p 1 \
			     -package_key "intranet-confdb" \
			     -plain_p 1 \
			     -include_empty_p 1 \
			     -include_empty_name "" \
			     "Intranet Conf Item Action" \
			     action_id \
			]
		</td>
		<td>
			<input type=submit value='[lang::message::lookup "" intranet-confdb.Action "Action"]'>
			$conf_db_action_customize_html
		</td>
		</tr>
		</table>

	  </td>
	</tr>
  </tfoot>
"

if {!$view_conf_items_all_p} { set table_submit_html "" }




# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

eval [template::adp_compile -string {<formtemplate id="conf_item_filter"></formtemplate>}]
set filter_html $__adp_output

set left_navbar_html "
    <div class='filter-block'>
      <div class='filter-title'>
	[lang::message::lookup "" intranet-confdb.Filter_Items "Filter Items"]
      </div>
      $filter_html
    </div>
    <hr>

    <div class='filter-block'>
      <div class='filter-title'>
        [_ intranet-core.Admin_Links]
      </div>
      $admin_links
    </div>
"


set letter ""
set next_page_url ""
set prev_page_url ""
set menu_select_label "confdb_summary"
set conf_item_navbar_html [im_conf_item_navbar -navbar_menu_label "confdb" $letter "/intranet-confdb/index" $next_page_url $prev_page_url [list start_idx order_by how_many view_name letter conf_db_status_id] $menu_select_label]


