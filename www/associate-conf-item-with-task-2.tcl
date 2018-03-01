# /packages/intranet-confdb/www/associate-2.tcl
#
# Copyright (C) 2010 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Associate the conf_item_ids in "cid" with one of the specified objects.
    target_object_type specifies the type of object to associate with and
    determines which parameters are used.
    @author frank.bergmann@project-open.com
} {
    { conf_item_id:integer }
    { object_id:integer }
    { return_url "/intranet-confdb/index" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set action_forbidden_msg [lang::message::lookup "" intranet-confdb.Action_Forbidden "<b>Unable to execute action</b>:<br>You don't have the permissions to associated this conf item with other objects."]


# ---------------------------------------------------------------
# 
# ---------------------------------------------------------------

set object_view 0
set object_read 0
set object_write 0
set object_admin 0
set object_type [db_string acs_object_type "select object_type from acs_objects where object_id = :object_id" -default ""]
if {"" != $object_type} {
    set perm_cmd "${object_type}_permissions \$current_user_id \$object_id object_view object_read object_write object_admin"
    eval $perm_cmd
}

if {!$object_write} {
    ad_return_complaint $action_forbidden_msg
    ad_script_abort
}


# ---------------------------------------------------------------
#
# ---------------------------------------------------------------

im_conf_item_new_project_rel \
    -project_id $object_id \
    -conf_item_id $conf_item_id


ad_returnredirect $return_url
