<?xml version="1.0"?>
<!DOCTYPE queryset PUBLIC "-//OpenACS//DTD XQL 1.0//EN" "/usr/share/emacs/DTDs/xql.dtd">
<!-- packages/intranet-notes/www/notes-del-postgresql.xql -->
<!-- @author  (avila@digiteix.com) -->
<!-- @creation-date 2006-04-27 -->
<!-- @arch-tag 7410be05-735d-4f4d-b0e5-6252f93a9d29 -->
<!-- @cvs-id $Id$ -->

<queryset>
  <rdbms>
    <type>postgresql</type>
    <version>7.2</version>
  </rdbms>
  
  <fullquery name="del_conf_item">
    <querytext>
        select im_conf_item__delete(:id);
    </querytext>
  </fullquery>
</queryset>
