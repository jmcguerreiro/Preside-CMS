<!---@feature admin--->
<cfscript>
	param name="args.objectName"              type="string"  default=(rc.object ?: '' );
	param name="args.formName"                type="string"  default=(prc.formName ?: '' );
	param name="args.editRecordAction"        type="string"  default=event.buildAdminLink( linkTo='datamanager.quickEditRecordAction', queryString="object=#args.objectName#" );
	param name="args.validationResult"        type="any"     default=( rc.validationResult ?: '' );
	param name="args.record"                  type="struct"  default=( prc.record ?: {} );
	param name="args.stripPermissionedFields" type="boolean" default=true;
	param name="args.permissionContext"       type="string"  default=args.objectName;
	param name="args.permissionContextKeys"   type="array"   default=ArrayNew( 1 );
	param name="args.preForm"                 type="string"  default=( prc.preForm ?: '' );
	param name="args.postForm"                type="string"  default=( prc.postForm ?: '' );

	editRecordPrompt    = translateResource( uri="preside-objects.#args.objectName#:editRecord.prompt", defaultValue="" );
	objectTitleSingular = translateResource( uri="preside-objects.#args.objectName#:title.singular"   , defaultValue=args.objectName );
	formId              = "editForm-" & CreateUUId();

	event.include( "/js/admin/specific/datamanager/quickEditForm/" );
</cfscript>

<cfoutput>
	<form id="#formId#" data-auto-focus-form="true" data-dirty-form="protect" class="form-horizontal quick-edit-form" method="post" action="#args.editRecordAction#">
		<input name="id" type="hidden" value="#( rc.id ?: '' )#" />

		#args.preForm#
		
		#renderForm(
			  formName                = args.formName
			, context                 = "admin"
			, formId                  = formId
			, validationResult        = args.validationResult
			, savedData               = args.record
			, stripPermissionedFields = args.stripPermissionedFields
			, permissionContext       = args.permissionContext
			, permissionContextKeys   = args.permissionContextKeys
		)#
		
		#args.postForm#
		
	</form>
</cfoutput>