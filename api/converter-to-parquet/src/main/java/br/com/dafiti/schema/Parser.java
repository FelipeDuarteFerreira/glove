/*
 * Copyright (c) 2019 Dafiti Group
 * 
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 * 
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 * 
 */
package br.com.dafiti.schema;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import org.apache.avro.Schema;
import org.apache.log4j.Logger;
import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Schema parser.
 *
 * @author Valdiney V GOMES
 */
public class Parser {

    private final File schemaFile;

    /**
     * Constructor.
     *
     * @param schemaFile Schema file.
     */
    public Parser(File schemaFile) {
        this.schemaFile = schemaFile;
    }

    /**
     * Get schema from parquet file.
     *
     * @return Avro schema.
     * @throws java.io.IOException
     */
    public Schema getAvroSchema() throws IOException {
        StringBuilder schema = new StringBuilder();
        String line;

        //Read the schema file.
        BufferedReader buffer = new BufferedReader(new FileReader(schemaFile));

        //Insert schema header.
        schema.append("{");
        schema.append("\"type\": \"record\",");
        schema.append("\"name\": \"model\",");
        schema.append("\"fields\":");

        //Insert schema fields.
        while ((line = buffer.readLine()) != null) {
            schema.append(line);
        }

        //Insert schema footer.
        schema.append("}");

        //Convert the schema to json.
        JSONObject jsonSchema = new JSONObject(schema.toString());

        //Get field list.
        JSONArray fields = jsonSchema.getJSONArray("fields");

        //Adjusts field attributes if necessary.
        for (int i = 0; i < fields.length(); i++) {
            JSONObject field = fields.getJSONObject(i);

            if (field.get("type") instanceof JSONArray) {
                JSONArray union = field.getJSONArray("type");

                for (int j = 0; j < union.length(); j++) {
                    if (union.get(j) instanceof JSONObject) {
                        JSONObject type = union.getJSONObject(j);

                        if (type.get("type").equals("fixed")) {
                            if (type.has("logicalType")
                                    && type.get("logicalType").equals("decimal")) {
                                int precision = type.getInt("precision");
                                int size = computeMinBytesForPrecision(precision);

                                type.put("size", size);
                                type.put("precision", type.getInt("precision"));
                                type.put("scale", type.getInt("scale"));

                                Logger.getLogger(this.getClass())
                                        .info("Schema was auto adjusted: "
                                                + type.getString("name")
                                                + " size fixed to "
                                                + size);
                            }
                        }
                    }
                }
            } else if (field.get("type") instanceof JSONObject) {
                JSONObject type = field.getJSONObject("type");

                if (type.get("type").equals("fixed")) {
                    if (type.has("logicalType")
                            && type.get("logicalType").equals("decimal")) {
                        int precision = type.getInt("precision");
                        int size = computeMinBytesForPrecision(precision);

                        type.put("size", size);
                        type.put("precision", type.getInt("precision"));
                        type.put("scale", type.getInt("scale"));

                        Logger.getLogger(this.getClass())
                                .info("Schema was auto adjusted: "
                                        + type.getString("name")
                                        + " size fixed to "
                                        + size);
                    }
                }
            }
        }

        return new Schema.Parser().parse(jsonSchema.toString());
    }

    /**
     * Returns the minimum number of bytes needed to store a decimal with a
     * given precision.
     *
     * Extracted from: https://goo.gl/JD8Q4E
     *
     * @param precision field precision.
     * @return bytes field size.
     */
    private int computeMinBytesForPrecision(int precision) {
        int bytes = 1;

        while (Math.pow(2, 8 * bytes - 1) < Math.pow(10, precision)) {
            bytes += 1;
        }

        return bytes;
    }
}
