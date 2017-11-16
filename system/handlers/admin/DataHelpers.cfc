/**
 * Handler that provides admin related helper viewlets,
 * and actions for preside object data
 *
 */
component extends="preside.system.base.adminHandler" {

	property name="adminDataViewsService" inject="adminDataViewsService";
	property name="dataManagerService"    inject="dataManagerService";
	property name="presideObjectService"  inject="presideObjectService";

	/**
	 * Method that is called from `adminDataViewsService.buildViewObjectRecordLink()`
	 * for objects that are managed in the DataManager. Hint: this can also be invoked with:
	 * `event.buildAdminLink( objectName=myObject, recordId=myRecordId )`
	 *
	 */
	private string function getViewRecordLink( required string objectName, required string recordId ) {
		if ( dataManagerService.isOperationAllowed( arguments.objectName, "read" ) ) {
			return event.buildAdminLink(
				  linkto      = "datamanager.viewRecord"
				, queryString = "object=#arguments.objectName#&id=#arguments.recordId#"
			);
		}
		return "";
	}


	/**
	 * Method for rendering a record for an admin view
	 *
	 */
	private string function viewRecord( event, rc, prc, args={} ) {
		var objectName = args.objectName ?: "";

		args.viewGroups = adminDataViewsService.listViewGroupsForObject( objectName );

		return renderView( view="/admin/dataHelpers/viewRecord", args=args );
	}

	/**
	 * Helper viewlet for rendering a admin data view 'display group'
	 * for a given object/record
	 */
	private string function displayGroup( event, rc, prc, args={} ) {
		var objectName    = args.objectName ?: "";
		var recordId      = args.recordId   ?: "";
		var props         = args.properties ?: [];
		var version       = Val( args.version ?: "" );
		var uriRoot       = presideObjectService.getResourceBundleUriRoot( objectName=objectName );
		var useVersioning = presideObjectService.objectIsVersioned( objectName );

		if ( useVersioning && Val( version ) ) {
			prc.record = prc.record ?: presideObjectService.selectData( objectName=object, filter={ id=recordId }, useCache=false, fromVersionTable=true, specificVersion=version, allowDraftVersions=true );
		} else {
			prc.record = prc.record ?: presideObjectService.selectData( objectName=object, filter={ id=recordId }, useCache=false, allowDraftVersions=true );
		}

		args.renderedProps = [];
		for( var propertyName in props ) {
			var renderedValue = adminDataViewsService.renderField(
				  objectName   = objectName
				, propertyName = propertyName
				, recordId     = recordId
				, value        = prc.record[ propertyName ] ?: ""
			);
			args.renderedProps.append( {
				  objectName    = objectName
				, propertyName  = propertyName
				, propertyTitle = translateResource( uri="#uriRoot#field.#propertyName#.title", defaultValue=translateResource( uri="cms:preside-objects.default.field.#propertyName#.title", defaultValue=propertyName ) )
				, recordId      = recordId
				, value         = prc.record[ propertyName ] ?: ""
				, rendered      = renderedValue
			} );
		}

		return renderView( view="/admin/dataHelpers/displayGroup", args=args );
	}

	/**
	 * Public action that is expected to be POSTed to with a 'content' variable
	 * that will be rendered within the preview layout
	 */
	public string function richeditorPreview( event, rc, prc ) {
		event.include( "/css/admin/specific/richeditorPreview/" );

		return renderLayout(
			  layout = "richeditorPreview"
			, args   = { content = renderContent( "richeditor", rc.content ?: "" ) }
		);
	}

	/**
	 * Viewlet for rendering a datatable of related records, i.e.
	 * a many-to-many or one-to-many relationship.
	 *
	 */
	private string function relatedRecordsDatatable( event, rc, prc, args={} ) {
		var objectName    = args.objectName   ?: "";
		var propertyName  = args.propertyName ?: "";
		var recordId      = args.recordId     ?: "";
		var queryString   = "objectName=#args.objectName#&propertyName=#args.propertyName#&recordId=#args.recordId#";
		var datasourceUrl = event.buildAdminLink( linkto="dataHelpers.getRecordsForRelatedRecordsDatatable", queryString=queryString );
		var relatedObject = presideObjectService.getObjectPropertyAttribute( objectName=objectName, propertyName=propertyName, attributeName="relatedTo" );
		var gridFields    = adminDataViewsService.listGridFieldsForRelationshipPropertyTable( objectName, propertyName );

		return renderView( view="/admin/datamanager/_objectDataTable", args={
			  objectName      = relatedObject
			, gridFields      = gridFields
			, dataSourceUrl   = dataSourceUrl
			, id              = "related-object-datatable-#objectName#-#propertyName#-" & CreateUUId()
			, compact         = true
			, useMultiActions = false
			, isMultilingual  = false
			, draftsEnabled   = false
			, allowSearch     = true
			, allowFilter     = false
			, allowDataExport = false
		} );
	}

	/**
	 * Ajax event for returning records to populate the relatedRecordsDatatable
	 *
	 */
	public void function getRecordsForRelatedRecordsDatatable( event, rc, prc ) {
		var objectName     = rc.objectName   ?: "";
		var propertyName   = rc.propertyName ?: "";
		var recordId       = rc.recordId     ?: "";
		var gridFields     = adminDataViewsService.listGridFieldsForRelationshipPropertyTable( objectName, propertyName ).toList();
		var relatedObject  = presideObjectService.getObjectPropertyAttribute( objectName=objectName, propertyName=propertyName, attributeName="relatedTo" );
		var relatedIdField = presideObjectService.getIdField( objectName=relatedObject );
		var extraFilters   = [];
		var subquerySelect = presideObjectService.selectData(
			  objectName          = objectName
			, id                  = recordId
			, selectFields        = [ "#propertyName#.#relatedIdField# as id" ]
			, getSqlAndParamsOnly = true
		);
		var subQueryAlias = "relatedRecordsFilter";
		var params        = {};

		for( var param in subquerySelect.params ) { params[ param.name ] = param; }

		extraFilters.append( {
			filter="1=1", filterParams=params, extraJoins=[ {
				  type           = "inner"
				, subQuery       = subquerySelect.sql
				, subQueryAlias  = subQueryAlias
				, subQueryColumn = "id"
				, joinToTable    = relatedObject
				, joinToColumn   = relatedIdField
			} ]
		} );

		prc.viewRecordLink = adminDataViewsService.buildViewObjectRecordLink( objectName=relatedObject, recordId="{id}" );

		runEvent(
			  event          = "admin.DataManager._getObjectRecordsForAjaxDataTables"
			, prePostExempt  = true
			, private        = true
			, eventArguments = {
				  object          = relatedObject
				, gridFields      = gridFields
				, extraFilters    = extraFilters
				, useMultiActions = false
				, isMultilingual  = false
				, draftsEnabled   = false
				, useCache        = false
				, actionsView     = "admin.dataHelpers.relatedRecordTableActions"
			}
		);
	}

	private string function relatedRecordTableActions( event, rc, prc, args={} ) {
		if ( Len( Trim( prc.viewRecordLink ?: "" ) ) ) {
			args.viewRecordLink = prc.viewRecordLink.replace( "{id}", ( args.id ?: "" ) );

			return renderView( view="/admin/dataHelpers/relatedRecordTableActions", args=args );
		}
		return "";
	}
}