@RestResource(urlMapping='/v2/Entitlements/*')
global class EntitlementResource extends ScimResource {
    
	@HttpPut   
	global static void doPut() {
		RestRequest req = RestContext.request;
		RestResponse res = RestContext.response;
		res.statusCode = 501;
        res.responseBody = SCIMError.serializeError(res.statusCode, 'Method not supported', req.headers.containsKey('X-Prettyprint'));
    	return;
    }
    
    @HttpDelete
	global static void doDelete() {
		RestRequest req = RestContext.request;
		RestResponse res = RestContext.response;
		res.statusCode = 501;
        res.responseBody = SCIMError.serializeError(res.statusCode, 'Method not supported', req.headers.containsKey('X-Prettyprint'));
    	return;
    }
    
    @HttpPatch
    global static void doPatch() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;
        
        Boolean isFound = false;
        String entitlementId = uriParts[numParts];
        if (entitlementId.startsWith('00e')) {
            isFound = !([select ID from Profile where ID = :entitlementId].isEmpty());
        }
        else if (entitlementId.startsWith('0PS')) {
            isFound = !([select ID from PermissionSet where ID = :entitlementId].isEmpty());
        }
        
        if (numParts >= 4 || !isFound) { 
            res.statusCode = 404;
            res.addHeader('Content-Type', 'application/json');
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
            return;
        }        
        
        Savepoint sp = Database.setSavepoint();
        try {
	        if (entitlementId.startsWith('0PS')) {
	            // PermissionSets
	            System.JSONParser psParser = System.JSON.createParser(req.requestBody.toString());
	            entitlementId = doUpdatePermissionSet(entitlementId, psParser);
	        }
	        else {
	            System.JSONParser parser = System.JSON.createParser(req.requestBody.toString());
	            List<Map<String,String>> members;
	            while (parser.nextToken() != null) {
	                if ((parser.getCurrentToken() == JSONToken.FIELD_NAME) && (parser.getText() == 'members')) {    
	                    members = ScimResource.parseObjectArray('members', parser);                            
	                }
	            }
	            if ( members != null ) {
	                for ( Map<String,String> member : members ) {
	                    String userid;
	                    if (member.containsKey('value')) userid = member.get('value');
	                    if (userid != null) {
	                        // TODO: bulk this
	                        List<User> users = [Select ID from User where Id = :userid];
	                        if (users.size() == 0) {
	                        	throw new ScimException('Invalid: user ID is invalid ' + userid);
	                        }
	                        User user = users.get(0);
	                        if (entitlementId.startsWith('00e')) {
	                            // Profiles
	                            // Note: profile has no meaningful semantics for operation:delete or meta:attributes:members
	                            // since a user cannot have no profile.
	                            // we ignore such requests.
	                            user.ProfileId = uriParts[numParts];
	                            update user;
	                        }
	                    } 
	                }
	            }
	        }
	        
	        // retrieve self
	        if (entitlementId != null) {
	            doGet();
	        }
        }
        catch (Exception e) {
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 500;
            res.responseBody = ScimError.serializeError(res.statusCode, e.getMessage(), req.headers.containsKey('X-Prettyprint'));
            Database.rollback(sp);  
        }
    }
    
    public static Id doUpdatePermissionSet(String permsetId, System.JSONParser parser) {
        List<Map<String,String>> members;
        List<String> attributes;
        String displayName;
        
        Savepoint sp = Database.setSavepoint();
        try {
            if (permsetId != null && [select id from PermissionSet where id = :permsetId].size() == 0) {
                throw new ScimException('PermissionSet ' + permsetId + ' not found');
            }
        
            while (parser.nextToken() != null) {
                if (ScimResource.isNextTokenField(parser, 'members')) {    
                    members = ScimResource.parseObjectArray('members', parser);                            
                }
                if (ScimResource.isNextTokenField(parser, 'displayName')) {    
                    displayName = ScimResource.parseString('displayName', parser);                            
                }
                if (ScimResource.isNextTokenField(parser, 'meta')) {    
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
            
            if (permsetId == null) {
                throw new ScimException('No PermissionSet specified');
            }
            
            // The meta operations are per the spec
            // They are quite unrestful
            
            if (attributes != null) {
                for (String attribute : attributes) {
                    if ('members'.equals(attribute)) {
                        // A meta attribute with an attributes array that contains a members value
                        // Per spec this means removing all members
                        List<PermissionSetAssignment> psas = [Select Id from PermissionSetAssignment where PermissionSetId = :permsetId];
                        Database.delete(psas, true);
                    }
                }
            } 
            
            if ( members != null ) {
                for ( Map<String,String> member : members ) {
                    String userId;
                    if (member.containsKey('value')) userId = member.get('value');
                    String operation = member.get('operation');
                    if ('delete'.equals(operation)) {
                        // delete if there
                        List<PermissionSetAssignment> thisPsa = [Select Id from PermissionSetAssignment where PermissionSetId = :permsetId AND AssigneeId = :userId];
                        if (!thisPsa.isEmpty()) {
                            Database.delete(thisPsa, true);
                        }                    
                    }
                    else {
                        // add if not there
                        if (userId != null) {
                            List<PermissionSetAssignment> thisPsa = [Select Id from PermissionSetAssignment where PermissionSetId = :permsetId AND AssigneeId = :userId];
                            if (thisPsa.isEmpty()) {
                                PermissionSetAssignment newPsa = new PermissionSetAssignment();
                                newPsa.assigneeId = userId;
                                newPsa.permissionSetId = permsetId;
                                insert newPsa;
                            }
                        } 
                    }
                }
            }  
            return permsetId;
        }
        catch (Exception e) {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 500;
            res.responseBody = ScimError.serializeError(res.statusCode, e.getMessage(), req.headers.containsKey('X-Prettyprint'));
            Database.rollback(sp);  
            return null;
        }  
    }    

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String attributes = req.params.get('attributes');
        
        String membersCount = req.params.get('members.count');
        String membersStartIndex = req.params.get('members.startIndex');
        if (attributes != null) {
            attributes = attributes.replaceAll(' ', '');
        }
        
        try{
            Integer membersLimit = 200;
            if (membersCount != null) {
                FilterTranslator.validateCount(membersCount);
                membersLimit = Integer.valueof(membersCount);
            }
            
            Integer membersOffset = 0;
            if (membersStartIndex != null) {
                FilterTranslator.validateStartIndex(membersStartIndex);
                membersOffset = Integer.valueof(membersStartIndex) - 1;
            }
            else {
                membersOffset = 0;
            }
        
            res.addHeader('Content-Type', 'application/json');
            String host = req.headers.get('Host');
            String[] uriParts = req.requestURI.split('/',0);
            Integer numParts = uriParts.size() - 1;   
            
            if (numParts >= 4) { 
                res.statusCode = 404;
                res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
            } else {
                List<User> users = new List<User>();
                String entitlementId = uriParts[numParts];
                if (entitlementId.startsWith('00e')) {
                    QueryHolder profileQueryHolder = FilterTranslator.buildAttributeQueryString(attributes, 'id eq \"' + entitlementId + '\"', null, null, EntitlementsResource.scimNameToProfileSObjectNameMap, 'Profile', ' (Id != NULL) ' , null, null);
                    List<Profile> profiles = Database.query(profileQueryHolder.getActualQuery());
                    if ( !profiles.isEmpty()  ) {
                        users = [ select Id, Name, ProfileId, Profile.Name, isActive from User where isActive = true and ProfileId = :uriParts[numParts] LIMIT :membersLimit OFFSET :membersOffset];
                        List<UserIdNamePair> userIdNamePair = new List<UserIdNamePair>();
                        if (!users.isEmpty()) {
                            for (User user : users) {
                                userIdNamePair.add(new UserIdNamePair(user.id, user.Name));
                            }                        
                        }
                        res.statusCode = 200; 
                        res.responseBody = serializeEntitlement(profiles.get(0).Id, profiles.get(0), attributes, userIdNamePair, req.headers.containsKey('X-Prettyprint'));
                    }
                    else {
                        res.statusCode = 404;
                        res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Entitlements/' + uriParts[numParts] + ' not found', req.headers.containsKey('X-Prettyprint'));
                    }
                }
                else if (entitlementId.startsWith('0PS')) {
                    QueryHolder permsetQueryHolder = FilterTranslator.buildAttributeQueryString(attributes, 'id eq \"' + entitlementId + '\"', null, null, EntitlementsResource.scimNameToPermsetSObjectNameMap, 'PermissionSet', ' (IsOwnedByProfile = false) ' , null, null); 
                    List<PermissionSet> permsets = Database.query(permsetQueryHolder.getActualQuery());
                    if ( !permsets.isEmpty()  ) {
                        List<PermissionSetAssignment> psas = [select AssigneeId from permissionsetassignment where permissionsetid = :permsets.get(0).Id LIMIT :membersLimit OFFSET :membersOffset];
                        List<Id> ids = new List<Id>();
                        for (PermissionSetAssignment thisPsa : psas) {
                            ids.add(thisPsa.assigneeId);
                        }
                        List<UserIdNamePair> userIdNamePair = new List<UserIdNamePair>();
                        if ( !psas.isEmpty()) {
                            users = [select Id, Name from User where isActive = true and Id IN :ids];
                            for (User user : users) {
                                userIdNamePair.add(new UserIdNamePair(user.id, user.Name));
                            }
                        }  
                        res.statusCode = 200; 
                        res.responseBody = serializeEntitlement(permsets.get(0).Id, permsets.get(0), attributes, userIdNamePair, req.headers.containsKey('X-Prettyprint'));
                    }
                    else {
                        res.statusCode = 404;
                        res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Entitlements/' + uriParts[numParts] + ' not found', req.headers.containsKey('X-Prettyprint'));
                    }
                }
                else {
                    res.statusCode = 404;
                    res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Entitlements/' + uriParts[numParts] + ' not found', req.headers.containsKey('X-Prettyprint'));
                }  
            }       
        }
        catch (ScimException ex) {
            res.statusCode = 400;
            res.responseBody = SCIMError.serializeError(res.statusCode, ex.getMessage(), req.headers.containsKey('X-Prettyprint'));
            return;
        }           
    }
    
    public static boolean shouldSerialize(String id, String attributeName, String attributes) {
        if (id.startsWith('00e')) {
            return ScimResource.shouldSerialize(attributeName, attributes, EntitlementsResource.scimNameToProfileSObjectNameMap);
        }
        else if (id.startsWith('0PS')) {
            return ScimResource.shouldSerialize(attributeName, attributes, EntitlementsResource.scimNameToPermsetSObjectNameMap);
        }
        else {
            return false; // makes no sense just do not serialize
        }
    }      
    
    public static Blob serializeEntitlement(String id, SObject entitlement, String attributes, List<UserIdNamePair> users, boolean prettyPrint) {
        JSONGenerator gen = JSON.createGenerator(prettyPrint);
        serializeEntitlementWithGenerator(id, entitlement, attributes, users, gen);
        return Blob.valueOf(gen.getAsString());
    }      
    
    public class UserIdNamePair {
        private Id id;
        private String name;
        
        public UserIdNamePair(Id id, String name) {
            this.id = id;
            this.name = name;
        }
        
        public String getName() {
            return name;
        }
        
        public Id getId() {
            return id;
        }
    
        public void setName(String name) {
            this.name = name;
        }
        
        public void setId(Id id) {
            this.id = id;
        }
    }
    
    public static void serializeEntitlementWithGenerator(String id, SObject entitlement, String attributes, List<UserIdNamePair> users, JSONGenerator gen) {
	        String base = URL.getSalesforceBaseUrl().toExternalForm();
        
        	gen.writeStartObject();
            gen.writeFieldName('schemas');
            gen.writeStartArray();
                gen.writeString('urn:salesforce:schemas:extension:1.0:Entitlement');
            gen.writeEndArray();
            gen.writeStringField('id', id);
            if (shouldSerialize(id, 'displayName', attributes)) {
                gen.writeStringField('displayName', (String) entitlement.get('Name'));
            }
            if (id.startsWith('00e')){
                gen.writeStringField('type', 'Profile');
            } else {
                gen.writeStringField('type', 'Permission Set');
            }
            if (shouldSerialize(id, 'members', attributes)) {
                gen.writeFieldName('members');
                gen.writeStartArray();
                String userId;
                    if (users != null) {
                        for ( UserIdNamePair user : users ) {
                            userId = user.getId();
                            gen.writeStartObject();
                                gen.writeStringField('value', userId);
                                gen.writeStringField('display', user.getName());
                            	gen.writeStringField('$ref', base + '/services/apexrest/v2/Users/' + userId);
                            gen.writeEndObject();        
                        }
                    }
                gen.writeEndArray();
            }
            
            if (shouldSerialize(id, 'meta', attributes)) {
                gen.writeFieldName('meta');
                    gen.writeStartObject();
                        String createdFormated = ((Datetime) entitlement.get('CreatedDate')).format('yyyy-MM-dd');
                        createdFormated += 'T';
                        createdFormated += ((Datetime) entitlement.get('CreatedDate')).formatGmt('hh:mm:ss');
                        gen.writeStringField('created', createdFormated + 'Z');
                        
                        String lastmodFormated = ((Datetime) entitlement.get('LastModifiedDate')).format('yyyy-MM-dd');
                        lastmodFormated += 'T';
                        lastmodFormated += ((Datetime) entitlement.get('LastModifiedDate')).formatGmt('hh:mm:ss');
                        gen.writeStringField('lastModified', lastmodFormated + 'Z');
                        
                        String path = '/services/apexrest/v2/Entitlements/' + id;
                        gen.writeStringField('location', base + path);
                            
                        Blob digest = Crypto.generateDigest('SHA-1',  Blob.valueOf(user.id + lastmodFormated));
                        gen.writeStringField('version', EncodingUtil.convertToHex(digest));
                gen.writeEndObject();
            }            
            
        gen.writeEndObject();        
}
}