@RestResource(urlMapping='/v2/Groups/*')
global class GroupResource extends ScimResource {

    @HttpDelete
    global static void doDelete() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;  
        
        Group[] g = Database.query('select id from group where id=\'' + uriParts[numParts] + '\'');
        if(g.size() == 1) {
        	delete g[0];
            res.statusCode = 204;
        } else {
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
            return;
        }
    }    

    @HttpPut
    global static void doPut() {

        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;   
        
        if (numParts >= 4) { 
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
            return;
        }                
        
        // put means we clear all the members whatsoever and then upsert
        String groupId = uriParts[numParts];
        List<GroupMember> groupMembers = [Select Id from GroupMember where GroupId = :groupId];
        Database.delete(groupMembers, true);

		doUpsert(groupId, System.JSON.createParser(req.requestBody.toString()));

    }

    @HttpPatch
    global static void doPatch() {
    
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String[] uriParts = req.requestURI.split('/',0);
        Integer numParts = uriParts.size() - 1;   
        
        if (numParts >= 4  || [select id from group where id = :uriParts[numParts]].size()==0){ 
            res.statusCode = 404;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'No such resource.', req.headers.containsKey('X-Prettyprint'));
            return;
        }
		
        String groupId = uriParts[numParts];
		GroupPatchParser groupPP = GroupPatchParser.parse(req.requestBody.toString());
		
        String schema = groupPP.schemas.get(0);
        if (!schema.equals('urn:ietf:params:scim:api:messages:2.0:PatchOp')){
            res.statusCode = 400;
            res.responseBody = SCIMError.serializeError(res.statusCode, 'Improper Schema.', req.headers.containsKey('X-Prettyprint'));
            return;
        }
        
        List<String> membersToBeAdded = new List<String>();
        List<String> membersToBeRemoved = new List<String>();
        for (GroupPatchParser.Operations op : groupPP.Operations){
            System.debug(groupPP.Operations);
            if (op.op == 'add' || op.op == 'replaced'){
                //add to list to be upserted
                for (GroupPatchParser.Value v : op.value){
                    membersToBeAdded.add(v.value);
                }
            } else if (op.op == 'delete'){
                //add to list to be deleted
                for (GroupPatchParser.Value v : op.value){
                    membersToBeRemoved.add(v.value);
                }
            }
        }
        
        if (!membersToBeAdded.isEmpty()){
            for (String member : membersToBeAdded){
                GroupMember newGroupMember = new GroupMember();
                newGroupMember.GroupId = groupId;
                newGroupMember.UserOrGroupId = member;
                insert newGroupMember;
            }
        }
		
        if (!membersToBeRemoved.isEmpty()){
            for (String member : membersToBeRemoved){
                List<GroupMember> groupMember = [Select Id from GroupMember where GroupId = :groupId AND UserOrGroupId = :member];
                if (!groupMember.isEmpty()) {
                    Database.delete(groupMember, true);
                }                                    
            }            
        }        

        if (groupId != null) {
            // retrieve self
            doGet(groupId, null, false);
        }
        
/*                
        Id groupId = doUpsert(uriParts[numParts], parser);
*/
    }

    
    
    public static Id doUpsert(String groupId, System.JSONParser parser) {
        
        List<Map<String,String>> members;
        List<String> attributes;
        String displayName;
        
        try {
            if (groupId != null && [select id from group where id = :groupId].size() == 0) {
                throw new ScimException('Group ' + groupId + ' not found');
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
            
            if (groupId == null) {
                Group g = new Group();
                g.Name = displayName;
                insert g;
                groupId = g.Id;
            }
            else {
                Group g = [Select Id, Name from Group where Id = :groupId];
                if (!g.Name.equals(displayName)) {
                    g.Name = displayName;
                    update g;
                }
            }
            
            // The meta operations are per the spec
            // They are quite unrestful
            
            if (attributes != null) {
                for (String attribute : attributes) {
                    if ('members'.equals(attribute)) {
                        // A meta attribute with an attributes array that contains a members value
                        // Per spec this means removing all members
                        List<GroupMember> groupMembers = [Select Id from GroupMember where GroupId = :groupId];
                        Database.delete(groupMembers, true);
                    }
                }
            } 
            
            if ( members != null ) {
                for ( Map<String,String> member : members ) {
                    String userOrGroupId;
                    if (member.containsKey('value')) userOrGroupId = member.get('value');
                    String operation = member.get('operation');
                    if ('delete'.equals(operation)) {
                        // delete if there
                        List<GroupMember> groupMember = [Select Id from GroupMember where GroupId = :groupId AND UserOrGroupId = :userOrGroupId];
                        if (!groupMember.isEmpty()) {
                            Database.delete(groupMember, true);
                        }                    
                    }
                    else {
                        // add if not there
                        if (userOrGroupId != null) {
                            List<GroupMember> groupMember = [Select Id from GroupMember where GroupId = :groupId AND UserOrGroupId = :userOrGroupId];
                            if (groupMember.isEmpty()) {
                                GroupMember newGroupMember = new GroupMember();
                                newGroupMember.groupId = groupId;
                                newGroupMember.UserOrGroupId = userOrGroupId;
                                insert newGroupMember;
                            }
                        } 
                    }
                }
            }  
            return groupId;
        }
        catch (Exception e) {
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            res.addHeader('Content-Type', 'application/json');
            res.statusCode = 500;
            res.responseBody = ScimError.serializeError(res.statusCode, e.getMessage(), req.headers.containsKey('X-Prettyprint'));  
            return null;      
        }  
    }
    
    public static void serializeGroupWithGenerator(List<Group> groups, String attributes, String host, JSONGenerator gen) {
        serializeGroupWithGenerator(groups, attributes, host, gen, 200, 0);
    }
    
    public static void serializeGroupWithGenerator(List<Group> groups, String attributes, String host, JSONGenerator gen, Integer membersLimit, Integer membersOffset) {
        Map<Id, List<GroupMember>> gmMap = new Map<Id, List<GroupMember>>();
        if (shouldSerialize('members', attributes)) {
            for (GroupMember gm : [select GroupId, UserOrGroupId from GroupMember where GroupId in :groups LIMIT :membersLimit OFFSET :membersOffset]) {
                Id groupId = gm.GroupId;
                List<GroupMember> gms = gmMap.get(groupId);
                if (gms == null) {
                    gms = new List<GroupMember>();
                    gmMap.put(groupId, gms);
                }
                gms.add(gm);
            }            
        }
        
        String scimRef = host + '/services/apexrest/v2/';
        for (Group g : groups) {
            gen.writeStartObject();
                gen.writeFieldName('schemas');
                gen.writeStartArray();
                    gen.writeString('urn:ietf:params:scim:schemas:core:2.0:Group');
                gen.writeEndArray();
                gen.writeStringField('id', g.id);            
                if (shouldSerialize('displayName', attributes)) {
                    gen.writeStringField('displayName', g.name);
                }
                
                if (shouldSerialize('members', attributes)) {
                    gen.writeFieldName('members');
                    gen.writeStartArray();
                        List<GroupMember> members = gmMap.get(g.id);
                        if (members != null) {
                            for (GroupMember member : members) {
                                gen.writeStartObject();
                                    gen.writeStringField('value', member.UserOrGroupId);  
                                    String strId = member.UserOrGroupId;
                                    if ( strId.startsWith('005') ) {
                                        gen.writeStringField('type', 'User');
                                        gen.writeStringField('$ref', 'https://' + scimref + 'Users/' + member.UserOrGroupId);
                                    } else {
                                        gen.writeStringField('type', 'Group');
                                        gen.writeStringField('$ref', 'https://' + scimref + 'Groups/' + member.UserOrGroupId);
                                    }
                                gen.writeEndObject();
                            } 
                        }  
                    gen.writeEndArray();
                }
                
                if (shouldSerialize('meta', attributes)) {
                    gen.writeFieldName('meta');
                        gen.writeStartObject();
                            String createdFormated = g.CreatedDate.format('yyyy-MM-dd');
                            createdFormated += 'T';
                            createdFormated += g.CreatedDate.formatGmt('hh:mm:ss');
                            gen.writeStringField('created', createdFormated + 'Z');
                            
                            String lastmodFormated = g.LastModifiedDate.format('yyyy-MM-dd');
                            lastmodFormated += 'T';
                            lastmodFormated += g.LastModifiedDate.formatGmt('hh:mm:ss');
                            gen.writeStringField('lastModified', lastmodFormated + 'Z');
                            
                            String base = URL.getSalesforceBaseUrl().toExternalForm();
                            String path = '/services/apexrest/v2/Groups/' + g.id;
                            gen.writeStringField('location', base + path);
                            
                            Blob digest = Crypto.generateDigest('SHA-1',  Blob.valueOf(user.id + lastmodFormated));
                            gen.writeStringField('version', EncodingUtil.convertToHex(digest));                                        
                        gen.writeEndObject();
                }
            gen.writeEndObject();    
        }   
    }    
    
    public static boolean shouldSerialize(String attributeName, String attributes) {
        return ScimResource.shouldSerialize(attributeName, attributes, GroupsResource.scimNameToGroupSObjectNameMap);
    }  

    @HttpPost
    global static void doPost() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        String method = req.headers.get('X-HTTP-Method-Override');
        if ( method == null ) method = 'POST';
        if ( method.equals('DELETE') ) {
            doDelete(); 
        } else {
            System.JSONParser parser = System.JSON.createParser(req.requestBody.toString());
            Id groupId = doUpsert(null, parser);
            if (groupId != null) {
                // retrieve self
                doGet(groupId, null, true);
            }
        }
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
            QueryHolder groupQueryHolder = FilterTranslator.buildAttributeQueryString(attributes, 'id eq \"' + id + '\"', null, null, GroupsResource.scimNameToGroupSObjectNameMap, 'Group', ' Type = \'Regular\' ', null, null);
            String actualSoql = groupQueryHolder.getActualQuery();
            List<Group> groups = Database.query(actualSoql);
            
            if ( !groups.isEmpty()  ) {
                res.statusCode = 200;
                if(isPost){
                    res.statusCode = 201; 
                }
                Boolean isPrettyPrint = req.headers.containsKey('X-Prettyprint');
                JSONGenerator gen = JSON.createGenerator(isPrettyPrint);
                serializeGroupWithGenerator(groups, attributes, host, gen, membersLimit, membersOffset);      
                res.responseBody =  Blob.valueOf(gen.getAsString());
            } else {
                res.statusCode = 404;
                res.responseBody = SCIMError.serializeError(res.statusCode, 'Resource https://' + host + '/services/apexrest/v2/Groups/' + id + ' not found', req.headers.containsKey('X-Prettyprint'));
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