<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">#intranet-core.context#</property>
<property name="main_navbar_label">confdb</property>

<h1>@page_title@</h1>

<p>
<%= [lang::message::lookup "" intranet-confdb.Associate_new_Conf_Items_Msg "This page allows you to associate a new configuration items."] %>
</p>
<br>

<form action="/intranet-confdb/associate-conf-item-with-task-2" method=GET>
<%= [export_vars -form {object_id return_url}] %>
<table>
	<tr>
	<th colspan="3"><%= [lang::message::lookup "" intranet-confdb.Associate_With "Associate With"] %></th>
	</tr>

	<tr>
	<td>	<%= [im_select -ad_form_option_list_style_p 1 conf_item_id $conf_item_options ""] %></td>
	</tr>

	<tr>
	<td><input type="submit" name="submit" value="<%= [lang::message::lookup "" intranet-confdb.Associate_Assoc_Action Associate] %>"></td>
	</tr>

</table>
</form>