@RestResource(urlMapping='/v2/Users/*')
global with sharing class UserResource extends ScimResource {
    final public static Map<String, ScimSoqlAttributeProcessor> scimNameToUserSObjectNameMap;
    final private static Map<String, Schema.SOAPType> customFieldToSoapTypeMap;
    
    final private static String enterpriseExtensionURN = 'urn:ietf:params:scim:schemas:extension:enterprise:2.0:User';
    final private static String orgId = UserInfo.getOrganizationId();
    
    final private static Set<String> portalUserTypes = new Set<String>();
    
    final public static Set<String> unsupportedAttrs = new Set<String>{'middlename', 'honorificPrefix', 'honorificSuffix', 'costCenter'};
    final public static Set<String> readOnlyAttrs = new Set<String>{'displayName', 'profileURL', 'photos', 'userType', 'id', 'formatted', 'organization'};

    
    static {
        portalUserTypes.add('cspliteportal');
        portalUserTypes.add('powercustomersuccess');
        portalUserTypes.add('customersuccess');
        portalUserTypes.add('powerpartner');
        portalUserTypes.add('partner');
    
        scimNameToUserSObjectNameMap = new Map<String, ScimSoqlAttributeProcessor>();
        scimNameToUserSObjectNameMap.put('id', new StandardAttributeProcessor('Id', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('userName', new StandardAttributeProcessor('Username', Schema.SOAPType.String, false));
        
        // Org may not have federation identifier. Only add it if it shows up in describe
        if (isFieldAccessible('FederationIdentifier')) {        
            scimNameToUserSObjectNameMap.put('externalId', new StandardAttributeProcessor('FederationIdentifier', Schema.SOAPType.String, false));
        }
        
        scimNameToUserSObjectNameMap.put('name', new StandardAttributeProcessor('Name,Lastname,Firstname', Schema.SOAPType.String, true));
        scimNameToUserSObjectNameMap.put('name.formatted', new StandardAttributeProcessor('Name', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('name.familyName', new StandardAttributeProcessor('Lastname', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('name.givenName', new StandardAttributeProcessor('Firstname', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('displayName', new StandardAttributeProcessor('Name', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('nickName', new StandardAttributeProcessor('CommunityNickname', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('emails', new StandardAttributeProcessor('Email', Schema.SOAPType.String, false));     
        scimNameToUserSObjectNameMap.put('addresses', new StandardAttributeProcessor('Street,City,State,PostalCode,Country', Schema.SOAPType.String, true));
        scimNameToUserSObjectNameMap.put('addresses.streetAddress', new StandardAttributeProcessor('Street', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('addresses.locality', new StandardAttributeProcessor('City', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('addresses.region', new StandardAttributeProcessor('State', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('addresses.postalCode', new StandardAttributeProcessor('PostalCode', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('addresses.country', new StandardAttributeProcessor('Country', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('phoneNumbers', new PhoneNumbersAttributeProcessor());
        
        scimNameToUserSObjectNameMap.put('userType', new StandardAttributeProcessor('UserType', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('title', new StandardAttributeProcessor('Title', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('preferredLanguage', new StandardAttributeProcessor('LanguageLocaleKey', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('locale', new StandardAttributeProcessor('LocaleSidKey', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('timezone',new StandardAttributeProcessor('TimeZoneSidKey', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('active', new StandardAttributeProcessor('IsActive', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('entitlements', new EntitlementsAttributeProcessor());
        scimNameToUserSObjectNameMap.put('groups', new GroupsAttributeProcessor());
        scimNameToUserSObjectNameMap.put('roles', new RolesAttributeProcessor());
        
        // profileUrl - should this be URL to user object
        
        // enterprise extensions
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN, new StandardAttributeProcessor('employeeNumber,Division,Department,ManagerId,Manager.Name', null, true));
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.employeeNumber', new StandardAttributeProcessor('employeeNumber', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.division', new StandardAttributeProcessor('Division', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.department', new StandardAttributeProcessor('Department', Schema.SOAPType.String, false));
        
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.delegatedApprover', new StandardAttributeProcessor('DelegatedApproverId', Schema.SOAPType.String, true));
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.delegatedApprover.delegatedApproverId', new StandardAttributeProcessor('DelegatedApproverId', Schema.SOAPType.String, false));
        
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.manager', new StandardAttributeProcessor('ManagerId,Manager.Name', Schema.SOAPType.String, true));
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.manager.managerId', new StandardAttributeProcessor('ManagerId', Schema.SOAPType.String, false));
        scimNameToUserSObjectNameMap.put(enterpriseExtensionURN + '.manager.displayName', new StandardAttributeProcessor('Manager.Name', Schema.SOAPType.String, false));
        
        // Org may not have Chatter
        if (isFieldAccessible('FullPhotoUrl') && isFieldAccessible('SmallPhotoUrl')) {        
            scimNameToUserSObjectNameMap.put('photos', new PhotosAttributeProcessor());
        }
        scimNameToUserSObjectNameMap.put('meta', new StandardAttributeProcessor('CreatedDate,LastModifiedDate', Schema.SOAPType.String, true));
        scimNameToUserSObjectNameMap.put('meta.created', new StandardAttributeProcessor('CreatedDate', Schema.SOAPType.DateTime, false));
        scimNameToUserSObjectNameMap.put('meta.lastModified', new StandardAttributeProcessor('LastModifiedDate', Schema.SOAPType.DateTime, false));
        
        customFieldToSoapTypeMap = new Map<String, Schema.SOAPType>();
        // Also the custom fields.
        Map<String, Schema.SObjectField> r = Schema.sObjectType.User.fields.getMap();
        String customFields = '';
        for (String key : r.keySet()) {
            SObjectField thisField = r.get(key);
            DescribeFieldResult thisDescribeResult = thisField.getDescribe();
            if (thisDescribeResult.isCustom()) {
                String customField = thisDescribeResult.getName();
                customFields = customFields + customField + ',';
                customFieldToSoapTypeMap.put(thisDescribeResult.getName(), thisDescribeResult.getSOAPType());
                scimNameToUserSObjectNameMap.put('urn:salesforce:schemas:extension:' + orgId + '.' + customField, new StandardAttributeProcessor(customField, thisDescribeResult.getSOAPType(), false));
            }
        }
    
        if (customFields.length() > 0) {
            customFields = customFields.substring(0, (customFields.length() - 1));        
            scimNameToUserSObjectNameMap.put('urn:salesforce:schemas:extension:' + orgId, new StandardAttributeProcessor(customFields, null, true));
        }
        
        // External User Extensions
        // TODO - parameterize type string
        scimNameToUserSObjectNameMap.put('urn:salesforce:schemas:extension:external:1.0', new StandardAttributeProcessor('', SOAPType.String, true));
        scimNameToUserSObjectNameMap.put('urn:salesforce:schemas:extension:external:1.0.accountId', new StandardAttributeProcessor('AccountId', SOAPType.String, false));
        scimNameToUserSObjectNameMap.put('urn:salesforce:schemas:extension:external:1.0.contactId', new StandardAttributeProcessor('ContactId', SOAPType.String, false));
    }
    
    private static boolean isFieldAccessible(String fieldName) {
        Schema.SObjectField field = Schema.sObjectType.User.fields.getMap().get(fieldName);
        if (field != null) {        
            Schema.DescribeFieldResult f = field.getDescribe();
            return (f != null && f.isAccessible());
        }
        return false;
    }
    
    public List<String> attributes {get;set;}
    public List<String> schemas {get;set;}
    public String id {get;set;}
    public String externalId {get;set;}
    public String userName {get;set;}
    public Map<String,String> name {get;set;}
    public String displayName {get;set;}
    public String nickName {get;set;}
    public String profileUrl {get;set;}
    public List<Map<String,String>> emails {get;set;}
    public List<Map<String,String>> addresses {get;set;}
    public List<Map<String,String>> phoneNumbers {get;set;}
    public List<Map<String,String>> photos {get;set;}
    public String userType {get;set;}
    public String title {get;set;}
    public String preferredLanguage {get;set;}
    public String locale {get;set;}
    public String timezone {get;set;}
    public Boolean active {get;set;}
    public List<Map<String,String>> groups {get;set;}
    public List<Map<String,String>> entitlements {get;set;}
    public List<Map<String,String>> roles {get;set;}
    public Map<String,String> meta {get;set;}
    public String employeeNumber {get;set;}
    public String costCenter {get;set;}
    public String organization {get;set;}
    public String division {get;set;}
    public String department {get;set;}
    public Map<String,String> manager {get;set;}
    public Map<String,String> delegatedApprover {get;set;}
    public String password {get;set;}
    public Map<String,Object> customFieldValues {get;set;}
    public Map<String,Object> externalUserProperties {get;set;}

    public List<Map<String, String>> operations {get;set;}
    

    
    /**
     * Instantiate a UserResource with user provided blob content
     */
    public UserResource(Blob body) {
        System.JSONParser parser = System.JSON.createParser(body.toString());
        while (parser.nextToken() != null) {
            if (isNextTokenField(parser,'schemas')) this.schemas = parseStringArray('schemas', parser);                            
            if (isNextTokenField(parser,'id')) this.id = parseString('id',parser);
            if (isNextTokenField(parser,'externalId')) this.externalId = parseString('externalId', parser);
            if (isNextTokenField(parser,'userName')) this.userName = parseString('userName', parser);
            if (isNextTokenField(parser,'name')) this.name = parseSimpleObject('name', parser);
            if (isNextTokenField(parser,'displayName')) this.displayName = parseString('displayName', parser);
            if (isNextTokenField(parser,'nickName')) this.nickName = parseString('nickName', parser);
            if (isNextTokenField(parser,'profileUrl')) this.profileUrl = parseString('profileUrl', parser);
            if (isNextTokenField(parser,'emails')) this.emails =  parseOptionalObjectArray('emails', parser);
            if (isNextTokenField(parser,'addresses')) this.addresses = parseObjectArray('addresses', parser);
            if (isNextTokenField(parser,'phoneNumbers')) this.phoneNumbers =  parseObjectArray('phoneNumbers', parser);
            if (isNextTokenField(parser,'photos')) this.photos =  parseObjectArray('photos', parser);
            if (isNextTokenField(parser,'userType')) this.userType = parseString('userType', parser);
            if (isNextTokenField(parser,'title')) this.title = parseString('title', parser);
            if (isNextTokenField(parser,'preferredLanguage')) this.preferredLanguage = parseString('preferredLanguage', parser);
            if (isNextTokenField(parser,'locale')) this.locale = parseString('locale', parser);
            if (isNextTokenField(parser,'timezone')) this.timezone = parseString('timezone', parser);
            if (isNextTokenField(parser,'active')) this.active = parseBoolean('active', parser);
            if (isNextTokenField(parser,'employeeNumber')) this.employeeNumber = parseString('employeeNumber', parser);
            if (isNextTokenField(parser,'costCenter')) this.costCenter = parseString('costCenter', parser);
            if (isNextTokenField(parser,'organization')) this.organization = parseString('organization', parser);
            if (isNextTokenField(parser,'division')) this.division = parseString('division', parser);
            if (isNextTokenField(parser,'department')) this.department = parseString('department', parser);
            if (isNextTokenField(parser,'manager')) this.manager = parseSimpleObject('manager', parser);
            if (isNextTokenField(parser,'delegatedApprover')) this.delegatedApprover = parseSimpleObject('delegatedApprover', parser);
            if (isNextTokenField(parser,'entitlements')) this.entitlements =  parseObjectArray('entitlements', parser);
            if (isNextTokenField(parser,'groups')) this.groups =  parseObjectArray('groups', parser);
            if (isNextTokenField(parser,'roles')) this.roles =  parseObjectArray('roles', parser);
            if (isNextTokenField(parser,'password')) this.password = parseString('password', parser);
            if (isNextTokenField(parser,'urn:salesforce:schemas:extension:' + orgId)) this.customFieldValues = parseSimpleObject('urn:salesforce:schemas:extension:' + orgId, parser);
            if (isNextTokenField(parser,'urn:salesforce:schemas:extension:external:1.0')) this.externalUserProperties = parseSimpleObject('urn:salesforce:schemas:extension:external:1.0', parser);
            
            if (isNextTokenField(parser, 'meta')) {    
                while ((parser.nextToken() != null) && (parser.getCurrentToken() != JSONToken.END_OBJECT)) {
                    if (parser.getCurrentToken() == JSONToken.FIELD_NAME) {
                        String name = parser.getText();
                        if ('attributes'.equals(name)) {
                            attributes = ScimResource.parseStringArray('attributes', parser);
                        }
                    }                      
                }                     
            }             
        }     
    }
    
    public static void doCreateOrUpdate(RestRequest req, RestResponse res, User u, String operation) {
        Boolean isCreate = ( operation == 'POST' );
        Boolean isUpdate =  ( operation == 'PUT' );
        Boolean isPatch =  ( operation == 'PATCH' );
        res.addHeader('Content-Type', 'application/json');    
        res.statusCode = 201;
        String error = '';
        UserResource user;
        Savepoint sp = Database.setSavepoint();
        try {
             user = new UserResource(req.requestBody);
        } catch (ScimException scex) {
            res.statusCode = scex.getStatusCode();
            error = scex.getMessage();
        } catch (Exception e) {
            res.statusCode = 500;
            error = e.getMessage();
        }
        
        // In order to be able to create users with PermSets and Groups I moved this declaration up here
        // I bet there is a better way to handle the problem
        List<PermissionSetAssignment> newPsas = new List<PermissionSetAssignment>();        
        List<GroupMember> newGMs = new List<GroupMember>();

        if (res.statusCode == 201) {
            if ( isUpdate ) {
                if ((user.id != null) && ( user.id != u.id)) {
                    error += 'INVALID:id_attribute_is_readonly;';  
                    res.statusCode = 500;
                }
            }
    
            if (user.externalId != null) {
                if (scimNameToUserSObjectNameMap.containsKey('externalId')) {
                    u.put('FederationIdentifier', user.externalId);
                }
                else {
                    error += 'INVALID:externalId_not_available_in_your_organization;';  
                    res.statusCode = 500;
                }
            }
    
            if ( ( user.userName == null) && (  ( isCreate ) || ( isUpdate ) )  ){
                error += 'REQUIRED_FIELD_MISSING:userName;';  
                res.statusCode = 500;
            } else {
                if ( user.userName != null ) {
                    u.userName = user.userName;
                }
            }
            
            if ( user.name != null) {
                if (isUpdate) {
                    if (user.name.containsKey('formatted') && ( user.name.get('formatted') != u.name)) {
                        error += 'INVALID:name.formatted_is_read_only;';  
                        res.statusCode = 500;
                    }
                }
                
                if (user.name.containsKey('familyName')) {
                    u.lastName = user.name.get('familyName');
                } else {
                    if ( ( isCreate ) || ( isUpdate ) ) {
                        error += 'REQUIRED_FIELD_MISSING:name.familyName;';  
                        res.statusCode = 500;  
                    } 
                }
                if (user.name.containsKey('givenName')) {
                    u.firstName = user.name.get('givenName');
                }
                if (user.name.containsKey('middleName')) {
                    error += 'UNSUPPORTED_FIELD:name.middleName;';  
                    res.statusCode = 500;   
                }
                if (user.name.containsKey('honorificPrefix')) {
                    error += 'UNSUPPORTED_FIELD:name.honorificPrefix;';  
                    res.statusCode = 500;   
                }
                if (user.name.containsKey('honorificSuffix')) {
                    error += 'UNSUPPORTED_FIELD:name.honorificSuffix;';  
                    res.statusCode = 500;   
                }
            }

            if (isUpdate) {
                if (( user.displayName != null)  && ( user.displayName != u.name)) {
                    error += 'INVALID:displayName_is_read_only;';  
                    res.statusCode = 500;
                }
            }
                            
            if (user.name != null && user.name.containsKey('familyName')) {
                u.lastName = user.name.get('familyName');
            } else {
                if ( ( isCreate ) || ( isUpdate ) ) {
                    error += 'REQUIRED_FIELD_MISSING:name.familyName;';  
                    res.statusCode = 500;  
                } 
            }
                        
            if ( user.nickName != null) {
                u.communityNickname = user.nickName;
                u.alias = user.nickName;
            } else {
                if ( isCreate ) {
                    String timeString = Datetime.now().getTime().format().replace(',','');
                    u.alias = timeString.substring(timeString.length() - 8, timeString.length());
                    u.communityNickname = user.userName;   
                }
            }

            if (isUpdate) {
                if (( user.profileUrl != null)  && ( user.profileUrl != 'https://' + req.headers.get('Host') + '/' + user.Id)) {                
                    error += 'INVALID:profileUrl_is_read_only;';  
                    res.statusCode = 500;
                }
            }
            
            //email
            if ((user.emails == null) || (user.emails.isEmpty())) {
                if ( ( isCreate ) || ( isUpdate ) ) {
                    error += 'REQUIRED_FIELD_MISSING:email;';  
                    res.statusCode = 500;
                }
            } else if ( user.emails.size() != 1 ) {
                error += 'INVALID:only_a_single_email_is_allowed;';  
                res.statusCode = 500;
            } else {
                Map<String,String> email = user.emails.get(0);
                if ( email.containsKey('value') ) {
                    u.email = email.get('value');
                } else {
                    if ( ( isCreate ) || ( isUpdate ) ) {
                        error += 'REQUIRED_FIELD_MISSING:email;';  
                        res.statusCode = 500;            
                    }
                }
            }
            
            if ( user.addresses != null ) {
                if ( user.addresses.size() > 1 ) {
                    error += 'INVALID:only_a_single_address_is_allowed;';  
                    res.statusCode = 500;
                } else if (user.addresses.size() == 1 ) {
                    Map<String,String> address = user.addresses.get(0);
                    if (address.containsKey('streetAddress')) u.street = address.get('streetAddress');
                    if (address.containsKey('locality')) u.city = address.get('locality');
                    if (address.containsKey('region')) u.state = address.get('region');
                    if (address.containsKey('postalCode')) u.postalCode = address.get('postalCode');
                    if (address.containsKey('country')) u.country = address.get('country');
                    if (address.containsKey('formatted')) {
                        error += 'INVALID:addresses[].formatted_is_read_only;';  
                        res.statusCode = 500;
                    }
                }
            }
            
            if ( user.phoneNumbers != null ) {
                if ( !user.phoneNumbers.isEmpty()) {
                    for (Map<String,String>phone : user.phoneNumbers) {
                        String val = null;
                        if (phone.containsKey('value')) val = phone.get('value');
                        if ( val != null) {
                            if ((phone.containsKey('type')) && (phone.get('type') == 'work')) {
                                u.phone = val;
                            } else if ((phone.containsKey('type')) && (phone.get('type') == 'mobile')) {
                                u.mobilePhone = val;
                            } else if ((phone.containsKey('type')) && (phone.get('type') == 'fax')) {
                                u.fax = val;
                            }
                        }
                    }
                }
            }
            
            if (isCreate) {
                //TODO - diff the input
                if ( (user.photos != null ) && (!user.photos.isEmpty()) ) {
                    error += 'INVALID:photos[]_is_read_only;';  
                    res.statusCode = 500;
                }
            }

            if (isUpdate) {
                if ( (user.userType != null ) && (user.userType != u.userType)) {
                    error += 'INVALID:userType_is_read_only;';  
                    res.statusCode = 500;
                }
            }
    
            if ( user.title != null) {
                u.title = user.title;
            }
            
            if ( user.preferredLanguage != null) {
                u.languagelocalekey = user.preferredLanguage;
            } else {
                u.languagelocalekey = 'en_US';
            }
            
            if ( user.locale != null) {
                u.localesidkey = user.locale;
            } else {
                u.localesidkey = 'en_US';
            }
    
            if ( user.timezone != null) {
                u.timezonesidkey = user.timezone;
            } else {
                //TODO - improve default
                u.timezonesidkey = 'America/Los_Angeles';
            }        
            
            if ( (user.active != null) && (!user.active) ) u.isActive = false;
            if ( (user.active != null) && (user.active) ) u.isActive = true;
            
            if(isPatch && !u.isActive && user.password != null){
                error += 'BAD REQUEST:password_reset_failed_because_one_or_more_users_are_inactive;';  
                res.statusCode = 400;
            }
            
            if (user.roles != null) { 
                if ((user.roles.isEmpty()) || (user.roles.size() != 1) ) {
                    error += 'INVALID:user_must_have_only_one_role;';  
                    res.statusCode = 500;
                } else {
                    //TODO - improve this
                    u.put('userRoleId', user.roles.get(0).get('value'));
                }
            }        
			
			// Profiles and Permission Sets
            // PUT, PATCH, DELETE
            if ( user.entitlements != null && !user.entitlements.isEmpty() && !isCreate) {
                // if patch and meta attributes includes entitlements then we have to clear psas and profile
                boolean isMetaDelete = false;
                List<String> attributes = user.attributes;
                if (isPatch && attributes != null) {
                    for (String attribute : attributes) {
                        if ('entitlements'.equals(attribute)) {
                            isMetaDelete = true;
                        }
                    }
                }
                
                List<PermissionSetAssignment> existingPsas = [Select Id, PermissionSetId from PermissionSetAssignment where AssigneeId = :u.Id AND PermissionSet.IsOwnedByProfile = False];
                if (isMetaDelete || isUpdate) {
                    Database.delete(existingPsas, true);
                    u.put('profileid', null);
                }
                
                Map<Id, PermissionSetAssignment> existingPermsetIdToPsas = new Map<Id, PermissionSetAssignment>();
                for (PermissionSetAssignment psa : existingPsas) {
                    existingPermsetIdToPsas.put(psa.permissionsetid, psa);
                }
                Set<Id> existingPermsetIds = existingPermsetIdToPsas.keySet();
                List<PermissionSetAssignment> toDeletePsas = new List<PermissionSetAssignment>();
                
                for (Map<String,String> entitlmentIdMap : user.entitlements) {
                    String entitlementId = (String) entitlmentIdMap.get('value');
                    Boolean isDelete = !isMetaDelete && 'delete'.equals(entitlmentIdMap.get('operation'));
                    if (entitlementId != null) {
                        if (entitlementId.startsWith('00e')) {
                            u.put('profileid', entitlementId);
                            // don't bother delete, not multi valued.
                        }
                        else if (entitlementId.startsWith('0PS')) {
                            if (!existingPermsetIds.contains(entitlementId)) {
                                PermissionSetAssignment thisPsa = new PermissionSetAssignment();
                                thisPsa.AssigneeId = u.Id;
                                thisPsa.PermissionSetId = entitlementId;
                                newPsas.add(thisPsa);
                                // ignore if not there and is delete, per spec "MAY return a HTTP 400 error." which means I am free to not bother.
                            }
                            else {
                                // if is there and is delete, remove it
                                if (isDelete) {
                                    toDeletePsas.add(existingPermsetIdToPsas.get(entitlementId));
                                }
                            }
                            
                        }
                    }
                }
                Database.DeleteResult[] deleteDRs = Database.delete(toDeletePsas, false);
                for (Database.DeleteResult thisDR : deleteDRs) {
                	if (!thisDR.isSuccess()) {
                		for (Database.Error thisError : thisDR.getErrors()) {
                			error += 'INVALID:' + thisError.getMessage() + ';';
                		}
                		res.statusCode = 400;
                	}
                }
                
                Database.SaveResult[] newSRs = Database.insert(newPsas, false);
                for (Database.SaveResult thisSR : newSRs) {
                	if (!thisSR.isSuccess()) {
                		for (Database.Error thisError : thisSR.getErrors()) {
                			error += 'INVALID:' + thisError.getMessage() + ';';
                		}
                		res.statusCode = 400;
                	}
                }                
            }
            
            // POST
            // Cannot do PermSets until the user is created
            // This will do Profile
            // PermSet processing is defered and package up the PermSets for insertion after the user is created
            if ( user.entitlements != null && !user.entitlements.isEmpty() && isCreate) {
                for (Map<String,String> entitlmentIdMap : user.entitlements) {
                    String entitlementId = (String) entitlmentIdMap.get('value');
                    if (entitlementId != null) {
                        if (entitlementId.startsWith('00e')) {
                            u.put('profileid', entitlementId);
                        }
                        else if (entitlementId.startsWith('0PS')) {
                            PermissionSetAssignment thisPsa = new PermissionSetAssignment();
                            thisPsa.AssigneeId = null; // will provide new user.id after insert
                            thisPsa.PermissionSetId = entitlementId;
                            newPsas.add(thisPsa);                            
                        }
                    }
            	}
            }
              
            
            if ( ( isCreate  ||  isUpdate ) && u.get('profileid') == null ) {
                error += 'REQUIRED_FIELD_MISSING:user_must_have_one_entitlement_which_must_be_a_profileid;';  
                res.statusCode = 500;
            }            

            //Groups
           // PUT, PATCH, DELETE
           // Like PermSets Groups have to be added after user exists
            if ( user.groups != null && !user.groups.isEmpty() && !isCreate){
                boolean isMetaDelete = false;
                List<String> attributes = user.attributes;
                if (isPatch && attributes != null) {
                    for (String attribute : attributes) {
                        if ('entitlements'.equals(attribute)) {
                            isMetaDelete = true;
                        }
                    }
                }
                
				List<GroupMember> existingGroups = [select Id, GroupId from GroupMember where UserOrGroupId = :u.id];
                List<GroupMember> toDeleteGMs = new List<GroupMember>();
                Map<Id, GroupMember> existingIdToGroups = new Map<Id, GroupMember>();
                for (GroupMember gm : existingGroups) {
                    existingIdToGroups.put(gm.GroupId, gm);
                }
            
                Set<Id> existingGroupIds = existingIdToGroups.keySet();
                List<GroupMember> toDeleteGroups = new List<GroupMember>();
                
                for (Map<String,String> groupIdMap : user.groups) {
                    String groupId = (String) groupIdMap.get('value');
                    Boolean isDelete = !isMetaDelete && 'delete'.equals(groupIdMap.get('operation'));
                    if (groupId != null){
                        if (!existingGroupIds.contains(groupId)){
                            GroupMember thisGm = new GroupMember();
                            thisGm.UserOrGroupId = u.id;
                            thisGm.GroupId = groupId;
                            newGMs.add(thisGm);
                        } else {
                            if (isDelete) {
                                toDeleteGMs.add(existingIdtoGroups.get(groupId));
                            }
                        }
                    }
                }
				Database.DeleteResult[] deleteDRs = Database.delete(toDeleteGms, false);
                for (Database.DeleteResult thisDR : deleteDRs) {
                	if (!thisDR.isSuccess()) {
                		for (Database.Error thisError : thisDR.getErrors()) {
                			error += 'INVALID:' + thisError.getMessage() + ';';
                		}
                		res.statusCode = 400;
                	}
                }
                
                Database.SaveResult[] newSRs = Database.insert(newGMs, false);
                for (Database.SaveResult thisSR : newSRs) {
                	if (!thisSR.isSuccess()) {
                		for (Database.Error thisError : thisSR.getErrors()) {
                			error += 'INVALID:' + thisError.getMessage() + ';';
                		}
                		res.statusCode = 400;
                	}
                }                
            }
            
            // POST
            // Like PermSets, add Groups to the list and insert them after user create
            if ( user.groups != null && !user.groups.isEmpty() && isCreate){
                for (Map<String,String> groupIdMap : user.groups) {
                    String groupId = (String) groupIdMap.get('value');
                        GroupMember thisGm = new GroupMember();
                        thisGm.UserOrGroupId = null; //will assign after user crate
                        thisGm.GroupId = groupId;
                        newGMs.add(thisGm);
                }
            }
            
            if ( user.employeeNumber != null) {
                u.employeeNumber = user.employeeNumber;
            }
            
            if ( user.costCenter != null ) {
                error += 'UNSUPPORTED_FIELD:costCenter;';  
                res.statusCode = 500;
            } 
            
            if ( isUpdate ) {
                if ( ( user.organization != null ) && ( user.organization != UserInfo.getOrganizationId())){
                    error += 'INVALID:organization_is_read_only;';  
                    res.statusCode = 500;
                } 
            }
            
            if ( user.division != null) {
                u.division = user.division;
            }
            
            if ( user.department != null) {
                u.department = user.department;
            }
    
            if ( user.manager != null) {
                if (user.manager.containsKey('managerId')) u.managerId = user.manager.get('managerId');
                if (user.manager.containsKey('displayName')) {
                    error += 'INVALID:manager.displayName_is_read_only;';  
                    res.statusCode = 500;
                }
            }
            
            if ( user.delegatedApprover != null) {
                if (user.delegatedApprover.containsKey('delegatedApproverId')) u.delegatedApproverId = user.delegatedApprover.get('delegatedApproverId');
                if (user.delegatedApprover.containsKey('displayName')) {
                    error += 'INVALID:delegatedApprover.displayName_is_read_only;';  
                    res.statusCode = 500;
                }
            }            
            
            if (user.customFieldValues != null) {
                for (String customFieldName : user.customFieldValues.keySet()) {
                    Object customFieldValue = user.customFieldValues.get(customFieldName);
                    
                    // NOTE: customFieldValue is always a string, because of a limitation of 
                    // the parseSimpleObject de-serializing always with getText.
                    // making it dynamic there makes the method not simple in principle, so
                    // for simplicity, we just coerce it back to the right type here based on
                    // the field's type
                    Schema.SOAPType type = customFieldToSoapTypeMap.get(customFieldName);
                    if (type == Schema.SOAPType.Boolean) {
                        u.put(customFieldName, Boolean.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.Date) {
                        u.put(customFieldName, Date.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.DateTime) {
                        u.put(customFieldName, Datetime.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.Double) {
                        u.put(customFieldName, Double.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.ID) {
                        u.put(customFieldName, String.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.Integer) {
                        u.put(customFieldName, Integer.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.String) {
                        u.put(customFieldName, String.valueOf(customFieldValue));
                    }
                    else if (type == Schema.SOAPType.Time) {
                        u.put(customFieldName, Datetime.valueOf(customFieldValue));
                    }     
                    else if (type == Schema.SOAPType.base64binary) {
                        u.put(customFieldName, EncodingUtil.base64Decode((String) customFieldValue));
                    }                                                    
                    else {
                        error += 'INVALID:unsupported field type for field : ' + customFieldName;  
                        res.statusCode = 500;
                    }                                                                            
                }
            }

            // HANDLE EXTERNAL USERS
            // if userType is set and (.isPortal) then :
            // If no externalUserProperties -> create account and contact on the fly
            // if has externalUserProperties -> if has account create contact on the fly, otherwise use as is
            if (isCreate) {
                if(u.profileId != null){
                    Id profileId = u.profileId; // required for create
                    List<Profile> profiles = [select usertype from profile where Id = :profileId];
                    if (profiles.size() != 1) {
                        error += 'INVALID: profile id is invalid : ' + profileId;  
                        res.statusCode = 400;                        
                    }
                    else {
                        Profile profile = profiles.get(0);
                        boolean inferringExternalUserProfile = isPortalType(profile.userType);
                        // only run this if user knows what he is doing, i.e. specified an appropriate profile type.
                        if (inferringExternalUserProfile) {
                            Id accountId;
                            Id contactId;
                            if (user.externalUserProperties != null && user.externalUserProperties.get('accountId') != null) {
                                // if set, just pick it up                        
                                accountId = (Id) user.externalUserProperties.get('accountId');
                            }
                            else {
                                // else create one on the fly
                                Account jitAccount = new Account();
                                jitAccount.Name = user.userName + 'JITUserAccount';
                                jitAccount.OwnerId = UserInfo.getUserId();
                                Database.insert(jitAccount);
                                accountId = jitAccount.Id;
                             }
         
                            // if contact is set, use as is.
                            if (user.externalUserProperties != null && user.externalUserProperties.get('contactId') != null) {
                                contactId = (Id) user.externalUserProperties.get('contactId');
                            }
                            else {
                                // create a contact on the fly using the account
                                Contact jitContact = new Contact();
                                jitContact.FirstName = u.firstName;
                                jitContact.LastName = u.lastName;
                                jitContact.accountId = accountId;
                                jitContact.Email = u.email;
                                Database.insert(jitContact);
                                contactId = jitContact.Id;
                            }
                            u.contactId = contactId;
                        }
                    }
                }
            }
            else {
                // for updates, account id is fair. contact is not changeable.
                Id userId = u.id;
                User userWithContact = [select contactId, ProfileId, userType from user where Id = :userId];
                Id profileId = userWithContact.profileId;
                Profile profile = [select usertype from profile where Id = :profileId];
                boolean inferringExternalUserProfile = isPortalType(profile.userType);
                if (inferringExternalUserProfile) { 
                    Id accountId;
                    if (user.externalUserProperties != null && user.externalUserProperties.get('accountId') != null) {
                        // if set, just pick it up                        
                        accountId = (Id) user.externalUserProperties.get('accountId');
                    }
                    Id contactId = userWithContact.contactId;
                    
                    Contact existingContact = [select Id from Contact where Id = :contactId];
                    existingContact.accountId = accountId;
                    Database.update(existingContact);
                }
            }
            u.emailencodingkey = 'UTF-8';
        }

        if (res.statusCode == 201 ) {
            try {
                if (isCreate) {
                    insert u;
                    // now do PermSet assignments
                    List <PermissionSetAssignment> updatedPsas = new List<PermissionSetAssignment>();
                    for (PermissionSetAssignment psa : newPsas){
                        PermissionSetAssignment tempPSA = new PermissionSetAssignment();
                        tempPSA.PermissionSetId = psa.PermissionSetId;
                        tempPSA.AssigneeId = u.id;
                        updatedPSas.add(tempPSA);
                    }
                    if (!newPsas.isEmpty()){
                        Database.SaveResult[] newSRs = Database.insert(updatedPsas, false);
                        for (Database.SaveResult thisSR : newSRs) {
                            if (!thisSR.isSuccess()) {
                                for (Database.Error thisError : thisSR.getErrors()) {
                                    error += 'INVALID:' + thisError.getMessage() + ';';
                                }
                                res.statusCode = 400;
                            }
                        }                        
                    }
					// now do Group assignments
					List<GroupMember> updatedGMs = new List<GroupMember>();
                    for (GroupMember gm : newGMs){
                        GroupMember tempGM = new GroupMember();
                        tempGM.GroupId = gm.GroupId;
                        tempGM.UserOrGroupId = u.id;
                        updatedGMs.add(tempGM);
                    }
                    if (!newPsas.isEmpty()){
                        Database.SaveResult[] newSRs = Database.insert(updatedGMs, false);
                        for (Database.SaveResult thisSR : newSRs) {
                            if (!thisSR.isSuccess()) {
                                for (Database.Error thisError : thisSR.getErrors()) {
                                    error += 'INVALID:' + thisError.getMessage() + ';';
                                }
                                res.statusCode = 400;
                            }
                        }                        
                    }                    
                    if (user.password != null) {
                        System.setPassword(u.id, user.password);
                    }
                    else {  
                        System.resetPassword(u.id, true);
                    }
                } else {
                    update u;
                    if (user.password != null && u.isActive) {
                        System.setPassword(u.id, user.password);
                    }  
                    res.statusCode = 200;
                }    
                
                String soql = FilterTranslator.buildAttributeQueryString(null, 'id eq \"' + u.id + '\"', null, null, scimNameToUserSObjectNameMap, 'User', 'isActive = true', null, null).getActualQuery();
                List<User> users = Database.query(soql);
                if (!users.isEmpty()) {
                    // active could be set to false in which case will not return.
                    User uNew = users.get(0);
                    res.addHeader('Location', 'https://' + req.headers.get('Host') + '/services/apexrest/v2/Users/' + uNew.Id);    
                    res.responseBody = UserResource.serializeUser(uNew,req.headers.get('Host'),req.headers.containsKey('X-Prettyprint'));
                }
                
                // return to commit, anything else rolls back
                return;
                
            } catch (Exception e) {
                res.statusCode = 409;
                res.responseBody = ScimError.serializeError(res.statusCode, e.getMessage(), req.headers.containsKey('X-Prettyprint'));
            }
        } else {
            res.statusCode = 409;
            res.responseBody = ScimError.serializeError(res.statusCode, error, req.headers.containsKey('X-Prettyprint'));
        }
        
        // the inserting failed in some ways, we rollback.
        Database.rollback(sp);
    }
    
    public static void doPatch(RestRequest req, RestResponse res, User u){
        res.addHeader('Content-Type', 'application/json');    
        res.statusCode = 201;
        String error = '';
        UserResource user;
        Savepoint sp = Database.setSavepoint();
        try {
             user = new UserResource(req.requestBody);
        } catch (ScimException scex) {
            res.statusCode = scex.getStatusCode();
            error = scex.getMessage();
        } catch (Exception e) {
            res.statusCode = 500;
            error = e.getMessage();
        }
		

        System.debug('Patched User: ' + user);
    }
    
    public static boolean isPortalType(String userType) {
        return portalUserTypes.contains(userType.toLowerCase());
    }  
    
    public static void doDelete(System.RestRequest req, System.RestResponse res) {
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;          
        String host = req.headers.get('Host');
        
        User[] u = Database.query('select id, isActive from user where id=\'' + uriParts[numParts] + '\'');
        if(u.size() == 1 && u[0].isActive) {
            //TODO Add check for certain conditions that make delete not so simple
            //Matt to provide
//            User[] userRefedBy = Database.query('select id from user where id=\'' + uriParts[numParts] + '\'');
        	u[0].isActive = false;
        	update u[0];
        	res.statusCode = 200;
        } else {
        	res.statusCode = 404;
			res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Users/' + uriParts[numParts] + ' not found', req.headers.containsKey('X-Prettyprint'));
        }
    }  
    
    public static Blob serializeUser(User user, String attributes, String host, Boolean prettyPrint) {
        JSONGenerator gen = JSON.createGenerator(prettyPrint);
        List<User> users = new List<User>();
        users.add(user);
        serializeUserWithGenerator(users,attributes,host,gen);
        return Blob.valueOf(gen.getAsString());
    }
    
    public static Blob serializeUser(User user, String host, Boolean prettyPrint) {
        JSONGenerator gen = JSON.createGenerator(prettyPrint);
        List<User> users = new List<User>();
        users.add(user);
        serializeUserWithGenerator(users,null,host,gen);
        return Blob.valueOf(gen.getAsString());
    }

    public static boolean shouldSerialize(String attributeName, String attributes) {
        return ScimResource.shouldSerialize(attributeName, attributes, scimNameToUserSObjectNameMap);
    }       

    public static void serializeUserWithGenerator(List<User> users, String attributes, String host, JSONGenerator gen) {
    
        // bulk get delegated approvers' names
        // This is quite silly, runtime enforcements prevent the field to be a group, (see W-1097715, CL 2154516)
        // but the udd says the field is a fk to user/group
        // which also prevents us from querying .delegatedApprover.Name
        Set<Id> userApproverId = new Set<Id>();
        Map<Id, User> userApproverMap = new Map<Id,User>();
        if (shouldSerialize(enterpriseExtensionURN, attributes)) {
            for (User thisUser : users) {
                String delegatedApproverId = thisUser.delegatedApproverId;
                if (delegatedApproverId != null && delegatedApproverId.startsWith('005')) {
                    userApproverId.add(thisUser.delegatedApproverId);
                }
            }
            userApproverMap = new Map<Id,User>([select Id, Name from User where Id in :userApproverId]);
        }
    	
        // based $ref for all scim objects
        String scimRef = host + '/services/apexrest/v2/';
        
        // bulk get the psa assignments
        Map<Id, List<PermissionSetAssignment>> psaMap = new Map<Id, List<PermissionSetAssignment>>();
        if (shouldSerialize('entitlements', attributes)) {
            for (PermissionSetAssignment psa : [select AssigneeId, PermissionSetId, PermissionSet.Name FROM PermissionSetAssignment WHERE assignee.isActive = true AND assigneeId IN :users and permissionSet.IsOwnedByProfile = false]) {
                Id assigneeId = psa.AssigneeId;
                List<PermissionSetAssignment> psas = psaMap.get(assigneeId);
                if (psas == null) {
                    psas = new List<PermissionSetAssignment>();
                    psaMap.put(assigneeId, psas);
                }
                psas.add(psa);
            }
        }

        // bulk get the group membership        
        Map<Id, List<GroupMember>> gmMap = new Map<Id, List<GroupMember>>();
        if (shouldSerialize('groups', attributes)) {
            for (GroupMember gm : [ select UserOrGroupId, Id, GroupId, Group.Name from GroupMember where UserOrGroupId IN :users]) {
                Id userOrGroupId = gm.UserOrGroupId;
                List<GroupMember> gms = gmMap.get(userOrGroupId);
                if (gms == null) {
                    gms = new List<GroupMember>();
                    gmMap.put(userOrGroupId, gms);
                }
                gms.add(gm);
            }
        }
    
        for (User user : users) {
            Map<String, Schema.SObjectField> r = Schema.sObjectType.User.fields.getMap();
            Map<String, Object> customFieldMap = new Map<String, Object>();
            if (shouldSerialize('urn:salesforce:schemas:extension:' + UserInfo.getOrganizationId(), attributes)) {
                for (String key : r.keySet()) {
                    SObjectField thisField = r.get(key);
                    DescribeFieldResult thisDescribeResult = thisField.getDescribe();
                    if (thisDescribeResult.isCustom()) {
                        try {
                            Object value = user.get(thisDescribeResult.getName());  
                            if (value != null) {
                                customFieldMap.put(thisDescribeResult.getName(), value);
                            }
                        }
                        catch (Exception ex) {
                            // Eat it silently.
                            // Some field types do not support get (e.g. geolocation composite field)
                        }
                    }
                }    
            }
            
            boolean hasExternalUserExtensions = false;
            if (shouldSerialize('urn:salesforce:schemas:extension:external:1.0', attributes)) {
                if (user.AccountId != null) hasExternalUserExtensions = true;
                if (user.ContactId != null) hasExternalUserExtensions = true;
            }        
        
            gen.writeStartObject();
                gen.writeFieldName('schemas');
                gen.writeStartArray();
                    gen.writeString('urn:ietf:params:scim:schemas:core:2.0:User');
                    gen.writeString(enterpriseExtensionURN);
                    if (!customFieldMap.isEmpty()) {
                        gen.writeString('urn:salesforce:schemas:extension:' + UserInfo.getOrganizationId());
                    }
                    if (hasExternalUserExtensions) {
                        gen.writeString('urn:salesforce:schemas:extension:external:1.0');
                    }
                gen.writeEndArray();
                gen.writeStringField('id', user.Id);
                if ((shouldSerialize('userName', attributes)) && (user.Username != null)) gen.writeStringField('userName', user.Username);
                if ((shouldSerialize('externalId', attributes))) {
                    String federationIdentifier = (String) user.get('FederationIdentifier');
                    if (federationIdentifier != null) {
                        gen.writeStringField('externalId', federationIdentifier);
                    }
                }
                if (shouldSerialize('name', attributes)) {
                    gen.writeFieldName('name');
                        gen.writeStartObject();
                            if ((shouldSerialize('name.formatted', attributes)) && (user.Name != null))  gen.writeStringField('formatted', user.Name);
                            if ((shouldSerialize('name.familyName', attributes)) && (user.Lastname != null)) gen.writeStringField('familyName', user.Lastname);
                            if ((shouldSerialize('name.givenName', attributes)) && (user.Firstname != null)) gen.writeStringField('givenName', user.Firstname);
                        gen.writeEndObject();
                }
                if ((shouldSerialize('displayName', attributes)) && (user.Name != null)) gen.writeStringField('displayName', user.Name);
                if ((shouldSerialize('nickName', attributes)) && (user.CommunityNickname != null)) gen.writeStringField('nickName', user.CommunityNickname);
                if (shouldSerialize('profileUrl', attributes))  gen.writeStringField('profileUrl', 'https://' + host + '/' + user.Id);
                if (shouldSerialize('emails', attributes)) {
                  gen.writeFieldName('emails');
                    gen.writeStartArray();
                        gen.writeStartObject();
                            gen.writeStringField('type', 'work');
                            gen.writeBooleanField('primary', true);
                            gen.writeStringField('value', user.Email);
                        gen.writeEndObject();
                    gen.writeEndArray();
                }
                if (shouldSerialize('addresses', attributes)) { 
                if  ((user.Street != null) || (user.City != null) || (user.State != null) || (user.postalCode != null) || (user.Country != null)) { 
                    gen.writeFieldName('addresses');
                        gen.writeStartArray();
                            gen.writeStartObject();
                                gen.writeStringField('type', 'work');
                                gen.writeBooleanField('primary', true);
                                String formatted = '';
                                if (user.Street != null) {
                                    gen.writeStringField('streetAddress', user.Street);
                                    formatted += user.Street + '\n';
                                }
                                if (user.City != null) {
                                    gen.writeStringField('locality', user.City);
                                    formatted += user.City + ', ';
                                }
                                if (user.State != null) {
                                    gen.writeStringField('region', user.State);
                                    formatted += user.State + ' ';
                                }
                                if (user.PostalCode != null) {
                                    gen.writeStringField('postalCode', user.PostalCode);
                                    formatted += user.PostalCode + ' ';
                                }
                                if (user.Country != null) {
                                    gen.writeStringField('country', user.Country);
                                    formatted += user.Country;
                                }
                                gen.writeStringField('formatted', formatted);
                            gen.writeEndObject();
                    gen.writeEndArray();
                    }
                }
                if ((shouldSerialize('phoneNumbers', attributes)) &&  ((user.Phone != null) || (user.MobilePhone != null) || (user.Fax != null))) {    
                    gen.writeFieldName('phoneNumbers');
                        gen.writeStartArray();
                            if (user.Phone != null) {
                                gen.writeStartObject();
                                    gen.writeStringField('type', 'work');
                                    if (user.Phone != null) gen.writeStringField('value', user.Phone);
                                gen.writeEndObject();
                            }
                            if (user.MobilePhone != null) {
                                gen.writeStartObject();
                                    gen.writeStringField('type', 'mobile');
                                    if (user.MobilePhone != null) gen.writeStringField('value', user.MobilePhone);
                                gen.writeEndObject();
                            }
                            if (user.Fax != null) {
                                gen.writeStartObject();
                                    gen.writeStringField('type', 'fax');
                                    if (user.Fax != null) gen.writeStringField('value', user.Fax);
                                gen.writeEndObject();
                            }
                        gen.writeEndArray();
                }
                if ((shouldSerialize('photos', attributes)) &&  ((user.FullPhotoUrl != null) || (user.SmallPhotoUrl != null))) {
                    gen.writeFieldName('photos');
                         gen.writeStartArray();
                            if (user.FullPhotoUrl != null) {
                                gen.writeStartObject();
                                    gen.writeStringField('type', 'photo');
                                    if (user.FullPhotoUrl != null) gen.writeStringField('value', user.FullPhotoUrl);
                                gen.writeEndObject();
                            }
                            if (user.SmallPhotoUrl != null) {
                                gen.writeStartObject();
                                    gen.writeStringField('type', 'thumbnail');
                                    if (user.SmallPhotoUrl != null) gen.writeStringField('value', user.SmallPhotoUrl);
                                gen.writeEndObject();
                            }
                        gen.writeEndArray();
                }    
                if ((shouldSerialize('userType', attributes)) &&  (user.UserType != null)) gen.writeStringField('userType', user.UserType);
                if ((shouldSerialize('title', attributes)) &&  (user.Title != null)) gen.writeStringField('title', user.Title);
                if ((shouldSerialize('preferredLanguage', attributes)) &&  (user.LanguageLocaleKey != null)) gen.writeStringField('preferredLanguage', user.LanguageLocaleKey);
                if ((shouldSerialize('locale', attributes)) &&  (user.LocaleSidKey != null)) gen.writeStringField('locale', user.LocaleSidKey);
                if ((shouldSerialize('timezone', attributes)) &&  (user.TimeZoneSidKey != null)) gen.writeStringField('timezone', user.TimeZoneSidKey);
                if ((shouldSerialize('active', attributes)) && (user.IsActive != null)) gen.writeBooleanField('active', user.IsActive);
                if (shouldSerialize('entitlements', attributes)) {
                gen.writeFieldName('entitlements');
                    gen.writeStartArray();
                        gen.writeStartObject();
                            gen.writeStringField('value', user.ProfileId);
                           	gen.writeStringField('$ref', '/Entitlements/' + user.ProfileId);                    
                            gen.writeStringField('display', user.Profile.Name);   
                    		gen.writeStringField('type', 'Profile');
                            gen.writeBooleanField('primary', true);
                        gen.writeEndObject();
                        List<PermissionSetAssignment> assignments = psaMap.get(user.id);
                        if (assignments != null) {
                            for (PermissionSetAssignment assignment : assignments) {
                            gen.writeStartObject();
                                gen.writeStringField('value', assignment.PermissionSetId);
	                           	gen.writeStringField('$ref', '/Entitlements/' + assignment.PermissionSetId);                    
                                gen.writeStringField('display', assignment.PermissionSet.Name);                        
	                    		gen.writeStringField('type', 'Permission Set');
                                gen.writeBooleanField('primary', false);
                            gen.writeEndObject();                    
                            }
                        }
                    gen.writeEndArray(); 
                }
            
                if (shouldSerialize('groups', attributes)) {
                    List<GroupMember> memberships = gmMap.get(user.id);
                    gen.writeFieldName('groups');
                    gen.writeStartArray();
                        if (memberships != null) {
                            for ( GroupMember membership : memberships ) {
                                gen.writeStartObject();
                                    gen.writeStringField('value', membership.GroupId);
                                	gen.writeStringField('$ref', '/Groups/' + membership.GroupId);
                                    gen.writeStringField('display', membership.Group.Name);
                                gen.writeEndObject();        
                            }
                        }
                    gen.writeEndArray(); 
                }        
                
                if (shouldSerialize('roles', attributes) && (user.userRoleId != null)) {
                    gen.writeFieldName('roles');
                    gen.writeStartArray();
                        gen.writeStartObject();
                            gen.writeStringField('value', user.UserRoleId);
                            gen.writeStringField('$ref', '/Roles/' + user.UserRoleId);
                            gen.writeStringField('display', user.UserRole.Name);
                        gen.writeEndObject();  
                    gen.writeEndArray(); 
                }        
                
    
                if (shouldSerialize(enterpriseExtensionURN, attributes)) {
                    gen.writeFieldName(enterpriseExtensionURN);
                    gen.writeStartObject();
                        gen.writeStringField('organization', UserInfo.getOrganizationId());
                        if (user.employeeNumber != null) gen.writeStringField('employeeNumber', user.employeeNumber);
                        if (user.Division != null) gen.writeStringField('division', user.Division);
                        if (user.Department != null) gen.writeStringField('department', user.Department);
                        if (user.ManagerId != null) {
                            gen.writeFieldName('manager'); 
                            gen.writeStartObject();
                                gen.writeStringField('managerId', user.managerId);
                                gen.writeStringField('$ref', '/Users/' + user.managerId);
                            	gen.writeStringField('displayName', user.manager.Name);
                            gen.writeEndObject();   
                        }
                        if (user.DelegatedApproverId != null) {
                            gen.writeFieldName('delegatedApprover'); 
                            gen.writeStartObject();
                                gen.writeStringField('delegatedApproverId', user.delegatedApproverId);
                                gen.writeStringField('$ref', '/Users/' + user.delegatedApproverId);
                            String delegatedApproverId = user.delegatedApproverId;
                                if (delegatedApproverId != null && delegatedApproverId.startsWith('005')) {
                                    gen.writeStringField('displayName', userApproverMap.get(user.delegatedApproverId).Name);
                                }
                            gen.writeEndObject();   
                        }                        
                        
                    gen.writeEndObject();    
                }
                
                if (shouldSerialize('urn:salesforce:schemas:extension:external:1.0', attributes) && hasExternalUserExtensions) {
                    gen.writeFieldName('urn:salesforce:schemas:extension:external:1.0');
                    gen.writeStartObject();
                        if (user.AccountId != null) gen.writeStringField('accountId', user.AccountId);
                        if (user.ContactId != null) gen.writeStringField('contactId', user.ContactId);
                    gen.writeEndObject();    
                }                    
                
                if (shouldSerialize('urn:salesforce:schemas:extension:' + UserInfo.getOrganizationId(), attributes)) {
                    if (!customFieldMap.isEmpty()) {    
                        gen.writeFieldName('urn:salesforce:schemas:extension:' + UserInfo.getOrganizationId());
                        gen.writeStartObject();
                            for (String key : customFieldMap.keySet()) {
                                Object value = customFieldMap.get(key);
                                if (value != null) {
                                    gen.writeObjectfield(key, value);
                                }
                            }                
                        gen.writeEndObject();    
                    }
                }            
                
                if (shouldSerialize('meta', attributes)) {
                    gen.writeFieldName('meta');
                        gen.writeStartObject();
                            String createdFormated = user.CreatedDate.format('yyyy-MM-dd');
                            createdFormated += 'T';
                            createdFormated += user.CreatedDate.formatGmt('hh:mm:ss');
                            gen.writeStringField('created', createdFormated + 'Z');
                            
                            String lastmodFormated = user.LastModifiedDate.format('yyyy-MM-dd');
                            lastmodFormated += 'T';
                            lastmodFormated += user.LastModifiedDate.formatGmt('hh:mm:ss');
                            gen.writeStringField('lastModified', lastmodFormated + 'Z');
                            
                            String base = URL.getSalesforceBaseUrl().toExternalForm();
                            
                            String path = '/services/apexrest/v2/Users/' + user.id;
                            gen.writeStringField('location', base + path);
                            
                            Blob digest = Crypto.generateDigest('SHA-1',  Blob.valueOf(user.id + lastmodFormated));
                            gen.writeStringField('version', EncodingUtil.convertToHex(digest));
                    gen.writeEndObject();
                }
            gen.writeEndObject();
        }
    }    
    
    public static boolean isValidId(String id) {
//        return java:common.udd.Udd.isValidId(id); JUST FOR IAN
	return true;
    }
   
    @HttpGet
    global static void doGet() {
        RestResponse res = RestContext.response;
        RestRequest req = RestContext.request;
        try {
            String host = req.headers.get('Host');
            res.addHeader('Content-Type', 'application/json');
            String[] uriParts = req.requestURI.split('/',0);
            Integer numParts = uriParts.size() - 1;
            if (numParts >= 4) { 
                res.statusCode = 404;
                res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource', req.headers.containsKey('X-Prettyprint'));
            } else {
            
                List<User> users = new List<User>();
                String attributes = req.params.get('attributes');
                if (attributes != null) {
                    attributes = attributes.replaceAll(' ', '');
                }
                
                if(isValidId(uriParts[numParts])){
                    String soql = FilterTranslator.buildAttributeQueryString(attributes, 'id eq \"' + uriParts[numParts] + '\"', null, null, scimNameToUserSObjectNameMap, 'User',  'isActive = true', null, null).getActualQuery();
                    users = Database.query(soql);
    
                    if ( !users .isEmpty()  ) {
                        res.addHeader('Location', 'https://' + host + '/services/scim/v2/Users/' + users.get(0).Id);   
                        res.statusCode = 200; 
                        res.responseBody = UserResource.serializeUser(users.get(0),attributes,host,req.headers.containsKey('X-Prettyprint'));
                    } else {
                        res.statusCode = 404;
                        res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Users/' + uriParts[numParts] + ' not found', req.headers.containsKey('X-Prettyprint'));
                    }
                }else{
                    res.statusCode = 404;
                    res.responseBody = SCIMError.serializeError(res.statusCode, 'Invalid Id', req.headers.containsKey('X-Prettyprint'));
                }
            }
        }
        catch (ScimException ex) {
            res.statusCode = 400;
            res.responseBody = SCIMError.serializeError(res.statusCode, ex.getMessage(), req.headers.containsKey('X-Prettyprint'));
            return;
        }        
    }

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String method = req.headers.get('X-HTTP-Method-Override');
        if ( method == null ) method = 'POST';
        if ( method.equals('DELETE') ) {
            doDelete(req,res); 
        }else {
            User user = new User();
            doCreateOrUpdate(req, res, user, method); 
        }
    }    
    
    @HttpDelete
    global static void doDelete() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        doDelete(req, res);
    }    

    @HttpPut
    global static void doPut() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;
           
        if (numParts >= 4) { 
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource', req.headers.containsKey('X-Prettyprint'));
            return;
        } 
        
        try {
            String soql = FilterTranslator.buildAttributeQueryString(null, 'id eq \"' + uriParts[numParts] + '\"', null, null, scimNameToUserSObjectNameMap, 'User',  'isActive = true', null, null).getActualQuery();
            List<User> users = Database.query(soql);
            if (users != null && users.size() == 1 ) {
                User user = users.get(0);            
                user.Username = null;
                if (scimNameToUserSObjectNameMap.containsKey('externalId')) {
                    user.put('FederationIdentifier', null);
                }
                user.Lastname = null;
                user.Firstname = null;
                user.CommunityNickname = null;
                user.Email = null;
                user.Street = null;
                user.City = null;
                user.State = null;
                user.PostalCode = null;
                user.Country = null;
                user.Phone = null;
                user.MobilePhone = null;
                user.Fax = null;
                user.Title = null;
                user.LanguageLocaleKey = null;
                user.LocaleSidKey = null;
                user.IsActive = null;
                user.ProfileId = null;
                user.Profile.Name = null;
                user.employeeNumber = null;
                user.Division = null;
                user.Department = null;
                user.managerId = null;
                user.UserRoleId = null;
                
                // NOTE ABOUT CUSTOM FIELDS
                // It is impossible to know what the proper default values for each and every custom fields is.
                // And not all custom fields are nilable.
                // So instead of trying to be clever, opting to not handle it instead.
                // Just tell the user to supply desired default values here.
                
                doCreateOrUpdate(req, res, user, 'PUT'); 
            } else {
                res.statusCode = 404;
                res.responseBody = ScimError.serializeError(res.statusCode, 'Resource https://' + req.headers.get('Host') + '/services/apexrest/v2/Users/' + uriParts[numParts] + ' not found', req.headers.containsKey('X-Prettyprint'));
            } 
        } catch ( Exception e ) {
             res.statusCode = 404;
             res.responseBody = ScimError.serializeError(res.statusCode, e.getMessage(), req.headers.containsKey('X-Prettyprint'));
        } 
    }
   
    public static Map<String, String> setResponse (String errorType, String attrName, String errorString, String responseCode){
		Map<String, String> response = new Map<String, String>();
		response.put('statusCode', responseCode);
        response.put('errorString', errorType + ' ' + attrName + ' ' + errorString);
        return response;
    }
 
    public static boolean isUnsupported (String attr) {
		Boolean result = false;
        if (unsupportedAttrs.contains(attr)) {
            result = true;
        }
        return result;
    }
    
    public static boolean isReadOnly (String attr) {
		Boolean result = false;
        if (readOnlyAttrs.contains(attr)) {
            result = true;
        }
        return result;
    }
    
    @HttpPatch
    global static void doPatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');    
        res.statusCode = 201;
        String error = '';

        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;           
        if (numParts >= 4) { 
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource', req.headers.containsKey('X-Prettyprint'));
            return;
        }                 

        User user = [ Select ID, Username, IsActive from User where Id = :uriParts[numParts]];
		User tempUser = new User();
        tempUser.id = user.Id;
        //doCreateOrUpdate(req, res, user, 'PATCH');
        // Old approach
        //doPatch(req, res, user);
        
        SCIMPatchParser userPP = new SCIMPatchParser(req.requestBody.toString());
        String schema = userPP.schemas.get(0);
        if (!schema.equals('urn:ietf:params:scim:api:messages:2.0:PatchOp')){
            res.statusCode = 400;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'Improper Schema.', req.headers.containsKey('X-Prettyprint'));
            return;
        }
        
        Savepoint sp = Database.setSavepoint();
        try {
			for (SCIMPatchParser.Operation op : userPP.operations){
				String operation = op.op;
				String path = op.path;
				Set<String> values = new Set<String>();

                if (path == null) {
                    for (Map<String, Object> val : op.value){
                        for (String key : val.keySet()){
							// check key for validity
                            if ((!isUnsupported(key)) && (!isReadOnly(key))) {
                                // key = givenName / firstName
                                if ((key == 'givenName') && (operation == 'remove')) {
                                    tempUser.firstname = null;
                                } else if (key == 'givenName'){
                                    tempUser.firstname = (String) val.get(key);
                                }

                                // key = familyName / lastName
                                if ((key == 'familyName') && (operation == 'remove')) {
                                    tempUser.lastName = null;
                                } else if (key == 'familyName'){
                                    tempUser.lastName = (String) val.get(key);
                                }
                                
                                // key = title / title
                                if ((key == 'title') && (operation == 'remove')) {
                                    tempUser.title = null;
                                } else if (key == 'title'){
                                    tempUser.title = (String) val.get(key);
                                }

                                // key = preferredLanguage / languagelocalekey
                                if ((key == 'preferredLanguage') && (operation == 'remove')) {
                                    tempUser.languagelocalekey = null;
                                } else if (key == 'preferredLanguage'){
                                    tempUser.languagelocalekey = (String) val.get(key);
                                }

                                // key = locale / localesidkey
                                if ((key == 'locale') && (operation == 'remove')) {
                                    tempUser.localesidkey = null;
                                } else if (key == 'locale'){
                                    tempUser.localesidkey = (String) val.get(key);
                                }

                                // key = timezone / timezonesidkey
                                if ((key == 'timezone') && (operation == 'remove')) {
                                    tempUser.timezonesidkey = null;
                                } else if (key == 'timezone'){
                                    tempUser.timezonesidkey = (String) val.get(key);
                                }
                                
                                // key = employeeNumber / employeeNumber
                                if ((key == 'employeeNumber') && (operation == 'remove')) {
                                    tempUser.employeeNumber = null;
                                } else if (key == 'employeeNumber'){
                                    tempUser.employeeNumber = (String) val.get(key);
                                }

                                // key = division / division
                                if ((key == 'division') && (operation == 'remove')) {
                                    tempUser.division = null;
                                } else if (key == 'division'){
                                    tempUser.division = (String) val.get(key);
                                }

                                // key = department / department
                                if ((key == 'department') && (operation == 'remove')) {
                                    tempUser.department = null;
                                } else if (key == 'department'){
                                    tempUser.department = (String) val.get(key);
                                }

                                // key = nickName / communityNickname
                                if ((key == 'nickName') && (operation == 'remove')) {
                                    tempUser.communityNickname = null;
                                } else if (key == 'nickName'){
                                    tempUser.communityNickname = (String) val.get(key);
                                }

                                // manager / managerId
                                if ((key == 'manager') && (operation == 'remove')) {
                                    tempUser.managerId = null;
                                } else if (key == 'manager'){
                                    tempUser.managerId = (Id) val.get(key);
                                }
        
                                // delegatedApprover / delegatedApproverId
                                if ((key == 'delegatedApprover') && (operation == 'remove')) {
                                    tempUser.delegatedApproverId = null;
                                } else if (key == 'delegatedApprover'){
                                    tempUser.delegatedApproverId = (Id) val.get(key);
                                }
                                
                                // active / isActive
                                if ((key == 'active') && (operation == 'remove')) {
                                    tempUser.isActive = false;
                                } else if (key == 'active'){
                                    tempUser.isActive = (Boolean) val.get(key);
                                }

                                // roles / userRoleId
                                if ((key == 'roles') && (operation == 'remove')) {
                                    tempUser.userRoleId = null;
                                } else if (key == 'roles'){
                                    Integer roleCount = 0;
                                    List<String> roleIds = new List<String>();
                                    for (Object roleId : (List<Object>) val.get(key)){
                                        roleIds.add((String)roleId);
                                        roleCount++;
                                    }
                                    if (roleCount != 1) {
                                        error += 'INVALID:user_must_have_only_one_role;';  
                                        res.statusCode = 500;
                                        break;
                                    } else {
                                        tempUser.userRoleId = roleIds[0];
                                    }
                                }
                                
                                // groups
                                if (key == 'groups') {
                                    List<GroupMember> groupsToProcess = new List<GroupMember>();
									// there has got to be a better way to get the size here but object conversion was driving me crazy
                                    List<Object> groupList = (List<Object>)val.get(key);                                    
                                    if (groupList.size() != 0 ){
                                        for (Object g : (List<Object>) val.get(key)){
                                            Map<String, Object> tempGroupId = (Map<String, Object>) g;
                                            GroupMember gm = new GroupMember();
                                            gm.GroupId = (String) tempGroupId.get('id');
                                            gm.UserOrGroupId = user.id;
                                            groupsToProcess.add(gm);
                                        }
                                    } else {
                                         groupsToProcess = [select id from GroupMember where userOrGroupId =: user.id];
                                    }
                                    if  ((operation == 'remove') || (operation == 'replace')) {
                                        // if replace then remove everything and add back what is specified
                                        List<GroupMember> currentGroups = [select id, groupId from GroupMember where userOrGroupId =: user.id];
                                        delete currentGroups;                                
                                    }
                                    if ((operation == 'add') || (operation == 'replace')){
                                        insert groupsToProcess;
                                    }
                                }
                            } else {
                                if (isUnsupported(key)){
                                    res.statusCode = 500;
                                    error += 'UNSUPPORTED_FIELD: ' + key;
                                    SCIMException e = new SCIMException();
                                    e.setMessage(error);
                                    e.setStatusCode(500);
                                    throw e;
                                }
                                
                                if (isReadOnly(key)){
                                    res.statusCode = 500;
                                    error += 'INVALID: ' + key + ' is read only';
                                    SCIMException e = new SCIMException();
                                    e.setMessage(error);
                                    e.setStatusCode(500);
                                    throw e;
                                }

                            }
                        }
                    }
                } else {
                    // check path for validity
                    if ((!isUnsupported(path)) && (!isReadOnly(path))) {
						// path = givenName / firstName
                        if (((path == 'givenName') || (path == 'name.givenName')) && (operation == 'remove')) {
                            tempUser.firstname = null;
                        } else if ((path == 'givenName') || (path == 'name.givenName')){
                            tempUser.firstname = (String) op.value[0].get('value');
                        }

                        // familyName / lastName
                        if (((path == 'givenName') || (path == 'name.familyName')) && (operation == 'remove')) {
                            tempUser.lastname = null;
                        } else if ((path == 'givenName') || (path == 'name.familyName')){
                            tempUser.lastname = (String) op.value[0].get('value');
                        }

						// title
                        if ((path == 'title') && (operation == 'remove')) {
                            tempUser.title = null;
                        } else if (path == 'title'){
                            tempUser.title = (String) op.value[0].get('value');
                        }
                
                        // preferredLanguage / languagelocalekey
                        if ((path == 'preferredLanguage') && (operation == 'remove')) {
                            tempUser.languagelocalekey = null;
                        } else if (path == 'preferredLanguage'){
                            tempUser.languagelocalekey = (String) op.value[0].get('value');
                        }

                        // locale / localesidkey
                        if ((path == 'preferredLanguage') && (operation == 'remove')) {
                            tempUser.localesidkey = null;
                        } else if (path == 'preferredLanguage'){
                            tempUser.localesidkey = (String) op.value[0].get('value');
                        }

                        // timezone / timezonesidkey
                        if ((path == 'timezone') && (operation == 'remove')) {
                            tempUser.timezonesidkey = null;
                        } else if (path == 'timezone'){
                            tempUser.timezonesidkey = (String) op.value[0].get('value');
                        }

                        // employeeNumber / employeeNumber
                        if ((path == 'employeeNumber') && (operation == 'remove')) {
                            tempUser.employeeNumber = null;
                        } else if (path == 'employeeNumber'){
                            tempUser.employeeNumber = (String) op.value[0].get('value');
                        }

                        // division / division
                        if ((path == 'division') && (operation == 'remove')) {
                            tempUser.division = null;
                        } else if (path == 'division'){
                            tempUser.division = (String) op.value[0].get('value');
                        }

                        // department / department
                        if ((path == 'department') && (operation == 'remove')) {
                            tempUser.department = null;
                        } else if (path == 'department'){
                            tempUser.department = (String) op.value[0].get('value');
                        }

                        // nickName / communityNickname
                        if ((path == 'nickName') && (operation == 'remove')) {
                            tempUser.communityNickname = null;
                        } else if (path == 'nickName'){
                            tempUser.communityNickname = (String) op.value[0].get('value');
                        }

                        // manager / managerId
                        if ((path == 'manager') && (operation == 'remove')) {
                            tempUser.managerId = null;
                        } else if (path == 'manager'){
                            tempUser.managerId = (Id) op.value[0].get('value');
                        }

                        // delegatedApprover / delegatedApproverId
                        if ((path == 'delegatedApprover') && (operation == 'remove')) {
                            tempUser.delegatedApproverId = null;
                        } else if (path == 'delegatedApprover'){
                            tempUser.delegatedApproverId = (Id) op.value[0].get('value');
                        }
                        
                        // active / isActive
                        if ((path == 'active') && (operation == 'remove')) {
                            tempUser.isActive = false;
                        } else if (path == 'active'){
                            tempUser.isActive = (Boolean) op.value[0].get('value');
                        }

                        // roles / userRoleId
                        // roles to use id key
                        if ((path == 'roles') && (operation == 'remove')) {
                            tempUser.userRoleId = null;
                        } else if (path == 'roles'){
                            Integer roleCount = 0;
                            List<String> roleIds = new List<String>();
                            for (Object roleId : (List<Object>) op.value[0].get('id')){
                                roleIds.add((String)roleId);
                                roleCount++;
                            }
                            if (roleCount != 1) {
                                error += 'INVALID:user_must_have_only_one_role;';  
                                res.statusCode = 500;
                                break;
                            } else {
                                tempUser.userRoleId = roleIds[0];
                            }
                        }

                        // groups
                        // expects list of groups to use id key
                        if (path == 'groups') {
                            List<GroupMember> groupsToProcess = new List<GroupMember>();
                            if (op.value.size() != 0) {
                                for (Map<String, Object> vals : (List<Map<String, Object>>) op.value){
                                    GroupMember gm = new GroupMember();
                                    gm.GroupId = (String) vals.get('id');
                                    gm.UserOrGroupId = user.id;
                                    groupsToProcess.add(gm);
                                }
                            } else {
                                 groupsToProcess = [select id from GroupMember where userOrGroupId =: user.id];
                            }
                            if  ((operation == 'remove') || (operation == 'replace')) {
                                // if replace then remove everything and add back what is specified
                                List<GroupMember> currentGroups = [select id, groupId from GroupMember where userOrGroupId =: user.id];
                                delete currentGroups;                                
                            }
                            if ((operation == 'add') || (operation == 'replace')){
								insert groupsToProcess;
                            }
                        }
                        
                        // entitlements
                        // expects list of entitlements to use id key
                        // TODO add support for entitlements in key section
                        if (path == 'entitlements'){
                            List<String> profileToProcess = new List<String>();
                            List<PermissionSetAssignment> permSetsToProcess = new List<PermissionSetAssignment>();                            
                            String tempEntId;
                            if (operation == 'remove'){
                                // cannot remove all entitlements
                                // because you cannot remove profile
                                res.statusCode = 500;
                                error += 'INVALID: Cannot remove all entitlements. Use replace';
                                SCIMException e = new SCIMException();
                                e.setMessage(error);
                                e.setStatusCode(res.statusCode);
                                throw e;
                                
                            }
                            if (op.value.size() != 0) {
                                for (Map<String, Object> vals : (List<Map<String, Object>>) op.value){
                                    tempEntId = (String) vals.get('id');
                                    if (tempEntId.startsWith('00e')) {
                                        profileToProcess.add(tempEntId);
                                    } else if (tempEntId.startsWith('0PS')) {
                                        PermissionSetAssignment psa = new PermissionSetAssignment();
                                        psa.PermissionSetId = tempEntId;
                                        psa.AssigneeId = user.id;
                                        permSetsToProcess.add(psa);
                                    } else {
                                        //bad entitlement id
                                        res.statusCode = 500;
                                        error += 'INVALID entitlement id: ' + tempEntId;
                                        SCIMException e = new SCIMException();
                                        e.setMessage(error);
                                        e.setStatusCode(res.statusCode);
                                        throw e;
                                    }
                                }
                            }
                            
                            if (operation == 'replace'){
                                if (profileToProcess.size() != 0){
                                    if (profileToProcess.size() > 1){
                                        // cannot have multiple profiles
                                        res.statusCode = 500;
                                        error += 'INVALID: cannot have multiple profiles: ' + profileToProcess;
                                        SCIMException e = new SCIMException();
                                        e.setMessage(error);
                                        e.setStatusCode(res.statusCode);
                                        throw e;
                                    } else if (profileToProcess.size() == 1){
                                        tempUser.ProfileId = profileToProcess[0];
                                    }
                                }
                                if (permSetsToProcess.size() !=0){
                                    // delete existing assignments
                                    // then add new ones
                                    List<PermissionSetAssignment> existingPSA = [select id from PermissionSetAssignment where assigneeId = :user.id AND PermissionSet.IsOwnedByProfile = False];
                                    Database.delete(existingPSA);
                                }
                            }
                            
                            if ((operation == 'add') || (operation == 'replace')){
                                if ((profileToProcess.size() !=0) && (operation == 'add')){
                                    // cannot have multiple profiles
                                    res.statusCode = 500;
                                    error += 'INVALID: cannot have multiple profiles: ' + profileToProcess;
                                    SCIMException e = new SCIMException();
                                    e.setMessage(error);
                                    e.setStatusCode(res.statusCode);
                                    throw e;
                                }
								
                                // insert new permSets
                                Database.SaveResult[] newSRs = Database.insert(permSetsToProcess, false);
                                for (Database.SaveResult thisSR : newSRs) {
                                    if (!thisSR.isSuccess()) {
                                        for (Database.Error thisError : thisSR.getErrors()) {
                                            error += 'INVALID:' + thisError.getMessage() + ';';
                                        }
                                        res.statusCode = 400;
                                    }
                                }      
                            }
                        }
                        
                    } else {
                        if (isUnsupported(path)){
                            res.statusCode = 500;
                            error += 'UNSUPPORTED_FIELD: ' + path;
                            SCIMException e = new SCIMException();
                            e.setMessage(error);
                            e.setStatusCode(500);
                            throw e;
                        }
                        
                        if (isReadOnly(path)){
                            res.statusCode = 500;
                            error += 'INVALID: ' + path + ' is read only';
                            SCIMException e = new SCIMException();
                            e.setMessage(error);
                            e.setStatusCode(500);
                            throw e;
                        }
                        
                    }
                }
/*                
                // email
                // this likely wont work if email is sent in the value
                // and not via path
                if (op.path == 'email'){
                    if (operation == 'remove'){
                        tempUser.email = '';
                    } else {
                        tempUser.email = (String) op.value[0].get('value');                        
                    }
                } else if (op.path == null){
                    // in case there isnt a path check the values for the attr
                    for (Map<String, Object> val : op.value){
                        if (val.keySet().contains('email')){
                            tempUser.email = (String) val.get('email');                        
                        }
                    }
                }
*/                                
                    //tempUser = Database.query('select id, ' + attrQueryStr.left(attrQueryStr.length() - 2) + ' FROM User WHERE id = \'' + user.id + '\' limit 1');
                
                if (res.statusCode == 201){
                    update tempUser;                    
                } else {
                    SCIMException e = new SCIMException();
                    e.setMessage(error);
					e.setStatusCode(res.statusCode);
                    throw e;
                }

            }
        } catch (SCIMException e) {
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = e.getStatusCode();
            if (res.statusCode == null) {
                res.statusCode = 500;
            } 
            res.responseBody = ScimError.serializeError(res.statusCode, e.getMessage(), req.headers.containsKey('X-Prettyprint'));
			Database.rollback(sp);
            return;
        }
    }
}