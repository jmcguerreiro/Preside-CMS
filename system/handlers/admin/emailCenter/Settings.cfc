/**
 * @feature admin and emailCenter
 */
component extends="preside.system.base.AdminHandler" {

	property name="emailServiceProviderService" inject="emailServiceProviderService";
	property name="siteService"                 inject="featureInjector:sites:siteService";
	property name="systemConfigurationService"  inject="systemConfigurationService";
	property name="emailCenterValidators"       inject="emailCenterValidators";
	property name="messagebox"                  inject="messagebox@cbmessagebox";
	property name="systemAlertsService"         inject="systemAlertsService";

	public void function preHandler( event, action, eventArguments ) {
		super.preHandler( argumentCollection=arguments );

		if ( !isFeatureEnabled( "emailcenter" ) ) {
			event.notFound();
		}

		if ( !hasCmsPermission( "emailcenter.settings.manage" ) ) {
			event.adminAccessDenied();
		}

		event.addAdminBreadCrumb(
			  title = translateResource( "cms:emailcenter.settings.breadcrumb.title" )
			, link  = event.buildAdminLink( linkTo="emailcenter.settings" )
		);

		event.setValue( "pageIcon", "envelope", true );
	}

	public void function index( event, rc, prc ) {
		var categoryId   = "email";
		var isSiteConfig = false;

		if ( isFeatureEnabled( "sites" ) ) {
			var siteId = Trim( rc.site ?: "" );
			prc.sites = siteService.listSites();
			isSiteConfig = prc.sites.recordCount > 1 && Len( siteId.len() );
		}

		if ( isSiteConfig ) {
			prc.savedData = systemConfigurationService.getCategorySettings(
				  category        = categoryId
				, includeDefaults = false
				, siteId          = siteId
			);
		} else {
			prc.savedData = systemConfigurationService.getCategorySettings(
				  category           = categoryId
				, globalDefaultsOnly = true
			);
		}

		prc.pageTitle    = translateResource( "cms:emailcenter.settings.page.title"    );
		prc.pageSubTitle = translateResource( "cms:emailcenter.settings.page.subTitle" );

		event.include( "/js/admin/specific/emailcenter/settings/" );
	}

	public void function saveGeneralSettingsAction( event, rc, prc ) {
		var categoryId = "email";
		var siteId     = isFeatureEnabled( "sites" ) ? ( rc.site ?: "" ) : "";

		var formName = "email.settings.general";
		var formData = event.getCollectionForForm( formName );

		if ( Len( Trim( siteId ) ) ) {
			for( var setting in formData ){
				if ( IsFalse( rc[ "_override_" & setting ] ?: "" ) ) {
					formData.delete( setting );
					systemConfigurationService.deleteSetting(
						  category = categoryId
						, setting  = setting
						, siteId   = siteId
					);
				}
			}
		}

		var validationResult = validateForm(
			  formName      = formName
			, formData      = formData
			, ignoreMissing = Len( Trim( siteId ) )
		);

		if ( Len( Trim( formData.allowed_sending_domains ?: "" ) ) ) {
			var allowedDomainErrors     = [];
			var badAddresses            = emailCenterValidators.existingEmailsUsingInvalidDomains( formData.allowed_sending_domains );
			var badFormbuilderAddresses = emailCenterValidators.formbuilderActionsUsingInvalidDomains( formData.allowed_sending_domains );
			if ( ArrayLen( badAddresses ) ) {
				ArrayAppend( allowedDomainErrors, translateResource( uri="cms:validation.allowedSenderEmail.existing.emails", data=[ ArrayToList( badAddresses, ", " ) ] ) );
			}
			if ( ArrayLen( badFormbuilderAddresses ) ) {
				ArrayAppend( allowedDomainErrors, translateResource( uri="cms:validation.allowedSenderEmail.existing.formbuilder", data=[ ArrayToList( badFormbuilderAddresses, ", " ) ] ) );
			}
			if ( ArrayLen( allowedDomainErrors ) ) {
				validationResult.addError( "allowed_sending_domains", ArrayToList( allowedDomainErrors, "<br>" ) );
			}
		}

		if ( !validationResult.validated() ) {
			messageBox.error( translateResource( uri="cms:sysconfig.validation.failed" ) );
			var persist = formData;
			persist.validationResult = validationResult;

			setNextEvent(
				  url           = event.buildAdminLink(linkTo="emailcenter.settings" )
				, persistStruct = persist
			);
		}

		for( var setting in formData ){
			systemConfigurationService.saveSetting(
				  category = categoryId
				, setting  = setting
				, value    = formData[ setting ]
				, siteId   = siteId
			);
		}

		systemAlertsService.runCheck( type="emailCentreSettings" );

		event.audit(
			  action   = "save_sysconfig_category"
			, type     = "sysconfig"
			, recordId = categoryId
			, detail   = formData
		);

		messageBox.info( translateResource( uri="cms:emailcenter.settings.saved.message" ) );
		setNextEvent( url=event.buildAdminLink( linkTo="emailcenter.settings" ) );
	}

	public void function provider( event, rc, prc ) {
		var providerId = rc.id ?: "";
		var isSiteConfig = false;

		prc.provider = emailServiceProviderService.getProvider( providerId );
		if ( prc.provider.isEmpty() ) {
			event.notFound();
		}

		prc.formName = emailServiceProviderService.getProviderConfigFormName( providerId );


		if ( isFeatureEnabled( "sites" ) ) {
			var siteId     = rc.site ?: "";
			prc.sites    = siteService.listSites();
			isSiteConfig = prc.sites.recordCount > 1 && siteId.len();
		}

		if ( isSiteConfig ) {
			prc.savedData = emailServiceProviderService.getProviderSettings(
				  provider        = providerId
				, includeDefaults = false
				, siteId          = siteId
			);
		} else {
			prc.savedData = emailServiceProviderService.getProviderSettings(
				  provider           = providerId
				, globalDefaultsOnly = true
			);
		}
		prc.savedData.check_connection = true;

		prc.pageTitle    = translateResource( uri="cms:emailcenter.provider.page.title", data=[ prc.provider.title ] );
		prc.pageSubTitle = translateResource( uri="cms:emailcenter.provider.page.subTitle", data=[ prc.provider.description ] );

		event.addAdminBreadCrumb(
			  title = translateResource( uri="cms:emailcenter.provider.breadcrumb.title", data=[ prc.provider.title ]  )
			, link  = event.buildAdminLink( linkTo="emailcenter.settings.provider", queryString="id=" & providerId )
		);
	}

	public void function saveProviderSettingsAction( event, rc, prc ) {
		var providerId = rc.id ?: "";
		var siteId     = rc.site ?: "";
		var provider   = emailServiceProviderService.getProvider( providerId );

		if ( provider.isEmpty() ) {
			event.notFound();
		}
		var categoryId = emailServiceProviderService.getProviderSettingsCategory( providerId );
		var formName = emailServiceProviderService.getProviderConfigFormName( providerId );
		var formData = event.getCollectionForForm( formName );

		if ( Len( Trim( siteId ) ) ) {
			for( var setting in formData ){
				if ( IsFalse( rc[ "_override_" & setting ] ?: "" ) ) {
					formData.delete( setting );
					systemConfigurationService.deleteSetting(
						  category = categoryId
						, setting  = setting
						, siteId   = siteId
					);
				}
			}
		}

		var validationResult = validateForm(
			  formName      = formName
			, formData      = formData
			, ignoreMissing = Len( Trim( siteId ) )
		);

		var validationData = Duplicate( formData );
		if ( siteId.len() ) {
			validationData.append( emailServiceProviderService.getProviderSettings(
				  provider           = providerId
				, globalDefaultsOnly = true
			), false );
		}
		emailServiceProviderService.validateSettings(
			    provider         = providerId
			  , settings         = validationData
			  , validationResult = validationResult
		);


		if ( !validationResult.validated() ) {
			messageBox.error( translateResource( uri="cms:sysconfig.validation.failed" ) );
			var persist = formData;
			persist.validationResult = validationResult;

			setNextEvent(
				  url           = event.buildAdminLink(linkTo="emailcenter.settings.provider", queryString="id=#providerId#&site=#siteId#" )
				, persistStruct = persist
			);
		}

		emailServiceProviderService.saveSettings(
			  provider = providerId
			, settings = formData
			, site     = siteId
		);

		// TODO audit!

		messageBox.info( translateResource( uri="cms:emailcenter.settings.provider.saved.message", data=[ provider.title ] ) );
		setNextEvent( url=event.buildAdminLink( linkTo="emailcenter.settings" ) );
	}


// VIEWLETS, ETC
	private string function _generalSettingsTabs( event, rc, prc, args={} ) {
		if ( hasCmsPermission( "emailCenter.serviceProviders.manage" ) ) {
			args.providers = emailServiceProviderService.listProviders();
		}

		return renderView( view="/admin/emailCenter/settings/_generalSettingsTabs", args=args );
	}
}