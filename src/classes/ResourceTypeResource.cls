@RestResource(urlMapping='/v2/ResourceTypes')
global class ResourceTypeResource {
    
    @HttpGet
    global static void doGet() {
        
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');
        res.statusCode = 200; 
        res.responseBody = serializeConfigs(req.headers.containsKey('X-Prettyprint'));
        
    }  
    
    public static Blob serializeConfigs(boolean prettyPrint) {
    
        JSONGenerator gen = JSON.createGenerator(prettyPrint);
            gen.writeStartObject();
                gen.writeStringField('totalResults', '4');
                gen.writeStringField('itemsPerPage', '4');
                gen.writeStringField('startIndex', '1');
                gen.writeFieldName('schemas');
                gen.writeStartArray();
                    gen.writeString('urn:ietf:params:scim:api:messages:2.0:ListResponse');
                gen.writeEndArray();
                gen.writeFieldName('Resources');
                gen.writeStartArray();
				
        		//User
        		gen.writeStartObject();
        			gen.writeStringField('id', 'urn:ietf:params:scim:schemas:core:2.0:User');
        			gen.writeStringField('name', 'Users');
        			gen.writeStringField('description', 'Resource type for Users. Users are thinsg that can login.');
        			gen.writeStringField('endpoint', '/Users');
        			gen.writeStringField('schema', 'urn:ietf:params:scim:schemas:core:2.0:User');
        			gen.writeFieldName('schemaExtensions');
        			gen.writeStartArray();
        				gen.writeStartObject();
        					gen.writeStringField('schema', 'urn:salesforce:schemas:extension:' + UserInfo.getOrganizationId());
                            gen.writeStringField('required', 'false');
       					gen.writeEndObject();
        				gen.writeStartObject();
        					gen.writeStringField('schema', 'urn:salesforce:schemas:extension:external:1.0');
                            gen.writeStringField('required', 'false');
       					gen.writeEndObject();
        			gen.writeEndArray();
        		gen.writeEndObject();

        		//Group
        		gen.writeStartObject();
        			gen.writeStringField('id', 'urn:ietf:params:scim:schemas:core:2.0:Group');
        			gen.writeStringField('name', 'Groups');
        			gen.writeStringField('description', 'Resource type for Groups. Group govern some access and sharing.');
        			gen.writeStringField('endpoint', '/Groups');
        			gen.writeStringField('schema', 'urn:ietf:params:scim:schemas:core:2.0:Group');
        		gen.writeEndObject();

        		//Entitlement
        		gen.writeStartObject();
        			gen.writeStringField('id', 'urn:salesforce:schemas:extension:1.0:Entitlement');
        			gen.writeStringField('name', 'Entitlements');
        			gen.writeStringField('description', 'Resource type for Entitlements. Entitlements including Profiles and Permission Sets.');
        			gen.writeStringField('endpoint', '/Entitlements');
        			gen.writeStringField('schema', 'urn:salesforce:schemas:extension:1.0:Entitlement');
        		gen.writeEndObject();

        		//Role
        		gen.writeStartObject();
        			gen.writeStringField('id', 'urn:salesforce:schemas:extension:1.0:Role');
        			gen.writeStringField('name', 'Roles');
        			gen.writeStringField('description', 'Resource type for Roles. Roles can control sharing.');
        			gen.writeStringField('endpoint', '/Roles');
        			gen.writeStringField('schema', 'urn:salesforce:schemas:extension:1.0:Role');
        		gen.writeEndObject();
        
        
        gen.writeEndArray();




        gen.writeFieldName('meta');
            gen.writeStartObject();
                String base = URL.getSalesforceBaseUrl().toExternalForm();               
                String path = '/services/apexrest/v2/ResourceTypes/';
        		String fullPath = base + path;
                gen.writeStringField('location', fullPath);
  
                
                Blob digest = Crypto.generateDigest('SHA-1',  Blob.valueOf(fullPath));
                gen.writeStringField('version', EncodingUtil.convertToHex(digest));
        gen.writeEndObject();
        gen.writeEndObject();                
        return Blob.valueOf(gen.getAsString());
    
    }
    
    


}