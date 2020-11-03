<!-- packages/intranet-confdb/www/new.adp -->
<!-- @author Frank Bergmann (frank.bergmann@project-open.com) -->
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN">

<if @enable_master_p@>
<master src="../../intranet-core/www/master">
</if>

<property name="doc(title)">@page_title;literal@</property>
<property name="context">@context_bar;literal@</property>
<property name="main_navbar_label">conf_items</property>
<property name="focus">@focus;literal@</property>
<property name="sub_navbar">@sub_navbar;literal@</property>

<if @message@ not nil>
  <div class="general-message">@message@</div>
</if>

<script type="text/javascript" <if @::__csp_nonce@ not nil>nonce="@::__csp_nonce;literal@"</if>>
window.addEventListener('load', function() { 
     document.getElementById('list_check_all').addEventListener('click', function() { acs_ListCheckAll('conf_items_list', this.checked) });
});
</script>



<if @view_name@ eq "component">

   <%= [im_component_page -plugin_id $plugin_id -return_url [export_vars -base "/intranet-confdb/new" {conf_item_id}]] %>

</if>
<else>

	
	<if @show_components_p@>
	
		<%= [im_component_bay top] %>
		<table width="100%">
		  <tr valign="top">
		    <td width="50%">
			<%= [im_box_header [lang::message::lookup "" intranet-confdb.Conf_Item "Configuration Item"]] %>
			<formtemplate id="conf_item"></formtemplate>
			<%= [im_box_footer] %>
			<%= [im_component_bay left] %>
		    </td>
		    <td width="50%">

			<if @sub_item_count@ gt 0>
			<%= [im_box_header [lang::message::lookup "" intranet-confdb.Sub_Items "Sub-Items"]] %>
			<listtemplate name="sub_conf_items"></listtemplate>
			<%= [im_box_footer] %>
			</if>

			<%= [im_component_bay right] %>

		    </td>
		  </tr>
		</table>
		<%= [im_component_bay bottom] %>

	</if>
	<else>
	
		<%= [im_box_header $page_title] %>
		<formtemplate id="conf_item"></formtemplate>
		<%= [im_box_footer] %>
	
	</else>

</else>


<table width="100%">
  <tr valign="top">
  <td>
	@result;noquote@
  </td>
  </tr>
</table>
