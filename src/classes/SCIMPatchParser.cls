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

            if (tempObj.get('path') != null){
                tempOp.path = (String)tempObj.get('path');
                Map<String, Object> tempV = new Map<String, Object>{'value' => tempObj.get('value')}; 
                tempOp.value.add(tempV);
            } else {
                List<Map<String, Object>> foo1 = (List<Map<String, Object>>)tempObj.get('value');
                for (Map<string, Object> f : foo1){
                    System.debug('listf: ' + f);
                }
/*
                for (String o1 : foo1.keySet()){
                   // tempOp.value.add(new Map<String, Object>{o1 => foo1.get(o1)});
                   System.debug('O1: '+ o1);
                }
*/
            }                      
            operations.add(tempOp);
        }
    }
}