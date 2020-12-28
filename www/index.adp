<master>
<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">conf_items</property>
<property name="left_navbar">@left_navbar_html;literal@</property>
<property name="sub_navbar">@conf_item_navbar_html;literal@</property>

<table cellspacing="0" cellpadding="0" border="0" width="100%">
<form action=/intranet-confdb/action method=POST>
<%= [export_vars -form {return_url}] %>
<tr valign="top">
<td>

	<table class="table_list_page">
	<%= $table_header_html %>
	<%= $table_body_html %>
	<%= $table_continuation_html %>
	<%= $table_submit_html %>
	</table>

</td>
<td width="<%= $dashboard_column_width %>">
<%= $dashboard_column_html %>
</td>
</tr>
</form>
</table>

