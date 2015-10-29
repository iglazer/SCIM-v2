@RestResource(urlMapping='/v2/Roles/*')
global class RoleResource extends ScimResource {

    @HttpDelete
    global static void doDelete() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;  
        
        UserRole[] r = Database.query('select id from userrole where id=\'' + uriParts[numParts] + '\'');
        if(r.size() == 1) {
        	delete r[0];
        } else {
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
            return;
        }
    }    
    
    public static void serializeRoleWithGenerator(List<UserRole> roles, String attributes, String host, JSONGenerator gen) {
        serializeRoleWithGenerator(roles, attributes, host, gen, 200, 0);
    }
    
    public static void serializeRoleWithGenerator(List<UserRole> roles, String attributes, String host, JSONGenerator gen, Integer membersLimit, Integer membersOffset) {
        Map<Id, List<User>> rmMap = new Map<Id, List<User>>();
        if (shouldSerialize('members', attributes)) {
            for (User u : [select id, UserRoleId from User where UserRoleId = :roles LIMIT :membersLimit OFFSET :membersOffset]){
                List<User> usersWithRole = rmMap.get(u.UserRoleId);
                if (usersWithRole == null) {
                    usersWithRole = new List<User>();
                    rmMap.put(u.UserRoleId, usersWithRole);
                }
                usersWithRole.add(u);
            }
            
        }
        
        String scimRef = host + '/services/apexrest/v2/';
        for (UserRole r : roles) {
            gen.writeStartObject();
                gen.writeFieldName('schemas');
                gen.writeStartArray();
                    gen.writeString('urn:salesforce:schemas:extension:1.0:Role');
                gen.writeEndArray();
                gen.writeStringField('id', r.id);            
                if (shouldSerialize('displayName', attributes)) {
                    gen.writeStringField('displayName', r.name);
                }
                
                if (shouldSerialize('members', attributes)) {
                    gen.writeFieldName('members');
                    gen.writeStartArray();
                        List<User> users = rmMap.get(r.id);
                        if (users != null) {
                            for (User user : users) {
                                gen.writeStartObject();
                                    gen.writeStringField('value', user.id);  
                                    gen.writeStringField('$ref', 'https://' + scimref + 'Users/' + user.id);
                                gen.writeEndObject();
                            } 
                        }  
                    gen.writeEndArray();
                }
                
                if (shouldSerialize('meta', attributes)) {
                    gen.writeFieldName('meta');
                        gen.writeStartObject();
                            String lastmodFormated = r.LastModifiedDate.format('yyyy-MM-dd');
                            lastmodFormated += 'T';
                            lastmodFormated += r.LastModifiedDate.formatGmt('hh:mm:ss');
                            gen.writeStringField('lastModified', lastmodFormated + 'Z');
                            
                            String base = URL.getSalesforceBaseUrl().toExternalForm();
                            String path = '/services/apexrest/v2/Roles/' + r.id;
                            gen.writeStringField('location', base + path);
                            
                            Blob digest = Crypto.generateDigest('SHA-1',  Blob.valueOf(user.id + lastmodFormated));
                            gen.writeStringField('version', EncodingUtil.convertToHex(digest));                                        
                        gen.writeEndObject();
                }
            gen.writeEndObject();    
        }   
    }    
    
    public static boolean shouldSerialize(String attributeName, String attributes) {
        return ScimResource.shouldSerialize(attributeName, attributes, RolesResource.scimNameToRoleSObjectNameMap);
    }  

    
    global static void doGet(String id, String attributes, boolean isPost) {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        
        String membersCount = req.params.get('members.count');
        String membersStartIndex = req.params.get('members.startIndex');
                
        try {
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
        
        
            String host = req.headers.get('Host');
            // problem query here
            QueryHolder roleQueryHolder = FilterTranslator.buildAttributeQueryString(attributes, 'id eq \"' + id + '\"', null, null, RolesResource.scimNameToRoleSObjectNameMap, 'UserRole', ' (Id != NULL) ', null, null);
            String actualSoql = roleQueryHolder.getActualQuery();
            List<UserRole> roles = Database.query(actualSoql);
            
            if ( !roles.isEmpty()  ) {
                res.statusCode = 200;
                if(isPost){
                    res.statusCode = 201; 
                }
                Boolean isPrettyPrint = req.headers.containsKey('X-Prettyprint');
                JSONGenerator gen = JSON.createGenerator(isPrettyPrint);
                serializeRoleWithGenerator(roles, attributes, host, gen, membersLimit, membersOffset);      
                res.responseBody =  Blob.valueOf(gen.getAsString());
            } else {
                res.statusCode = 404;
                res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Roles/' + id + ' not found', req.headers.containsKey('X-Prettyprint'));
            }    
        }  
        catch (ScimException ex) {
            res.statusCode = 400;
            res.responseBody = SCIMError.serializeError(res.statusCode, ex.getMessage(), req.headers.containsKey('X-Prettyprint'));
            return;
        }     
    }

    @HttpGet
    global static void doGet() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        
        String attributes = req.params.get('attributes');
        if (attributes != null) {
            attributes = attributes.replaceAll(' ', '');
        } 
        
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;   
        if (numParts >= 4) { 
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
        } else {
            doGet(uriParts[numParts], attributes, false);   
        }
    }
}