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
package br.com.dafiti.mitt;

import br.com.dafiti.mitt.cli.CommandLineInterface;
import br.com.dafiti.mitt.model.Configuration;
import br.com.dafiti.mitt.output.Output;
import br.com.dafiti.mitt.settings.ReaderSettings;
import br.com.dafiti.mitt.settings.WriterSettings;
import java.io.File;
import java.io.FileFilter;
import java.util.List;
import org.apache.commons.io.filefilter.WildcardFileFilter;

/**
 *
 * @author Valdiney V GOMES
 */
public class Mitt {

    private Output output;
    private File outputFile;
    private Configuration configuration;
    private ReaderSettings readerSettings;
    private WriterSettings writerSettings;
    private CommandLineInterface commandLineInterface;

    private boolean debug = false;

    /**
     *
     * @param output
     */
    public void setOutputFile(String output) {
        this.getWriterSettings()
                .setOutputFile(new File(output));
    }

    /**
     *
     * @param debug
     */
    public void setDebug(boolean debug) {
        this.debug = debug;
    }

    /**
     *
     * @param arguments
     * @return
     */
    public CommandLineInterface getCommandLineInterface(String[] arguments) {
        if (commandLineInterface == null) {
            commandLineInterface = new CommandLineInterface(
                    this.getConfiguration(),
                    arguments);
        }

        return commandLineInterface;
    }

    /**
     *
     * @return
     */
    public Configuration getConfiguration() {
        if (configuration == null) {
            configuration = new Configuration(debug);
        }

        return configuration;
    }

    /**
     *
     * @return
     */
    public ReaderSettings getReaderSettings() {
        if (readerSettings == null) {
            readerSettings = new ReaderSettings();
        }

        return readerSettings;
    }

    /**
     *
     * @return
     */
    public WriterSettings getWriterSettings() {
        if (writerSettings == null) {
            writerSettings = new WriterSettings();
        }

        return writerSettings;
    }

    /**
     *
     * @return
     */
    private Output getWriter() {
        if (output == null) {
            output = new Output(
                    this.getConfiguration(),
                    this.getReaderSettings(),
                    this.getWriterSettings());
        }

        return output;
    }

    /**
     *
     * @param record
     */
    public void write(List record) {
        this.getWriter().write(record);
    }

    /**
     *
     * @param record
     */
    public void write(String[] record) {
        this.getWriter().write(record);
    }

    /**
     *
     * @param file
     */
    public void write(File file) {
        this.write(file, "*");
    }

    /**
     *
     * @param file
     * @param wildcard
     */
    public void write(
            File file,
            String wildcard) {

        FileFilter fileFilter;
        File[] files = null;

        if (file.isDirectory()) {
            fileFilter = new WildcardFileFilter(wildcard);
            files = file.listFiles(fileFilter);
        }

        if (files != null) {
            this.getWriter().write(files);
        }
    }

    /**
     *
     */
    public void close() {
        if (outputFile != null) {
            this.getWriter().close();
        }
    }
}
