public class ScimError {
    public static Blob serializeError(Integer statusCode, String e, boolean prettyPrint) {
        JSONGenerator gen = JSON.createGenerator(prettyPrint);
        gen.writeStartObject();
            gen.writeFieldName('Errors');
            gen.writeStartArray();
                gen.writeStartObject();
                    gen.writeStringField('description', e);
                    gen.writeNumberField('code', statusCode);
                gen.writeEndObject();
            gen.writeEndArray();
        gen.writeEndObject();
        return Blob.valueOf(gen.getAsString());
    }
}