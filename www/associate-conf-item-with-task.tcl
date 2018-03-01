# /packages/intranet-confdb/www/associate.tcl
#
# Copyright (C) 2010 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Allow the user to associate the current ticket with a new object
    using an OpenACS relationship.
    @author frank.bergmann@project-open.com
} {
    { object_id ""}
    { return_url "/intranet-confdb/index" }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set current_user_id [auth::require_login]
set page_title [lang::message::lookup "" intranet-confdb.Associate_with_Conf_Item "Associate with Conf Item"]
set context_bar [im_context_bar $page_title]
set page_focus "im_header_form.keywords"
set action_forbidden_msg [lang::message::lookup "" intranet-confdb.Action_Forbidden "<b>Unable to execute action</b>:<br>You don't have the permissions to associated this conf item with other objects."]


set conf_item_options [im_conf_item_options]

