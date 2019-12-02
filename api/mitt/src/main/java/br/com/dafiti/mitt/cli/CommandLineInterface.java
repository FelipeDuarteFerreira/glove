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
package br.com.dafiti.mitt.cli;

import br.com.dafiti.mitt.model.Configuration;
import br.com.dafiti.mitt.model.Parameter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Level;
import java.util.logging.Logger;
import org.apache.commons.cli.CommandLine;
import org.apache.commons.cli.DefaultParser;
import org.apache.commons.cli.HelpFormatter;
import org.apache.commons.cli.Options;
import org.apache.commons.cli.ParseException;

/**
 *
 * @author Valdiney V GOMES
 */
public final class CommandLineInterface {

    CommandLine line;
    private final Options options;
    private final Map<String, String> defaults;

    /**
     *
     * @param configuration
     * @param arguments
     */
    public CommandLineInterface(Configuration configuration, String[] arguments) {
        this.options = new Options();
        this.defaults = new HashMap();

        List<Parameter> parameters = configuration.getParameters();

        if (!parameters.isEmpty()) {
            parameters.forEach((parameter) -> {
                if (parameter.getDefaultValue() != null
                        && !parameter.getDefaultValue().isEmpty()) {
                    this.defaults.put(parameter.getName(), parameter.getDefaultValue());
                }

                if (parameter.isOptional()) {
                    this.options.addOption(
                            parameter.getAbreviation(),
                            parameter.getName(),
                            parameter.hasArgument(),
                            parameter.getDescription()
                    );
                } else {
                    this.options.addRequiredOption(
                            parameter.getAbreviation(),
                            parameter.getName(),
                            parameter.hasArgument(),
                            parameter.getDescription()
                    );
                }
            });

            this.options.addOption("hp", "help", false, "Help");
        }

        try {
            line = new DefaultParser().parse(options, arguments);

            if (arguments.length == 1 && line.hasOption("help")) {
                this.help();
                System.exit(0);
            }
        } catch (ParseException ex) {
            this.help();
            Logger.getLogger(this.getClass().getName()).log(Level.SEVERE, "Fail parsing parameters!", ex);
            System.exit(1);
        }
    }

    /**
     *
     */
    private void help() {
        HelpFormatter formatter = new HelpFormatter();
        formatter.printHelp("Mitt", options, true);
        System.exit(0);
    }

    /**
     *
     * @param parameter
     * @return
     */
    public boolean hasParameter(String parameter) {
        return line.hasOption(parameter);
    }

    /**
     *
     * @param parameter
     * @return
     */
    public String getParameter(String parameter) {
        String value = line.getOptionValue(parameter);

        if (value == null && defaults.containsKey(parameter)) {
            value = defaults.get(parameter);
        }

        return value;
    }

    /**
     *
     * @param parameter
     * @return
     */
    public int getParameterAsInteger(String parameter) {
        return Integer.valueOf(this.getParameter(parameter));
    }

    /**
     *
     * @param parameter
     * @return
     */
    public boolean getParameterAsBoolean(String parameter) {
        return Boolean.valueOf(this.getParameter(parameter));
    }

    /**
     *
     * @param parameter
     * @param separator
     * @return
     */
    public List<String> getParameterAsList(String parameter, String separator) {
        List<String> parameters = new ArrayList();
        String value = this.getParameter(parameter);

        if (value != null
                && !value.isEmpty()) {
            parameters = Arrays.asList(this.getParameter(parameter).split(separator));
        }

        return parameters;
    }
    
    /**
     *
     * @param parameter
     * @return
     */
    public Character getParameterAsChar(String parameter) {
        String value = line.getOptionValue(parameter);

        if (value == null && defaults.containsKey(parameter)) {
            value = defaults.get(parameter);
        }

        return value.charAt(0);
    }
    
    /**
     *
     * @param parameter
     * @return
     */
    public String getParameterAsLowerCase(String parameter) {
        String value = line.getOptionValue(parameter);

        if (value == null && defaults.containsKey(parameter)) {
            value = defaults.get(parameter);
        }

        return value.toLowerCase();
    }
}
