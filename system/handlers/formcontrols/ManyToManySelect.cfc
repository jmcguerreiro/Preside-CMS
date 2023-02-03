component {

	property name="presideObjectService" inject="presideObjectService";

	public string function index( event, rc, prc, args={} ) {
		var sourceObject  = args.sourceObject ?: "";
		var sourceIdField = presideObjectService.getIdField( sourceObject );

		args.object   = args.relatedTo ?: "";
		args.multiple = true;

		var targetIdField = presideObjectService.getIdField( args.object );
		var sourceId      = args.savedData[ sourceIdField ] ?: ( prc.record[ sourceIdField ] ?: "" );

		if ( !isEmptyString( sourceId ) ) {
			var useVersioning = Val( rc.version ?: "" ) && presideObjectService.objectIsVersioned( sourceObject );

			args.savedValue = presideObjectService.selectManyToManyData(
				  objectName       = sourceObject
				, propertyName     = args.name
				, id               = sourceId
				, selectFields     = [ "#args.name#.#targetIdField# as id" ]
				, useCache         = false
				, fromVersionTable = useVersioning
				, specificVersion  = Val( rc.version ?: "" )
			);

			args.defaultValue = args.savedValue = ValueList( args.savedValue.id );
		}

		return renderFormControl( argumentCollection=args, type="objectPicker", layout="" );
	}

}