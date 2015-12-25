public class SCIMPatchParser {
    public List<String> schemas;
	public List<Operation> Operations;

    public class Operation {
        public String op;
        public String path;
        public List<Map<String, Object>> value;
    }    
    public SCIMPatchParser(String json){
        Map<String,Object> parsed = (Map<String, Object>)System.JSON.deserializeUntyped(json);
        List<Object> schemasObj = (List<Object>)parsed.get('schemas');
        List<Object> operationsObj = (List<Object>)parsed.get('Operations');
		
        schemas = new List<String>();
        Operations = new List<Operation>();       
        for (Object val : schemasObj){
			schemas.add((String) val);
        }

        for (Object val : (List<Object>)operationsObj) {
            Operation tempOp = new Operation();
			Map<String, Object> tempObj = (Map<String, Object>) val;
			tempOp.op = (String)tempObj.get('op');
			tempOp.value = new List<Map<String, Object>>();
            for (Object v : (List<Object>)tempObj.get('value')){
                Map<String, Object> tempValues = (Map<String, Object>) v;
                tempOp.value.add(tempValues);
            }
            
            if (tempObj.get('path') != null){
                tempOp.path = (String)tempObj.get('path');
            }
            operations.add(tempOp);
        }   
    }
}