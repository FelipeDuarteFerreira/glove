/*
 * Copyright (c) 2021 Dafiti Group
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
package br.com.dafiti.mitt.transformation.embedded;

import br.com.dafiti.mitt.transformation.Parser;
import br.com.dafiti.mitt.transformation.Transformable;
import java.util.List;
import java.util.concurrent.ConcurrentHashMap;

/**
 *
 * @author Valdiney V GOMES
 */
public class RowNumber implements Transformable {

    private List<Object> fields;
    private ConcurrentHashMap<String, Integer> map;

    @Override
    public void init() {
        map = new ConcurrentHashMap();
    }

    public RowNumber() {
    }

    public RowNumber(List<Object> fields) {
        this.fields = fields;
    }

    @Override
    public String getValue(
            Parser parser,
            List<Object> record) {

        int row = 0;
        String key = new String();

        if (parser.getFile() != null) {
            key = parser.getFile().getName();
        }

        //Identifies if should define the key based on a field. 
        if (fields != null) {
            String value = "";

            for (Object field : fields) {
                value += parser.evaluate(record, field);
            }

            key += String.valueOf(value);
        }

        //Identifies if the key already exists and increment the counter.
        if (map.containsKey(key)) {
            row = map.get(key) + 1;
        }

        map.put(key, row);
        return String.valueOf(row);
    }
}
