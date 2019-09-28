

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
import br.com.dafiti.mitt.Mitt;
import br.com.dafiti.mitt.exception.DuplicateEntityException;
import br.com.dafiti.mitt.cli.CommandLineInterface;
import br.com.dafiti.mitt.model.Field;
import br.com.dafiti.mitt.transformation.embedded.Concat;
import br.com.dafiti.mitt.transformation.embedded.Now;
import java.util.ArrayList;
import java.util.List;

/**
 *
 * @author Valdiney V GOMES
 */
public class MittTest {

    public static void main(String[] args) throws DuplicateEntityException {
        Mitt mitt = new Mitt("/tmp/mitt/mitt.csv");

        List<Object> fields = new ArrayList<>();
        fields.add(new Field("id"));
        fields.add(new Field("nome"));
        fields.add(new Field("data", new Now()));

        //Fields.
        mitt.getConfiguration().addCustomField("custom_primary_key", new Concat(fields));
        mitt.getConfiguration().addField("id");
        mitt.getConfiguration().addField("nome");
        mitt.getConfiguration().addField("data");
        mitt.getConfiguration().addCustomField("scanner::concat([id,nome,::now(),::Dateformat(data,YYYYMM)])");
        mitt.getConfiguration().addCustomField("fixed::concat([id,nome])");
        mitt.getConfiguration().addCustomField("bola::eval((id*5))");

        //Parameters. 
        mitt.getConfiguration().addParameter("a", "primeiro", "Primeiro parâmetro", "xxx");
        mitt.getConfiguration().addParameter("b", "segundo", "Segundo parâmetro");
        mitt.getConfiguration().addParameter("c", "help", "Help", false);

        List<String> parameter = new ArrayList();
        //parameter.add("--help");
        parameter.add("--primeiro=1");
        parameter.add("--segundo=a+b+c");

        CommandLineInterface cli = mitt.getCommandLineInterface(parameter.toArray(new String[0]));
        cli.getParameter("primeiro");
        cli.getParameterAsList("segundo", "\\+");

        for (int i = 0; i < 10; i++) {
            List<Object> data = new ArrayList();
            data.add(i);
            data.add("A" + i);
            data.add("2019-01-01 00:00:00");

            mitt.write(data);
        }

        mitt.close();
    }
}
