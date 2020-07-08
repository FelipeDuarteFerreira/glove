/*
 * Copyright (c) 2020 Dafiti Group
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
package br.com.dafiti.one.signal;

import br.com.dafiti.mitt.Mitt;
import br.com.dafiti.mitt.cli.CommandLineInterface;
import br.com.dafiti.mitt.exception.DuplicateEntityException;
import br.com.dafiti.mitt.transformation.embedded.Concat;
import br.com.dafiti.mitt.transformation.embedded.Now;
import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.ArrayList;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.json.simple.JSONArray;
import org.json.simple.JSONObject;
import org.json.simple.parser.JSONParser;
import org.json.simple.parser.ParseException;

/**
 *
 * @author Helio Leal
 */
public class OneSignal {

    /**
     * One signal API data transfer
     *
     * @param args cli parameteres provided by command line.
     */
    public static void main(String[] args) {
        Logger.getLogger(OneSignal.class.getName()).info("GLOVE - One Signal Extractor started");

        //Define the mitt.
        Mitt mitt = new Mitt();

        try {
            //Defines parameters.
            mitt.getConfiguration()
                    .addParameter("c", "credentials", "Credentials file", "", true, false)
                    .addParameter("o", "output", "Output file", "", true, false)
                    .addParameter("s", "service", "Identifies the service name", "", true, false)
                    .addParameter("e", "endpoint", "Identifies the endpoint that contains a list to extract data from", "", true, false)
                    .addParameter("f", "field", "Fields to be extracted from the file", "", true, false)
                    .addParameter("d", "delimiter", "(Optional) File delimiter; ';' as default", ";")
                    .addParameter("sl", "sleep", "(Optional) Sleep time in seconds at one request and another; 0 is default", "0")
                    .addParameter("p", "partition", "(Optional)  Partition, divided by + if has more than one field")
                    .addParameter("k", "key", "(Optional) Unique key, divided by + if has more than one field", "")
                    .addParameter("m", "method", "(Optional) Request method; GET is default", "GET");

            //Reads the command line interface. 
            CommandLineInterface cli = mitt.getCommandLineInterface(args);

            //Defines output file.
            mitt.setOutputFile(cli.getParameter("output"));

            //Defines fields.
            mitt.getConfiguration()
                    .addCustomField("partition_field", new Concat((List) cli.getParameterAsList("partition", "\\+")))
                    .addCustomField("custom_primary_key", new Concat((List) cli.getParameterAsList("key", "\\+")))
                    .addCustomField("etl_load_date", new Now())
                    .addField(cli.getParameterAsList("field", "\\+"));

            //Reads the credentials file. 
            JSONParser parser = new JSONParser();
            JSONObject credentials = (JSONObject) parser.parse(new FileReader(cli.getParameter("credentials")));

            //Identifies original fields.
            List<String> fields = mitt.getConfiguration().getOriginalFieldsName();

            Logger.getLogger(OneSignal.class.getName()).log(Level.INFO, "Retrieving data from URL: {0}", new Object[]{cli.getParameter("endpoint")});

            //Connect to API.
            HttpURLConnection httpURLConnection = (HttpURLConnection) new URL(cli.getParameter("endpoint")).openConnection();
            httpURLConnection.setRequestProperty("Authorization", (String) credentials.get("authorization"));
            //httpURLConnection.setRequestProperty("Accept", "application/json");
            httpURLConnection.setRequestMethod(cli.getParameter("method"));

            //Get API Call response.
            try (BufferedReader bufferedReader = new BufferedReader(
                    new InputStreamReader(httpURLConnection.getInputStream()))) {
                String response;

                //Get service list from API.
                while ((response = bufferedReader.readLine()) != null) {
                    String url = (String) ((JSONObject) new JSONParser()
                            .parse(response))
                            .get("csv_file_url");                    

                    Logger.getLogger(OneSignal.class.getName()).log(Level.INFO, "{0} {1} found ", new Object[]{jsonObject.size(), cli.getParameter("service")});

                    
                }
            }
            httpURLConnection.disconnect();

        } catch (DuplicateEntityException
                | FileNotFoundException
                | ParseException ex) {

            Logger.getLogger(OneSignal.class.getName()).log(Level.SEVERE, "GLOVE - One Signal fail: ", ex);
            System.exit(1);
        } catch (IOException ex) {

            Logger.getLogger(OneSignal.class.getName()).log(Level.SEVERE, "GLOVE - One Signal fail: ", ex);
            System.exit(1);
        } finally {
            mitt.close();
        }

        Logger.getLogger(OneSignal.class
                .getName()).info("GLOVE - One Signal Extractor finalized");
    }
}
