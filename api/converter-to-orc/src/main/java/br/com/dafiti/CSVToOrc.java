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
package br.com.dafiti;

import br.com.dafiti.converter.Converter;
import br.com.dafiti.mitt.Mitt;
import br.com.dafiti.mitt.cli.CommandLineInterface;
import br.com.dafiti.mitt.exception.DuplicateEntityException;
import br.com.dafiti.schema.Parser;
import java.io.File;
import java.io.FileFilter;
import java.io.IOException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import org.apache.commons.io.filefilter.WildcardFileFilter;
import org.apache.log4j.BasicConfigurator;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.apache.orc.TypeDescription;

/**
 * Converts an input file to Orc.
 *
 * @author Helio Leal
 * @author Valdiney V GOMES
 */
public class CSVToOrc {

    /**
     *
     * @param args
     *
     * @throws br.com.dafiti.mitt.exception.DuplicateEntityException
     * @throws java.io.IOException
     */
    public static void main(String[] args) throws
            DuplicateEntityException,
            IOException {

        Logger.getLogger(CSVToOrc.class.getName())
                .info("Converter to orc started.");

        //Define the mitt.
        Mitt mitt = new Mitt();

        //Define parameters.
        mitt.getConfiguration()
                .addParameter("F", "folder", "Folder where the files to be converted to parquet are", "", true, false)
                .addParameter("f", "filename", "Filename, with wildcard if necessary, to be converted", "", true, false)
                .addParameter("s", "schema", "Avro schema to be used on conversion", "", true, false)
                .addParameter("b", "bucket", "Identify the storage bucket", "", true, true)
                .addParameter("d", "debug", "Show full log messages", "", true, true)
                .addParameter("m", "mode", "Identify the partition mode", "virtual")
                .addParameter("k", "fieldkey", "Unique key field", "-1")
                .addParameter("d", "merge", "Identify if should merge existing files", "false")
                .addParameter("z", "duplicated", "Identify if duplicated is allowed", "false")
                .addParameter("C", "compression", "Identify the compression to be applied", "gzip")
                .addParameter("H", "header", "Identify the csv file has a header", "false")
                .addParameter("t", "thread", "Limit of thread", "1")
                .addParameter("r", "replace", "Identify if csv files will be replaced to parquet files", "false")
                .addParameter("D", "delimiter", "Delimiter of csv files", ";")
                .addParameter("q", "quote", "Identify the quote character", "\"")
                .addParameter("e", "escape", "Identify the quote escape character", "\"");

        //Read the command line interface. 
        CommandLineInterface cli = mitt.getCommandLineInterface(args);

        //Configure Log4J.
        BasicConfigurator.configure();

        //Configure HADOOP_HOME.
        System.setProperty("hadoop.home.dir", "/");

        try {

            //Identify the log level.
            if (cli.getParameter("debug") == null) {
                org.apache.log4j.Logger.getRootLogger().setLevel(Level.ERROR);
            } else {
                org.apache.log4j.Logger.getRootLogger().setLevel(Level.DEBUG);
            }

            //Get the file to convert.
            FileFilter fileFilter = new WildcardFileFilter(
                    cli.getParameter("filename"));

            //Get the folder. 
            String folderName = cli.getParameter("folder").replace("file:", "");
            File[] files = new File(folderName).listFiles(fileFilter);

            //Identify if there are files to process.
            if (files != null) {

                //Define how many files should be converted simultaneously. 
                ExecutorService executor = Executors.newFixedThreadPool(
                        cli.getParameterAsInteger("thread"));

                TypeDescription schema = new Parser(
                        new File(cli.getParameter("schema")))
                        .getOrcSchema();

                for (File file : files) {
                    executor.execute(new Converter(
                            file,
                            cli.getParameter("compression"),
                            cli.getParameterAsChar("delimiter"),
                            cli.getParameterAsChar("quote"),
                            cli.getParameterAsChar("escape"),
                            schema,
                            cli.getParameterAsBoolean("header"),
                            cli.getParameterAsBoolean("replace"),
                            cli.getParameterAsInteger("fieldkey"),
                            cli.getParameterAsBoolean("duplicated"),
                            cli.getParameterAsBoolean("merge"),
                            cli.getParameterAsLowerCase("bucket"),
                            cli.getParameterAsLowerCase("mode")
                    ));
                }

                //Exit the thread executor.
                executor.shutdown();
            }
        } catch (NumberFormatException ex) {
            org.apache.log4j.Logger
                    .getLogger(CSVToOrc.class)
                    .error(ex);
            System.exit(1);
        }

        Logger.getLogger(CSVToOrc.class.getName())
                .info("Converter to orc finalized.");
    }
}
