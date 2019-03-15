# /packages/intranet-confdb/tcl/intranet-confdb-procs.tcl
#
# Copyright (C) 2003-2007 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_library {
    @author frank.bergmann@project-open.com
}


# ----------------------------------------------------------------------
# Constants
# ----------------------------------------------------------------------

# Conf Item Status
ad_proc -public im_conf_item_status_active {} { return 11700 }
ad_proc -public im_conf_item_status_deleted {} { return 11702 }

# Top-Level Conf Item Types
ad_proc -public im_conf_item_type_hardware {} { return 11800 }
ad_proc -public im_conf_item_type_software {} { return 11802 }
ad_proc -public im_conf_item_type_process {} { return 11804 }
ad_proc -public im_conf_item_type_license {} { return 11806 }
ad_proc -public im_conf_item_type_specs {} { return 11808 }
ad_proc -public im_conf_item_type_service {} { return 11810 }

# Hardware
ad_proc -public im_conf_item_type_pc {} { return 11850 }
ad_proc -public im_conf_item_type_workstation {} { return 11852 }
ad_proc -public im_conf_item_type_laptop {} { return 11854 }
ad_proc -public im_conf_item_type_server {} { return 11856 }
ad_proc -public im_conf_item_type_host {} { return 11858 }
ad_proc -public im_conf_item_type_mainframe {} { return 11860 }
ad_proc -public im_conf_item_type_network_device {} { return 11862 }

# Types of Software
ad_proc -public im_conf_item_type_po_package {} { return 12008 }

# Types of Processes
ad_proc -public im_conf_item_type_po_process {} { return 12300 }
ad_proc -public im_conf_item_type_postgresql_process {} { return 12302 }
ad_proc -public im_conf_item_type_postfix_process {} { return 12304 }
ad_proc -public im_conf_item_type_pound_process {} { return 12306 }

# Types of Services
ad_proc -public im_conf_item_type_cvs_repository {} { return 12400 }



# ----------------------------------------------------------------------
# PackageID
# ----------------------------------------------------------------------

ad_proc -public im_package_conf_items_id {} {
    Returns the package id of the intranet-confdb module
} {
    return [util_memoize im_package_conf_items_id_helper]
}

ad_proc -private im_package_conf_items_id_helper {} {
    return [db_string im_package_core_id {
	select package_id from apm_packages
	where package_key = 'intranet-confdb'
    } -default 0]
}


namespace eval im_conf_item {

    ad_proc -public new {
	{ -var_hash "" }
    } {
	Create a new configuration item.
	There are only few required field.
	Primary key is conf_item_nr which defaults to conf_item_name.

	@author frank.bergmann@project-open.com
	@return The object_id of the new (or existing) Conf Item.
    } {

	# Get the current user and its address.
	# If we are not connected then use some system defaults.
	if {[ns_conn isconnected]} { 
	    set peeraddr [ad_conn peeraddr] 
	    set current_user_id [ad_conn user_id]
	} else {
	    set peeraddr "0.0.0.0"
	    set current_user_id [util_memoize [list db_string first_user "select min(person_id) from persons where person_id > 0" -default 0]]
	}

	array set vars $var_hash
	set conf_item_new_sql "
		select im_conf_item__new(
			null,
			'im_conf_item',
			now(),
			:current_user_id,
			:peeraddr,
			null,
			:conf_item_name,
			:conf_item_nr,
			:conf_item_parent_id,
			:conf_item_type_id,
			:conf_item_status_id
		)
	"

	# Set defaults.
	set conf_item_name $vars(conf_item_name)
	set conf_item_nr $conf_item_name
	set conf_item_code $conf_item_name
	set conf_item_parent_id ""
	set conf_item_status_id [im_conf_item_status_active]
	set conf_item_type_id [im_conf_item_type_hardware]
	set conf_item_version ""
	set conf_item_owner_id $current_user_id
	set description ""
	set note ""

	# Override defaults
	if {[info exists vars(conf_item_nr)]} { set conf_item_nr $vars(conf_item_nr) }
	if {[info exists vars(conf_item_code)]} { set conf_item_code $vars(conf_item_nr) }
	if {[info exists vars(conf_item_parent_id)]} { set conf_item_parent_id $vars(conf_item_parent_id) }
	if {[info exists vars(conf_item_status_id)]} { set conf_item_status_id $vars(conf_item_status_id) }
	if {[info exists vars(conf_item_type_id)]} { set conf_item_type_id $vars(conf_item_type_id) }
	if {[info exists vars(conf_item_version)]} { set conf_item_version $vars(conf_item_version) }
	if {[info exists vars(conf_item_owner_id)]} { set conf_item_owner_id $vars(conf_item_owner_id) }
	if {[info exists vars(description)]} { set description $vars(description) }
	if {[info exists vars(note)]} { set note $vars(note) }

	# Check if the item already exists
	set conf_item_id [db_string exists "
		select	conf_item_id
		from	im_conf_items
		where
			conf_item_parent_id = :conf_item_parent_id and
			conf_item_nr = :conf_item_nr
	" -default 0]

	# Create a new item if necessary
	if {!$conf_item_id} { set conf_item_id [db_string new $conf_item_new_sql] }

	# Update the item with additional variables from the vars array
	set sql_list [list]
	foreach var [array names vars] {
	    if {$var eq "conf_item_id"} { continue }
	    lappend sql_list "$var = :$var"
	}
	set sql "
		update im_conf_items set
		[join $sql_list ",\n"]
		where conf_item_id = :conf_item_id
	"
	db_dml update_conf_item $sql
	return $conf_item_id
    }


    ad_proc -public audit {
	-conf_item_id:required
	-action:required
    } {
	Write the audit trail
    } {
	# Write Audit Trail
	im_audit -object_id $conf_item_id -action $action
    }


    ad_proc -public nuke {
	-conf_item_id:required
    } {
	Permanently deletes the ConfItem from the database.
	This is only suitable for test purposes. During production operations,
	please set the ConfItem's status to "deleted".
    } {
	return [im_conf_item_nuke -conf_item_id $conf_item_id]
    }


    ad_proc -public check_permissions {
	{-check_only_p 0}
	-conf_item_id:required
	-operation:required
    } {
	Check if the user can perform view, read, write or admin the conf_item
    } {
	set user_id [ad_conn user_id]
	set user_name [im_name_from_user_id $user_id]
	im_conf_item_permissions $user_id $conf_item_id view read write admin
	if {[lsearch {view read write admin} $operation] < 0} { 
	    ad_return_complaint 1 "Invalid operation '$operation':<br>Expected view, read, write or admin"
	    ad_script_abort
	}
	set perm [set $operation]

	# Just return the result check_only_p is set
	if {$check_only_p} { return $perm }

 	if {!$perm} { 
	    set action_forbidden_msg [lang::message::lookup "" intranet-helpdesk.Forbidden_operation_on_conf_item "
	    <b>Unable to perform operation '%operation%'</b>:<br>You don't have the necessary permissions for conf_item #%conf_item_id%."]
	    ad_return_complaint 1 $action_forbidden_msg 
	    ad_script_abort
	}
	return $perm
    }

    ad_proc -public set_status_id {
	-conf_item_id:required
	-conf_item_status_id:required
    } {
	Set the conf_item to the specified status.
    } {
	set user_id [ad_conn user_id]
	set user_name [im_name_from_user_id $user_id]
	set operation "set_status_id"

	# Fraber 140202: Permission should be checked using check_permissions above!
	im_conf_item_permissions $user_id $conf_item_id view read write admin
	if {!$write} {
	    set action_forbidden_msg [lang::message::lookup "" intranet-helpdesk.Forbidden_operation_on_conf_item "
	    <b>Unable to perform operation '%operation%'</b>:<br>You don't have the necessary permissions for conf_item #%conf_item_id%."]
	    ad_return_complaint 1 $action_forbidden_msg 
	    ad_script_abort
	}

	# Set the status
	audit -conf_item_id $conf_item_id -action "before_update"
	db_dml update_conf_item_status "
		update im_conf_items set 
			conf_item_status_id = :conf_item_status_id
		where conf_item_id = :conf_item_id
	"
	audit -conf_item_id $conf_item_id -action "after_update"
    }


}




# ----------------------------------------------------------------------
# Generate generic select SQL for Conf Items
# to be used in list pages, options, ...
# ---------------------------------------------------------------------


ad_proc -public im_conf_item_select_sql { 
    {-type_id ""} 
    {-status_id ""} 
    {-project_id ""} 
    {-owner_id ""} 
    {-member_id ""}
    {-cost_center_id ""} 
    {-var_list "" }
    {-parent_id ""}
    {-treelevel ""}
    {-current_user_id ""}
} {
    Returns an SQL statement that allows you to select a range of
    configuration items, given a number of conditions.
    This SQL is used for example in the ConfItemListPage, in
    im_conf_item_options and others.
    The variable names returned by the SQL adhere to the ]po[ coding
    standards. Important returned variables include:
	- im_conf_items.*, (all fields from the base table)
	- conf_item_status, conf_item_type, (status and type human readable)
    The result set is a conjunction (and-connection) of the specified
    conditions:
	- type_id & status_id: Limit type and status, including sub-types and states
	- project_id: Returns CIs associated with project
	- owner_id: Checks for the specific conf_item_owner_id
	- member_id: Check for owner_id OR association relationship.
} {
    # Prepare and check some variables.
    if {![ns_conn isconnected]} {
	# Not connected. We can't do much...
	if {"" eq $current_user_id} { set current_user_id 0 }
    } else {
	set current_user_id [ad_conn user_id]
    }

    set view_conf_items_all_p [im_permission $current_user_id "view_conf_items_all"]

    # base url, where only the conf_item_id has to be added
    set conf_item_base_url "/intranet-confdb/new?form_mode=display&conf_item_id="

    im_security_alert_check_integer -location im_conf_item_select_sql -value $type_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $status_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $project_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $cost_center_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $member_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $owner_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $parent_id
    im_security_alert_check_integer -location im_conf_item_select_sql -value $treelevel

    # Deal with generically passed variables as replacement of parameters.
    array set var_hash $var_list
    foreach var_name [array names var_hash] { set $var_name $var_hash($var_name) }

    set extra_froms [list]
    set extra_wheres [list]

    # Member: Either owner or membership_rel
    if {"" != $member_id && 0 != $member_id} {
	lappend extra_wheres "(
		i.conf_item_owner_id = $member_id
	OR	i.conf_item_id in (
		select	r.object_id_two
		from	acs_rels r
		where	r.object_id_one = $member_id
	))"
    }

    # Owner: Check for conf_item_owner_id field
    if {"" != $owner_id && 0 != $owner_id} {
	lappend extra_wheres "(i.conf_item_owner_id = $owner_id OR i.conf_item_id in (select object_id_two from acs_rels where object_id_one = $owner_id))"
    }

    if {"" != $project_id && 0 != $project_id} {
	# lappend extra_wheres "project_rel.object_id_two = i.conf_item_id"
	# lappend extra_wheres "project_rel.object_id_one = $project_id"
	# lappend extra_froms "acs_rels project_rel"

	lappend extra_wheres "i.conf_item_id in (
		-- CIs related to the current project
		select	sub_ci.conf_item_id
		from	im_projects p,
			im_projects sub_p,
			acs_rels r2,
			im_conf_items ci,
			im_conf_items sub_ci
		where	p.project_id = $project_id and
			sub_p.tree_sortkey between p.tree_sortkey and tree_right(p.tree_sortkey) and
			r2.object_id_one = sub_p.project_id and
			r2.object_id_two = ci.conf_item_id and
			sub_ci.tree_sortkey between ci.tree_sortkey and tree_right(ci.tree_sortkey)
        )"
    }

    # -----------------------------------------------
    # Permissions

    set perm_where ""
    if {!$view_conf_items_all_p} {
	set perm_where "
	i.conf_item_id in (
		-- User is explicit member of conf item
		select	ci.conf_item_id
		from	im_conf_items ci,
			acs_rels r
		where	r.object_id_two = $current_user_id and
			r.object_id_one = ci.conf_item_id
	UNION
		-- User is a member of a group that is explicit member of conf item
		select	ci.conf_item_id
		from	im_conf_items ci,
			acs_rels r
		where	r.object_id_one = ci.conf_item_id and
			r.object_id_two in (
				select	group_id
				from	group_distinct_member_map
				where	member_id = $current_user_id
			)
	UNION
		-- User belongs to project that belongs to conf item
		select	ci.conf_item_id
		from	im_conf_items ci,
			im_projects p,
			acs_rels r1,
			acs_rels r2
		where	r1.object_id_two = $current_user_id and
			r1.object_id_one = p.project_id and
			r2.object_id_two = ci.conf_item_id and
			r2.object_id_one = p.project_id
	UNION
		-- User belongs to project that belongs to conf item
		select	sub_ci.conf_item_id
		from	acs_rels r1,
			im_projects p,
			im_projects sub_p,
			acs_rels r2,
			im_conf_items ci,
			im_conf_items sub_ci
		where	r1.object_id_two = $current_user_id and
			r1.object_id_one = p.project_id and
			sub_p.tree_sortkey between p.tree_sortkey and tree_right(p.tree_sortkey) and
			r2.object_id_one = sub_p.project_id and
			r2.object_id_two = ci.conf_item_id and
			sub_ci.tree_sortkey between ci.tree_sortkey and tree_right(ci.tree_sortkey)
	UNION
		-- User belongs to a company which is the customer of project that belongs to conf item
		select	ci.conf_item_id
		from	im_companies c,
			im_conf_items ci,
			im_projects p,
			acs_rels r1,
			acs_rels r2
		where	r1.object_id_two = $current_user_id and
			r1.object_id_one = c.company_id and
			p.company_id = c.company_id and
			r2.object_id_two = ci.conf_item_id and
			r2.object_id_one = p.project_id
	)
    "
    }

    set project_perm_sql "
	select  pp.project_id,
		bom.object_role_id as role_id
	from
		im_projects pp,
		acs_rels r,
		im_biz_object_members bom
	where
		r.object_id_one = pp.project_id and
		r.object_id_two = :user_id and
		r.rel_id = bom.rel_id and
		pp.tree_sortkey in (
			-- Walk up the conf item is-part-of hierarchy and collect
			-- all projects for which the CI is a member.
			-- Returns the list of all these projects and their parents.
			select  tree_ancestor_keys(p.tree_sortkey)
			from    im_conf_items ci,
				acs_rels r,
				im_projects p
			where   r.object_id_two = ci.conf_item_id and
				r.object_id_one = p.project_id and
				ci.tree_sortkey in (
					select  tree_ancestor_keys(sci.tree_sortkey)
					from    im_conf_items sci
					where   sci.conf_item_id = :conf_item_id
				)
			)
    "


    # -----------------------------------------------
    # Join the query parts

    if {"" != $cost_center_id} { lappend extra_wheres "i.conf_item_cost_center_id = $cost_center_id" }
    if {"" != $status_id} { lappend extra_wheres "i.conf_item_status_id in ([join [im_sub_categories $status_id] ","])" }
    if {"" != $type_id} { lappend extra_wheres "i.conf_item_type_id in ([join [im_sub_categories $type_id] ","])" }
    if {"" != $treelevel} { lappend extra_wheres "tree_level(i.tree_sortkey) <= 1+$treelevel" }
    if {"" != $perm_where} { lappend extra_wheres $perm_where }
    if {"" != $parent_id} { 
	lappend extra_wheres "parent.conf_item_id = $parent_id" 
	lappend extra_wheres "i.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)" 
	lappend extra_wheres "i.conf_item_id != parent.conf_item_id" 
	lappend extra_froms "im_conf_items parent"
    }

    set extra_from [join $extra_froms "\n\t\t,"]
    set extra_where [join $extra_wheres "\n\t\tand "]

    if {"" != $extra_from} { set extra_from ",$extra_from" }
    if {"" != $extra_where} { set extra_where "and $extra_where" }

    set select_sql "
	select distinct
		i.*,
		tree_level(i.tree_sortkey)-1 as conf_item_level,
		im_category_from_id(i.conf_item_status_id) as conf_item_status,
		im_category_from_id(i.conf_item_type_id) as conf_item_type,
		im_conf_item_name_from_id(i.conf_item_parent_id) as conf_item_parent,
		im_cost_center_code_from_id(i.conf_item_cost_center_id) as conf_item_cost_center,
		im_name_from_user_id(i.conf_item_owner_id) as conf_item_owner,
		'$conf_item_base_url' || i.conf_item_id as conf_item_url
	from	im_conf_items i	
		$extra_from
	where	1=1 
		$extra_where
	order by
		i.tree_sortkey
    "

    return $select_sql
}

ad_proc -public im_conf_item_update_sql { 
    {-include_dynfields_p 0}
} {
    Returns an SQL statement that updates all Conf Item fields from
    variables according to the ]po[ coding conventions.
} {
    set update_sql "
	update im_conf_items set
		conf_item_name =		:conf_item_name,
		conf_item_nr =			:conf_item_nr,
		conf_item_code =		:conf_item_code,
		conf_item_version =		:conf_item_version,
		conf_item_parent_id =		:conf_item_parent_id,
		conf_item_type_id =		:conf_item_type_id,
		conf_item_status_id =		:conf_item_status_id,
		conf_item_owner_id =		:conf_item_owner_id,
		conf_item_cost_center_id =      :conf_item_cost_center_id,
		description = 			:description,
		note = 				:note
	where conf_item_id = :conf_item_id
    "
}


# ----------------------------------------------------------------------
# Permissions
# ---------------------------------------------------------------------


ad_proc -public im_conf_item_permissions {user_id conf_item_id view_var read_var write_var admin_var} {
    Fill the "by-reference" variables read, write and admin
    with the permissions of $user_id on $conf_item_id
} {
    upvar $view_var view
    upvar $read_var read
    upvar $write_var write
    upvar $admin_var admin

    set read [im_permission $user_id view_conf_items_all]
    set write [im_permission $user_id edit_conf_items_all]
    set admin [im_permission $user_id edit_conf_items_all]

    set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
    set user_is_wheel_p [im_profile::member_p -profile_id [im_wheel_group_id] -user_id $user_id]
    set user_is_group_member_p [im_biz_object_member_p $user_id $conf_item_id]
    set user_is_group_admin_p [im_biz_object_admin_p $user_id $conf_item_id]

    # Admin permissions to global + intranet admins + group administrators
    set user_admin_p [expr {$user_is_admin_p || $user_is_group_admin_p || $user_is_wheel_p}]
    if {$user_admin_p} {
	set read 1
	set write 1
	set admin 1
    }

    if {$user_is_group_member_p} {
	set read 1
    }

    # Project-based permissions - Check if the current user is an explicit member
    # of a project, to which the ConfItem belongs
    # Normal membership of the project is sufficient to get write permission on the
    # conf item(?)
    set project_perm_sql "
	select  pp.project_id,
		bom.object_role_id as role_id
	from
		im_projects pp,
		acs_rels r,
		im_biz_object_members bom
	where
		r.object_id_one = pp.project_id and
		r.object_id_two = :user_id and
		r.rel_id = bom.rel_id and
		pp.tree_sortkey in (
			-- Walk up the conf item is-part-of hierarchy and collect
			-- all projects for which the CI is a member.
			-- Returns the list of all these projects and their parents.
			select  tree_ancestor_keys(p.tree_sortkey)
			from    im_conf_items ci,
				acs_rels r,
				im_projects p
			where   r.object_id_two = ci.conf_item_id and
				r.object_id_one = p.project_id and
				ci.tree_sortkey in (
					select  tree_ancestor_keys(sci.tree_sortkey)
					from    im_conf_items sci
					where   sci.conf_item_id = :conf_item_id
				)
			)
    "
    # ad_return_complaint 1 "<pre>[im_ad_hoc_query $project_perm_sql]</pre>"
    db_foreach project_perms $project_perm_sql {
	# normal project members only get read permissions on the conf items
	set read 1
	# PMs get write permissions on the conf items
	if {[im_biz_object_role_project_manager] eq $role_id} { 
	    set write 1 
	}
    }

    # Tricky: Check if the user is the owner of one of the parent CIs...
    # ToDo: not yet implemented...

    # No explict view perms - set to tread
    set view $read

    # No read - no write...
    if {!$read} {
	set write 0
	set admin 0
    }

    # ad_return_complaint 1 "$read $write $admin"
}


# ----------------------------------------------------------------------
# Configurable list of Configuration Items
# ---------------------------------------------------------------------

ad_proc -public im_conf_item_list_component {
    {-debug 0}
    {-object_id 0}
    {-owner_id 0}
    {-member_id 0}
    {-view_name "im_conf_item_list_short"} 
    {-order_by ""} 
    {-restrict_to_member_id 0} 
    {-restrict_to_type_id 0} 
    {-restrict_to_status_id 0} 
    {-max_entries_per_page 5000}
    {-export_var_list {} }
    {-return_url "" }
} {
    Creates a HTML table showing a list of configuration items associated with
    a project, a task, a user or a ticket.
} {
    # ---------------------- Security - Show the comp? -------------------------------
    set current_user_id [auth::require_login]
    set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]
    set org_object_id $object_id

    if {"" == $member_id || 0 == $member_id} { set member_id $restrict_to_member_id }
    if {"" == $order_by} {
	set order_by [parameter::get_from_package_key -package_key intranet-confdb -parameter ConfItemComponentDefaultSortOrder -default "tree_sortkey"] 
    }

    # URL to toggle open/closed tree
    set open_close_url "/intranet/biz-object-tree-open-close"    

    # Permissions
    set object_view 0
    set object_read 0
    set object_write 0
    set object_admin 0
    set object_type [db_string acs_object_type "select object_type from acs_objects where object_id = :org_object_id" -default ""]
    if {"" != $object_type} {
	set perm_cmd "${object_type}_permissions \$current_user_id \$object_id object_view object_read object_write object_admin"
	eval $perm_cmd
    }


    # ---------------------- Defaults ----------------------------------
    # Get parameters from HTTP session
    # Don't trust the container page to pass-on that value...
    set form_vars [ns_conn form]
    if {"" == $form_vars} { set form_vars [ns_set create] }

    # Get the start_idx in case of pagination
    set start_idx [ns_set get $form_vars "conf_item_start_idx"]
    if {"" == $start_idx} { set start_idx 0 }
    set end_idx [expr {$start_idx + $max_entries_per_page - 1}]

    set bgcolor(0) " class=roweven"
    set bgcolor(1) " class=rowodd"
    set date_format "YYYY-MM-DD"

    set current_url [im_url_with_query]

    if {![info exists current_page_url]} { set current_page_url [ad_conn url] }
    if {(![info exists return_url] || $return_url eq "")} { set return_url $current_url }
    # Get the "view" (=list of columns to show)
    set view_id [db_string get_view_id "select view_id from im_views where view_name = :view_name" -default 0]

    if {0 == $view_id} {
	ns_log Error "im_conf_item_list_component: we didn't find view_name=$view_name"
	set view_name "im_conf_item_list"
	set view_id [db_string get_view_id "select view_id from im_views where view_name=:view_name" -default 0]
    }

    if {$debug} { ns_log Notice "im_conf_item_list_component: view_id=$view_id" }
    if {0 == $view_id} {
	return [lang::message::lookup "" intranet-core.lt_Internal_error_unknow "Unknown View: $view_name, please inform your System Adminitrator"]
    }

    # ---------------------- Get Columns ----------------------------------
    # Define the column headers and column contents that
    # we want to show:
    #
    set column_headers [list]
    set column_vars [list]
    set admin_links [list]
    set extra_selects [list]
    set extra_froms [list]
    set extra_wheres [list]
    set view_order_by_clause ""

    set column_sql "
	select	*
	from	im_view_columns
	where	view_id = :view_id
		and group_id is null
	order by sort_order
    "
    set col_span 0
    db_foreach column_list_sql $column_sql {
	if {"" == $visible_for || [eval $visible_for]} {
	    lappend column_headers "$column_name"
	    lappend column_vars "$column_render_tcl"
	    lappend admin_links "<a href=[export_vars -base "/intranet/admin/views/new-column" {return_url column_id {form_mode edit}}] target=\"_blank\">[im_gif wrench]</a>"

	    if {"" != $extra_select} { lappend extra_selects $extra_select }
	    if {"" != $extra_from} { lappend extra_froms $extra_from }
	    if {"" != $extra_where} { lappend extra_wheres $extra_where }
	    if {"" != $order_by_clause && $order_by == $column_name} { set view_order_by_clause $order_by_clause }
	}
	incr col_span
    }
    if {$debug} { ns_log Notice "im_conf_item_list_component: column_headers=$column_headers" }

    # -------- Compile the list of parameters to pass-through-------
    set form_vars [ns_conn form]
    if {"" == $form_vars} { set form_vars [ns_set create] }

    set bind_vars [ns_set create]
    foreach var $export_var_list {
	upvar 1 $var value
	if { [info exists value] } {
	    ns_set put $bind_vars $var $value
	    if {$debug} { ns_log Notice "im_conf_item_list_component: $var <- $value" }
	} else {
	    set value [ns_set get $form_vars $var]
	    if {$value ne ""} {
 		ns_set put $bind_vars $var $value
 		if {$debug} { ns_log Notice "im_conf_item_list_component: $var <- $value" }
	    }
	}
    }

    ns_set delkey $bind_vars "order_by"
    ns_set delkey $bind_vars "conf_item_start_idx"
    set params [list]
    set len [ns_set size $bind_vars]
    for {set i 0} {$i < $len} {incr i} {
	set key [ns_set key $bind_vars $i]
	set value [ns_set value $bind_vars $i]
	if {$value ne "" } {
	    lappend params "$key=[ns_urlencode $value]"
	}
    }
    set pass_through_vars_html [join $params "&"]


    # ---------------------- Format Header ----------------------------------
    # Set up colspan to be the number of headers + 1 for the # column
    set colspan [expr {[llength $column_headers] + 1}]

    # Format the header names with links that modify the
    # sort order of the SQL query.
    #
    set col_ctr 0
    set admin_link ""
    set table_header_html ""
    foreach col $column_headers {
	set cmd_eval ""
	set cmd "set cmd_eval $col"
	eval $cmd
	regsub -all " " $cmd_eval "_" cmd_eval_subs

	# Only localize "reasonable" strings...
	if {[regexp {^[a-zA-Z0-9_\.\ ]+$} $cmd_eval_subs]} {
	    set cmd_eval [lang::message::lookup "" intranet-timesheet2-tasks.$cmd_eval_subs $cmd_eval]
	}

	if {$user_is_admin_p} { set admin_link [lindex $admin_links $col_ctr] } else { set admin_link "" }
	append table_header_html "  <td class=\"rowtitle\">$cmd_eval$admin_link</td>\n"
	incr col_ctr
    }

    set table_header_html "
	<thead>
	    <tr class=tableheader>$table_header_html</tr>
	</thead>
    "
    
    # ---------------------- Build the SQL query ---------------------------
    set order_by_clause "order by ci.tree_sortkey"
    set order_by_clause_ext "order by conf_item_nr, conf_item_name"
    switch $order_by {
	"Status" { 
	    set order_by_clause "order by ci.conf_item_status_id" 
	    set order_by_clause_ext "m.conf_item_id"
	}
    }
	
    # ---------------------- Calculate the Children's restrictions -------------------------
    set criteria [list]

    if {[string is integer $restrict_to_status_id] && $restrict_to_status_id > 0} {
	lappend criteria "sub_ci.conf_item_status_id in ([join [im_sub_categories $restrict_to_status_id] ","])"
    }

    if {[string is integer $restrict_to_type_id] && $restrict_to_type_id > 0} {
	lappend criteria "sub_ci.conf_item_type_id in ([join [im_sub_categories $restrict_to_type_id] ","])"
    }

    # Owner is stictly the owner_id of the conf_item
    if {[string is integer $owner_id] && $owner_id > 0} {
	lappend criteria "sub_ci.conf_item_owner_id = :owner_id"
    }

    # Member is anybody associated with the conf item + the owner.
    # Challenge: We also need to show the parents of sub-items with that member.
    # We assume that there are few ConfItems per user only...
    if {[string is integer $member_id] && $member_id > 0} {

	# Get the list of CIs who are directly associated with $member_id
	set new_parents [db_list user_conf_items "
		select	ci.conf_item_id
		from	im_conf_items ci,
			acs_rels r
		where	r.object_id_one = ci.conf_item_id and
			r.object_id_two = :member_id
	UNION
		select	ci.conf_item_id
		from	im_conf_items ci
		where	ci.conf_item_owner_id = :member_id
	"]

	# Loop through all parents of member_id CIs
	set result_list [list 0]
	set cnt 0
	while {[llength $new_parents] > 0} {
	    set result_list [concat $result_list $new_parents]
	    set new_parents [db_list new_parents "
		select distinct
			conf_item_parent_id
		from	im_conf_items
		where	conf_item_parent_id is not null and
			conf_item_id in ([join $new_parents ","])
	    "]
	    incr cnt
	    if {$cnt > 10} { ad_return_complaint 1 "im_conf_item_list_component: Infinite loop looking for parent: '$new_parents'" }
	}

	# Restrict to this list of direct members and their parents
	lappend criteria "sub_ci.conf_item_id in ([join $result_list ","])"
    }

    if {![im_permission $current_user_id "view_conf_items_all"]} {
	lappend criteria "sub_ci.conf_item_id in (
			select	ci.conf_item_id
			from	im_conf_items ci,
				acs_rels r
			where	r.object_id_one = ci.conf_item_id and 
				r.object_id_two = :current_user_id
			)
	"
	lappend criteria "main_ci.conf_item_id in (
			select	ci.conf_item_id
			from	im_conf_items ci,
				acs_rels r
			where	r.object_id_one = ci.conf_item_id and 
				r.object_id_two = :current_user_id
			)
	"
    }

    set restriction_clause [join $criteria "\n\tand "]
    if {"" != $restriction_clause} { 
	set restriction_clause "and $restriction_clause" 
    }

    set extra_select [join $extra_selects ",\n\t"]
    if { $extra_select ne "" } { set extra_select ",\n\t$extra_select" }

    set extra_from [join $extra_froms ",\n\t"]
    if { $extra_from ne "" } { set extra_from ",\n\t$extra_from" }

    set extra_where [join $extra_wheres "and\n\t"]
    if { $extra_where ne "" } { set extra_where "and \n\t$extra_where" }


    # ---------------------- Get the SQL Query -------------------------

    switch $object_type {
	user {
	    set conf_item_sql [im_conf_item_select_sql -owner_id $org_object_id]
	}
	default {
	    set conf_item_sql [im_conf_item_select_sql \
				   -project_id $org_object_id \
				   -treelevel "" \
				   -type_id "" \
				   -status_id "" \
				   -owner_id "" \
				   -cost_center_id "" \
				  ]
	}
    }
    # ad_return_complaint 1 "object_type=$object_type<br><pre>$conf_item_sql</pre><br>[im_ad_hoc_query -format html $conf_item_sql]"

    db_multirow conf_item_list_multirow conf_item_list_sql $conf_item_sql {

	# Perform the following steps in addition to calculating the multirow:
	# The list of all conf_items
	set all_conf_items_hash($conf_item_id) 1

	# The list of conf_items that have a sub-conf_item
	set parents_hash($conf_item_parent_id) 1
    }

    # ----------------------------------------------------
    # Determine closed CIs and their children

    # Store results in hash array for faster join
    # Only store positive "closed" branches in the hash to save space+time.
    # Determine the sub-conf_items that are also closed.
    set oc_sub_sql "
	select	child.conf_item_id as child_id
	from	im_conf_items child,
		im_conf_items parent
	where	parent.conf_item_id in (
			select	ohs.object_id
			from	im_biz_object_tree_status ohs
			where	ohs.open_p = 'c' and
				ohs.user_id = :current_user_id and
				ohs.page_url = 'default' and
				ohs.object_id in (
					select	conf_item_id
					from	($conf_item_sql) t
				)
			) and
		child.tree_sortkey between parent.tree_sortkey and tree_right(parent.tree_sortkey)
    "
    db_foreach oc_sub $oc_sub_sql {
	set closed_conf_items_hash($child_id) 1
    }

    # Calculate the list of leaf conf_items
    set all_conf_items_list [array names all_conf_items_hash]
    set parents_list [array names parents_hash]
    set leafs_list [set_difference $all_conf_items_list $parents_list]
    foreach leaf_id $leafs_list { set leafs_hash($leaf_id) 1 }

    if {$debug} { 
	ns_log Notice "im_conf_item_list_component: all_conf_items_list=$all_conf_items_list"
	ns_log Notice "im_conf_item_list_component: parents_list=$parents_list"
	ns_log Notice "im_conf_item_list_component: leafs_list=$leafs_list"
	ns_log Notice "im_conf_item_list_component: closed_conf_items_list=[array get closed_conf_items_hash]"
	ns_log Notice "im_conf_item_list_component: "
    }

    # Render the multirow
    set table_body_html ""
    set ctr 0
    set idx $start_idx
    set old_conf_item_id 0

    # ----------------------------------------------------
    # Render the list of CIs
    template::multirow foreach conf_item_list_multirow {

	# Skip this entry completely if the parent of this conf_item is closed
	if {[info exists closed_conf_items_hash($conf_item_parent_id)]} { continue }

	set indent_html ""
	set indent_short_html ""
	for {set i 0} {$i < $conf_item_level} {incr i} {
	    append indent_html "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
	    append indent_short_html "&nbsp;&nbsp;&nbsp;"
	}

	if {[info exists closed_conf_items_hash($conf_item_id)]} {
	    # Closed conf_item
	    set gif_html "<a href='[export_vars -base $open_close_url {{user_id $current_user_id} {page_url "default"} {object_id $conf_item_id} {open_p "o"} return_url}]'>[im_gif "plus_9"]</a>"
	} else {
	    # So this is an open conf_item - show a "(-)", unless the conf_item is a leaf.
	    set gif_html "<a href='[export_vars -base $open_close_url {{user_id $current_user_id} {page_url "default"} {object_id $conf_item_id} {open_p "c"} return_url}]'>[im_gif "minus_9"]</a>"
	    if {[info exists leafs_hash($conf_item_id)]} { set gif_html "&nbsp;" }
	}

	set object_url [export_vars -base "/intranet-confdb/new" {{conf_item_id $conf_item_id} {form_mode display} return_url}]

	# Table fields for timesheet conf_items
	set status_select [im_category_select {Intranet Conf Item Status} conf_item_status_id.$conf_item_id $conf_item_status_id]

	set conf_item_name "<nobr>[string range $conf_item_name 0 20]</nobr>"

	# We've got a conf_item.
	# Write out a line with conf_item information
	append table_body_html "<tr$bgcolor([expr {$ctr % 2}])>\n"

	foreach column_var $column_vars {
	    append table_body_html "\t<td valign=top>"
	    set cmd "append table_body_html $column_var"
	    eval $cmd
	    append table_body_html "</td>\n"
	}
	append table_body_html "</tr>\n"

	# Update the counter.
	incr ctr
	if { $max_entries_per_page > 0 && $ctr >= $max_entries_per_page } {
	    set more_url [export_vars -base "/intranet-confdb/index" {{conf_item_id $object_id} {view_name "im_conf_item_conf_item_list"}}]
	    append table_body_html "
		<tr><td colspan=99>
		<b>[lang::message::lookup "" intranet-confdb.List_cut_at_n_entries "List cut at %max_entries_per_page% entries"]</b>.
		[lang::message::lookup "" intranet-confdb.List_cut_at_n_entries_msg "
			Please click <a href=%more_url%>here</a> for the entire list.
		"]
		</td></tr>\n"
	    break
	}
    }

    # ----------------------------------------------------
    # Show a reasonable message when there are no result rows:
    if { $table_body_html eq "" } {

	set table_body_html "
		<tr class=table_list_page_plain>
			<td colspan=$colspan align=left>
			<b>[_ intranet-confdb.There_are_no_active_conf_items]</b>
			</td>
		</tr>
	"
    }


    if { "im_project" == [acs_object_type $org_object_id] } {
	set new_conf_item_url [export_vars -base "/intranet-confdb/new" {{form_mode edit} {return_url $current_url} {conf_item_project_id $org_object_id}}]
    } else {
	set new_conf_item_url [export_vars -base "/intranet-confdb/new" {{form_mode edit} {return_url $current_url}}]
    }

    set table_body_html_ul ""
    if {$object_write} { 
	append table_body_html_ul "
		<li><a href=\"[export_vars -base "/intranet-confdb/associate-conf-item-with-task" {{object_id $org_object_id} {return_url $current_url}}]\"
		>[lang::message::lookup "" intranet-confdb.Associate_New_Conf_Item "Associate new Conf Item"]</a>
        "
    }
    if {[im_permission $current_user_id "add_conf_items"]} {
	append table_body_html_ul "
		<li><a href=\"$new_conf_item_url\">[lang::message::lookup "" intranet-confdb.Create_New_Conf_Item "Create new Conf Item"]</a>
        "
    }

    append table_body_html "
	<tr>
	<td colspan=$colspan>
	<ul>
                $table_body_html_ul
	</ul>
	</td>
	</tr>
    "
    
    set total_in_limited 0

    # Deal with pagination
    if {$ctr == $max_entries_per_page && $end_idx < [expr {$total_in_limited - 1}]} {
	# This means that there are rows that we decided not to return
	# Include a link to go to the next page
	set next_start_idx [expr {$end_idx + 1}]
	set conf_item_max_entries_per_page $max_entries_per_page
	set next_page_url  "[export_vars -base $current_page_url {conf_item_id conf_item_object_id conf_item_max_entries_per_page order_by}]&conf_item_start_idx=$next_start_idx&$pass_through_vars_html"
	set next_page_html "($remaining_items more) <A href=\"$next_page_url\">&gt;&gt;</a>"
    } else {
	set next_page_html ""
    }
    
    if { $start_idx > 0 } {
	# This means we didn't start with the first row - there is
	# at least 1 previous row. add a previous page link
	set previous_start_idx [expr {$start_idx - $max_entries_per_page}]
	if { $previous_start_idx < 0 } { set previous_start_idx 0 }
	set previous_page_html "<A href=[export_vars -base $current_page_url {conf_item_id}]&$pass_through_vars_html&order_by=$order_by&conf_item_start_idx=$previous_start_idx>&lt;&lt;</a>"
    } else {
	set previous_page_html ""
    }
    

    # ---------------------- Format the action bar at the bottom ------------

    set table_footer_action "
	<table width='100%'>
	<tr>
	<td align=right>
		<select name=action>
		<option value=save>[lang::message::lookup "" intranet-confdb.Save_Changes "Save Changes"]</option>
		<option value=delete>[_ intranet-confdb.Delete]</option>
		</select>
		<input type=submit name=submit value='[_ intranet-confdb.Apply]'>
	</td>
	</tr>
	</table>
    "
    set table_footer_action ""

    set table_footer "
	<tfoot>
	<tr>
	  <td class=rowplain colspan=$colspan align=right>
	    $previous_page_html
	    $next_page_html
	    $table_footer_action
	  </td>
	</tr>
	<tfoot>
    "

    # ---------------------- Join all parts together ------------------------

    set component_html "
	<form action=/intranet-confdb/conf_item-action method=POST>
	[export_vars -form {conf_item_id return_url}]
	<table bgcolor=white border=0 cellpadding=1 cellspacing=1 class=\"table_list_page\">
	  $table_header_html
	  $table_body_html
	  $table_footer
	</table>
	</form>
    "

    return $component_html
}


# ----------------------------------------------------------------------
# Options for ad_form
# ---------------------------------------------------------------------

ad_proc -public im_conf_item_options { 
    {-include_empty_p 0} 
    {-include_empty_name ""} 
    {-type_id ""} 
    {-status_id ""} 
    {-project_id ""} 
    {-owner_id ""} 
    {-cost_center_id ""} 
} {
    Returns a list of all Conf Items.
} {
    set var_list [list type_id $type_id status_id $status_id project_id $project_id owner_id $owner_id cost_center_id $cost_center_id]
    set options_sql [im_conf_item_select_sql -treelevel 2 -var_list $var_list]

    set options [list]
    if {$include_empty_p} { lappend options [list $include_empty_name ""] }

    set cnt 0
    db_foreach conf_item_options $options_sql {
	set conf_item_name [string range $conf_item_name 0 69 ]
	set spaces ""
	for {set i 0} {$i < $conf_item_level} { incr i } {
	    append spaces "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
	}
	lappend options [list "$spaces$conf_item_name" $conf_item_id]
	incr cnt
    }

    if {!$cnt && $include_empty_p} {
	set not_found [lang::message::lookup "" intranet-confdb.No_Conf_Items_Found "No Conf Items found"]
	lappend options [list $not_found ""]
    }

    return $options
}

# ----------------------------------------------------------------------
# Components
# ---------------------------------------------------------------------

ad_proc -public im_conf_item_list_component_old {
    { -object_id 0 }
    { -owner_id 0 }
} {
    Returns a HTML component to show all project related conf items
} {
    set params [list \
	[list base_url "/intranet-confdb/"] \
	[list object_id $object_id] \
	[list owner_id $owner_id] \
	[list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-confdb/lib/conf-item-list-component"]
    set result [string trim $result]
    return [string trim $result]
}


# ----------------------------------------------------------------------
# Conf Item - Project Relationship
# ---------------------------------------------------------------------

ad_proc -public im_conf_item_new_project_rel {
    -project_id:required
    -conf_item_id:required
    {-sort_order 0}
} {
    Establishes as is-conf-item-of relation between conf item and project
} {
    if {"" == $project_id} { ad_return_complaint 1 "Internal Error - project_id is NULL" }
    if {"" == $conf_item_id} { ad_return_complaint 1 "Internal Error - conf_item_id is NULL" }

    set rel_id [db_string rel_exists "
	select	rel_id
	from	acs_rels
	where	object_id_one = :project_id
		and object_id_two = :conf_item_id
    " -default 0]
    if {0 != $rel_id} { return $rel_id }

    return [db_string new-conf-project_rel "
	select im_conf_item_project_rel__new (
		null,
		'im_conf_item_project_rel',
		:project_id,
		:conf_item_id,
		null,
		[ad_conn user_id],
		'[ad_conn peeraddr]',
		:sort_order
	)
    "]
}


# ----------------------------------------------------------------------
# Nuke a Conf Item
# ---------------------------------------------------------------------

ad_proc -public im_conf_item_nuke {
    -conf_item_id:required
} {
    Permanently deletes the ConfItem from the database.
    This is only suitable for test purposes. During production operations,
    please set the ConfItem's status to "deleted".
} {
    set parent_p [db_string parent "select count(*) from im_conf_items where conf_item_parent_id = :conf_item_id"]
    if {$parent_p > 0} { ad_return_complaint 1 "<b>Can't Delete Conf Item</b>:<br>The configuration item is the parent of another conf item. <br>Please delete the children first." }

    # Relationships
    ns_log Notice "projects/nuke-2: rels"
    set rels [db_list rels "
		select rel_id 
		from acs_rels 
		where object_id_one = :conf_item_id 
			or object_id_two = :conf_item_id
    "]

    set im_conf_item_project_rels_exists_p [im_table_exists im_conf_item_project_rels]
    set im_ticket_ticket_rels_exists_p [im_table_exists im_ticket_ticket_rels]
    foreach rel_id $rels {
	db_dml del_rels "delete from group_element_index where rel_id = :rel_id"
	if {[im_column_exists im_biz_object_members skill_profile_rel_id]} {
	    db_dml del_rels "update im_biz_object_members set skill_profile_rel_id = null where skill_profile_rel_id = :rel_id"
	}
	if {[im_table_exists im_gantt_assignment_timephases]} {
	    db_dml del_rels "delete from im_gantt_assignment_timephases where rel_id = :rel_id"
	}
	if {[im_table_exists im_gantt_assignments]} {
	    db_dml del_rels "delete from im_gantt_assignments where rel_id = :rel_id"
	}
	if {[im_table_exists im_agile_task_rels]} {
	    db_dml del_rels "delete from im_agile_task_rels where rel_id = :rel_id"
	}
	db_dml del_rels "delete from im_biz_object_members where rel_id = :rel_id"
	db_dml del_rels "delete from membership_rels where rel_id = :rel_id"
	if {$im_conf_item_project_rels_exists_p} { db_dml del_rels "delete from im_conf_item_project_rels where rel_id = :rel_id" }
	if {$im_ticket_ticket_rels_exists_p} { db_dml del_rels "delete from im_ticket_ticket_rels where rel_id = :rel_id" }
	if {[im_table_exists im_release_items]} {
	    db_dml del_rels "delete from im_release_items where rel_id = :rel_id"
	}

	db_dml del_rels "delete from acs_rels where rel_id = :rel_id"
	db_dml del_rels "delete from acs_objects where object_id = :rel_id"

	db_string del_user_rel "select im_biz_object_member__delete(:object_id_one, :object_id_two)"
    }

    db_dml nuke_ci_context_id "update acs_objects set context_id = null where context_id = :conf_item_id"

    # Delete references in im_tickets to the conf item.
    db_dml del_ticket_refs "update im_tickets set ticket_conf_item_id = NULL where ticket_conf_item_id = :conf_item_id"

    db_string nuke_ci "select im_conf_item__delete(:conf_item_id)"
}


# ----------------------------------------------------------------------
# Navigation Bar Tree
# ---------------------------------------------------------------------

ad_proc -public im_navbar_tree_confdb { } {
    Creates an <ul> ...</ul> collapsable menu for the
    system's main NavBar.
} {
    set wiki [im_navbar_doc_wiki]
    set current_user_id [ad_conn user_id]
    set html "
	<li><a href=/intranet-confdb/index>[lang::message::lookup "" intranet-confdb.Conf_Management "Config Management"]</a>
	<ul>
    "

    # Create new Conf Item
    if {[im_permission $current_user_id add_conf_items]} {
	append html "<li><a href=\"/intranet-confdb/new?form_mode=edit&return_url=/intranet/confdb/index\">[lang::message::lookup "" intranet-confdb.New_Conf_Item "New Conf Item"]</a>\n"
    }

    # Add sub-menu with types of conf_items
    append html "
	<li><a href=\"/intranet-confdb/index\">[lang::message::lookup "" intranet-confdb.Conf_Item_Types "Conf Items Types"]</a>
	<ul>
    "

    if {$current_user_id > 0} {
	set conf_item_type_sql "
		select	t.*
		from	im_conf_item_type t 
		where not exists (select * from im_category_hierarchy h where h.child_id = t.conf_item_type_id)
	"
	db_foreach conf_item_types $conf_item_type_sql {
	    set url [export_vars -base "/intranet-confdb/index" {{type_id $conf_item_type_id}}]
	    regsub -all " " $conf_item_type "_" conf_item_type_subst
	    set name [lang::message::lookup "" intranet-confdb.Conf_Item_type_$conf_item_type_subst "$conf_item_type"]
	    append html "<li><a href=\"$url\">$name</a></li>\n"
	}
    }
    append html "
	</ul>
	</li>
    "


    append html "
	</ul>
	</li>
    "
    return $html
}


# ---------------------------------------------------------------
# Component showing related objects
# ---------------------------------------------------------------

ad_proc -public im_conf_item_related_objects_component {
    -conf_item_id:required
} {
    Returns a HTML component with the list of related tickets.
} {
    set params [list \
		    [list base_url "/intranet-helpdesk/"] \
		    [list conf_item_id $conf_item_id] \
		    [list return_url [im_url_with_query]] \
    ]

    set result [ad_parse_template -params $params "/packages/intranet-confdb/lib/related-objects-component"]
    return [string trim $result]
}




# ---------------------------------------------------------------
# Admin links shown from main menu
# ---------------------------------------------------------------


ad_proc -public im_menu_conf_items_admin_links {

} {
    Return a list of admin links to be added to the "Conf Items" menu
} {
    set result_list {}
    set current_user_id [ad_conn user_id]
    set return_url [im_url_with_query]

    if {[im_is_user_site_wide_or_intranet_admin $current_user_id]} {
	lappend result_list [list [lang::message::lookup "" intranet-confdb.Admin_Conf_Items "Admin Conf Items"] "/intranet-confdb/admin"]
    }

    if {[im_permission $current_user_id "add_conf_items"]} {
#	lappend result_list [list [lang::message::lookup "" intranet-confdb.Add_a_new_Conf_Item "New Conf Item"] "[export_vars -base "/intranet-confdb//new" {return_url}]"]

	set wf_oid_col_exists_p [im_column_exists wf_workflows object_type]
	if {$wf_oid_col_exists_p} {
	set wf_sql "
		select  t.pretty_name as wf_name,
			w.*
		from    wf_workflows w,
			acs_object_types t
		where   w.workflow_key = t.object_type
			and w.object_type = 'im_conf_item'
	"
	    db_foreach wfs $wf_sql {
		set new_from_wf_url [export_vars -base "/intranet-confdb/new" {workflow_key}]
		lappend result_list [list [lang::message::lookup "" intranet-confdb.New_workflow "New %wf_name%"] "$new_from_wf_url"]
	    }
	}
    }

    # Append user-defined menus
    set bind_vars [list return_url $return_url]
    set links [im_menu_ul_list -no_uls 1 -list_of_links 1 "conf_items_admin" $bind_vars]
    foreach link $links {
	lappend result_list $link
    }

    return $result_list
}



# ----------------------------------------------------------------------
# Navigation Bar
# ---------------------------------------------------------------------

ad_proc -public im_conf_item_navbar { 
    {-navbar_menu_label "confdb"}
    default_letter 
    base_url 
    next_page_url 
    prev_page_url 
    export_var_list 
    {select_label ""} 
} {
    Returns rendered HTML code for a horizontal sub-navigation
    bar for /intranet-confdb/.
    The lower part of the navbar also includes an Alpha bar.

    @param default_letter none marks a special behavious, hiding the alpha-bar.
    @navbar_menu_label Determines the "parent menu" for the menu tabs for 
		       search shortcuts, defaults to "projects".
} {
    # -------- Defaults -----------------------------
    set user_id [ad_conn user_id]
    set url_stub [ns_urldecode [im_url_with_query]]

    set sel "<td class=tabsel>"
    set nosel "<td class=tabnotsel>"
    set a_white "<a class=whitelink"
    set tdsp "<td>&nbsp;</td>"

    # -------- Calculate Alpha Bar with Pass-Through params -------
    set bind_vars [ns_set create]
    foreach var $export_var_list {
	upvar 1 $var value
	if { [info exists value] } {
	    ns_set put $bind_vars $var $value
	}
    }
    set alpha_bar [im_alpha_bar -prev_page_url $prev_page_url -next_page_url $next_page_url $base_url $default_letter $bind_vars]

    # Get the Subnavbar
    set parent_menu_sql "select menu_id from im_menus where label = '$navbar_menu_label'"
    set parent_menu_id [util_memoize [list db_string parent_admin_menu $parent_menu_sql -default 0]]
    
    ns_set put $bind_vars letter $default_letter
    ns_set delkey $bind_vars project_status_id

    set navbar [im_sub_navbar $parent_menu_id $bind_vars $alpha_bar "tabnotsel" $select_label]

    return $navbar
}

