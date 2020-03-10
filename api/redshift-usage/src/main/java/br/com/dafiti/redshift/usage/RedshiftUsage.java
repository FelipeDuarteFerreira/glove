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
package br.com.dafiti.redshift.usage;

import br.com.dafiti.mitt.Mitt;
import br.com.dafiti.mitt.cli.CommandLineInterface;
import br.com.dafiti.mitt.exception.DuplicateEntityException;
import br.com.dafiti.mitt.transformation.embedded.Concat;
import br.com.dafiti.mitt.transformation.embedded.Now;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.List;
import java.util.Properties;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author Flávia Lima
 */
public class RedshiftUsage {

    /**
     *
     * @param args command line parameters
     * @throws br.com.dafiti.mitt.exception.DuplicateEntityException
     * @throws java.io.FileNotFoundException
     * @throws java.sql.SQLException
     */
    public static void main(String[] args) throws 
            DuplicateEntityException, 
            FileNotFoundException, 
            IOException, 
            SQLException {
        Mitt mitt = new Mitt();
        Logger.getLogger(RedshiftUsage.class.getName()).log(Level.INFO, "Redshift Usage - Extractor started");

        //Defines parameters
        mitt.getConfiguration()
                .addParameter("c", "credentials", "Credentials file", "", true, false)
                .addParameter("o", "output", "(Optional) Output file. Default is /tmp/hoover.csv", "/tmp/hoover.csv")
                .addParameter("d", "days", "(Optional) search occurrence period. Default value is 90", "90")
                .addParameter("e", "entity", "(Optional) entity to be searched. Default value fetchs all occurrences", "")
                .addParameter("p", "partition", "(Optional)  Partition, divided by + if has more than one")
                .addParameter("k", "key", "(Optional) Unique key, divided by + if has more than one", "");

        CommandLineInterface cli = mitt.getCommandLineInterface(args);

        //Defines the output file path
        mitt.setOutput(cli.getParameter("output"));

        //Defines the output fields
        mitt.getConfiguration()
                .addCustomField("partition_field", new Concat((List) cli.getParameterAsList("partition", "\\+")))
                .addCustomField("custom_primary_key", new Concat((List) cli.getParameterAsList("key", "\\+")))
                .addCustomField("etl_load_date", new Now())
                .addField("user")
                .addField("date")
                .addField("query")
                .addField("entity");

        Logger.getLogger(RedshiftUsage.class.getName()).log(Level.INFO, "Redshift Usage - Connecting to database.");

        //Connect to database
        Properties properties = new Properties();
        FileInputStream file = new FileInputStream(cli.getParameter("credentials"));
        properties.load(file);
        Connection conn = DriverManager.getConnection(properties.getProperty("url"), properties);

        Logger.getLogger(RedshiftUsage.class.getName()).log(Level.INFO, "Redshift Usage - Database successfully connected.");

        //Build historical query
        StringBuilder query = new StringBuilder();
        query.append("SELECT ");
        query.append("sq.pid AS pid,sq.userid AS userid,sq.query AS query,");
        query.append("TRIM( pu.usename ) AS usename,");
        query.append("TRIM( sq.querytxt ) AS querytxt,");
        query.append("TRUNC( sq.starttime ) AS date ");
        query.append("FROM ");
        query.append("admin.stl_query_history sq ");
        query.append("LEFT JOIN ");
        query.append("pg_user pu ON pu.usesysid = sq.userid ");
        query.append("WHERE ");
        query.append("sq.label = 'default' AND ");
        query.append("TRUNC( sq.starttime ) BETWEEN ( current_date -");
        query.append(cli.getParameter("days"));
        query.append(") AND current_date ");

        //Identifies if is necessary to search for a specific entity.
        if (cli.getParameter("entity") != null) {
            query.append("AND ");
            query.append("sq.querytxt LIKE '%");
            query.append(cli.getParameter("entity"));
            query.append("%' ");
        }

        //Execute historical Query
        ResultSet rs = conn.prepareStatement(query.toString()).executeQuery();

        while (rs.next()) {
            System.out.println(" ");
            System.out.println("PROCESS ID: " + rs.getString("pid"));
            System.out.println("USER ID: " + rs.getString("userid"));
            System.out.println("QUERY ID: " + rs.getInt("query"));
            System.out.println("USER: " + rs.getString("usename"));
            System.out.println("ORIGINAL QUERYTXT: " + rs.getString("querytxt"));
            System.out.println("DATE: " + rs.getDate("date"));

            String originalQuery = rs.getString("querytxt");
            String replacedQuery = originalQuery.replaceAll("[)(*:;',]", " ");
            System.out.println("Replaced Query: " + replacedQuery);
        }

        Logger.getLogger(RedshiftUsage.class.getName()).log(Level.INFO, "Redshift Usage - Extractor finished.");
    }
}

