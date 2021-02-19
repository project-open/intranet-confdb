# /packages/intranet-confdb/www/action.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    Perform bulk actions on conf_items
    
    @action_id	One of "Intranet Conf_Item Action" categories.
    		Determines what to do with the list of "tid"
		conf_item ids.
		The "aux_string1" field of the category determines
		the page to be called for pluggable actions.

    @param return_url the url to return to
    @author frank.bergmann@project-open.com
} {
    { conf_item:multiple ""}
    action_id:integer
    return_url
}

set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set user_name [im_name_from_user_id [ad_conn user_id]]


#-- 12600-12699  Intranet Conf Item Action (100)
#delete from im_categories where category_type = 'Intranet Conf Item Action';
#SELECT im_category_new(12600, 'Status: Active', 'Intranet Conf Item Action');
#SELECT im_category_new(12602, 'Status: Preactive', 'Intranet Conf Item Action');
#SELECT im_category_new(12616, 'Status: Archieved', 'Intranet Conf Item Action');
#SELECT im_category_new(12618, 'Status: Zombie', 'Intranet Conf Item Action');
#SELECT im_category_new(12620, 'Associate', 'Intranet Conf Item Action');
#SELECT im_category_new(12699, 'Nuke', 'Intranet Conf Item Action');
#-- reserved to 12699


# Deal with funky input parameter combinations
if {"" == $action_id} { ad_returnredirect $return_url }
if {0 == [llength $conf_item]} { ad_returnredirect $return_url }
if {1 == [llength $conf_item]} { set conf_item [lindex $conf_item 0] }

set action_name [im_category_from_id $action_id]
set action_forbidden_msg [lang::message::lookup "" intranet-confdb.Action_Forbidden "<b>Unable to execute action</b>:<br>You don't have the permissions to execute the action '%action_name%' on this conf_item."]

# ------------------------------------------
# Check the TCL that determines the visibility of the action
set visible_tcl [util_memoize [list db_string visible_tcl "select visible_tcl from im_categories where category_id = $action_id"]]
set visible_p 0
set visible_explicite_permission_p 0
if {"" == $visible_tcl} {
    # Not specified - User is allowed to execute but normal permissions apply
    set visible_p 1
} else {
    # Explicitely specified: Check TCL
    if {[eval $visible_tcl]} {
	set visible_p 1
	set visible_explicite_permission_p 1
    }
}

# ------------------------------------------
# Perform the action on multiple conf_items
#
switch $action_id {
    12699 {
	# Nuke
	if {!$user_is_admin_p} { 
	    ad_return_complaint 1 "User needs to be SysAdmin in order to 'Nuke' conf_items." 
	    ad_script_abort
	}
	set error_list [list]
	foreach cid $conf_item {
	    im_conf_item::check_permissions	-conf_item_id $cid -operation "admin"
	    im_conf_item::audit			-conf_item_id $cid -action "before_nuke"

	    if {[catch {
		im_conf_item::nuke			-conf_item_id $cid
	    } err_msg]} {
		lappend error_list $err_msg
	    }
	}

	if {[llength $error_list] > 0} {
	    ad_return_complaint 1 "<b>Errors while nuking conf items</b>:<br><pre>[join $error_list "<br>"]</pre>"
	    ad_script_abort
	}
	
	# Conf_Item may not exist anymore, return to conf_item list
	if {[regexp {^\/intranet-confdb\/new} $return_url match]} {
	    set return_url "/intranet-confdb/"
	}
    }
    12600 - 12602 - 12616 - 12618 {
	switch $action_id {
	    12600 { set status_id 11700 }
	    12602 { set status_id 11702 }
	    12616 { set status_id 11716 }
	    12618 { set status_id 11718 }
	    default { set status_id "" }
	}
	if {"" eq $status_id} { ad_returnredirect $return_url }

	# Set a specific status
	foreach cid $conf_item {
	    im_conf_item::audit			-conf_item_id $cid -action "before_update"
	    if {!$visible_explicite_permission_p} {
		im_conf_item::check_permissions	-conf_item_id $cid -operation "write"
	    }
	    im_conf_item::set_status_id		-conf_item_id $cid -conf_item_status_id $status_id
	    im_conf_item::audit			-conf_item_id $cid -action "after_update"
	}
	
	if {$action_id == 30510} {
	    # Close & Notify - Notify all stakeholders
	    ad_returnredirect [export_vars -base "/intranet-confdb/notify-stakeholders" {conf_item action_id return_url}]
	}
    }
    12620 {
	# Associate
	ad_return_complaint 1 "Not implemented yet"
	ad_returnredirect [export_vars -base "/intranet-confdb/action-associate" {conf_item action_id return_url}]
    }
    default {
	# Check if we've got a custom action to perform
	set redirect_base_url [db_string redir "select aux_string1 from im_categories where category_id = :action_id" -default ""]
	if {"" != [string trim $redirect_base_url]} {
	    # Redirect for custom action
	    set redirect_url [export_vars -base $redirect_base_url {action_id return_url}]
	    foreach cid $conf_item { append redirect_url "&conf_item=$cid"}
	    ad_returnredirect $redirect_url
	} else {
	    ad_return_complaint 1 "Unknown Conf_Item action: $action_id='[im_category_from_id $action_id]'"
	}
    }
}


ad_returnredirect $return_url
