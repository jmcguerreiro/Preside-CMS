<!---@feature admin and assetManager--->
<cfscript>
	activeFolder = Trim( rc.folder  ?: "" );
	allowedTypes = prc.allowedTypes ?: [];
	savedFilters = prc.savedFilters ?: "";
	loadMoreUrl  = prc.loadMoreUrl ?: "";

	rootFolder   = prc.rootFolderId ?: 0;
	if ( not Len( activeFolder ) ) {
		activeFolder = rootFolder;
	}

	folders = renderView(
		  view          = "admin/assetManager/_folderBrowserListingForPicker"
		, presideObject = "asset_folder"
		, filter        = { parent_folder=activeFolder, hidden=false }
		, orderBy       = "label asc"
	);


	assetFilter = { asset_folder = activeFolder, is_trashed=0 };
	if ( allowedTypes.len() ){
		assetFilter.asset_type = allowedTypes;
	}
	assets = renderView(
		  view          = "admin/assetManager/_assetBrowserListingForPicker"
		, presideObject = "asset"
		, filter        = assetFilter
		, savedFilters  = listToArray( savedFilters )
		, orderBy       = "title asc"
		, maxRows       = 10
	);

	multiple = IsBoolean( rc.multiple ?: "" ) && rc.multiple;
</cfscript>

<cfoutput>
	#renderView( 'admin/layout/breadcrumbs' )#
	<table id="asset-listing-table" class="table table-striped table-bordered table-hover asset-listing-table" data-multiple="#multiple#">
		<thead>
			<tr>
				<th>&nbsp;</th>
				<th>#translateResource( "cms:assetManager.browser.name.column" )#</th>
			</tr>
		</thead>
		<tbody data-nav-list="1" data-nav-list-child-selector="> tr" id="loadmorecontainer">
			<cfif activeFolder neq rootFolder>
				#renderView( view="admin/assetManager/_folderBrowserListingUpOneLevelForPicker", presideObject="asset_folder", id=activeFolder )#
			</cfif>
			#folders#
			#assets#
		</tbody>
		<cfif Len( Trim( assets ) )>
			<tfoot class="load-more">
				<tr>
					<td colspan="2">
						<i class="fa fa-fw fa-plus light-grey"></i>
						<a class="load-more" data-href="#loadMoreUrl#" data-load-more-target="loadmorecontainer">#translateResource( "cms:assetmanager.browser.load.more" )#</a>
					</td>
				</tr>
			</tfoot>
		</cfif>
	</table>
</cfoutput>