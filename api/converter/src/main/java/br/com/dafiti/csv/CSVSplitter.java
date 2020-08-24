/*
 * Copyright (c) 2018 Dafiti Group
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
package br.com.dafiti.csv;

import com.univocity.parsers.csv.CsvParser;
import com.univocity.parsers.csv.CsvParserSettings;
import com.univocity.parsers.csv.CsvWriter;
import com.univocity.parsers.csv.CsvWriterSettings;
import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.UUID;
import org.apache.commons.io.FileUtils;
import org.apache.commons.io.LineIterator;
import org.apache.log4j.Logger;

/**
 * This class read a plain csv and write into a plain csv file.
 *
 * @author Valdiney V GOMES
 */
public class CSVSplitter implements Runnable {

    private final File csvFile;
    private final int partitionColumn;
    private final Character delimiter;
    private final Character quote;
    private final Character quoteEscape;
    private final boolean header;
    private final boolean replace;
    private final String splitStrategy;

    private static final int SLICES = 65;

    /**
     * Constructor.
     *
     * @param csvFile Orc File
     * @param fieldPartition Partition field
     * @param delimiter File delimiter
     * @param quote File quote.
     * @param quoteEscape File escape.
     * @param header Identify if the file has header.
     * @param replace Identify if should replace the orignal file.
     * @param splitStrategy Identify if should use the fastest strategy to
     * partitioning.
     */
    public CSVSplitter(
            File csvFile,
            int fieldPartition,
            Character delimiter,
            Character quote,
            Character quoteEscape,
            boolean header,
            boolean replace,
            String splitStrategy) {

        this.csvFile = csvFile;
        this.partitionColumn = fieldPartition;
        this.delimiter = delimiter;
        this.quote = quote;
        this.quoteEscape = quoteEscape;
        this.replace = replace;
        this.header = header;
        this.splitStrategy = splitStrategy;
    }

    /**
     * Convert a csv file to a csv file.
     */
    @Override
    public void run() {
        Logger.getLogger(this.getClass()).info("Splitting CSV file");

        try {
            if (splitStrategy.equalsIgnoreCase("FAST")) {
                this.fastSplit();
            } else {
                this.secureSplit();
            }

            //Identify if should remove csv file. 
            if (replace) {
                csvFile.delete();
            }
        } catch (IOException ex) {
            Logger.getLogger(this.getClass()).error("Error [" + ex + "] splitting CSV file");
            System.exit(1);
        }
    }

    /**
     * Fast, but insecure split mode.
     *
     * @throws IOException
     */
    private void fastSplit() throws IOException {
        String part = "";
        int lineNumber = 0;
        HashMap<String, BufferedWriter> partitions = new HashMap<>();
        LineIterator lineIterator = FileUtils.lineIterator(csvFile, "UTF-8");

        try {
            while (lineIterator.hasNext()) {
                String line = lineIterator.nextLine();

                if (!(lineNumber == 0 && header)) {
                    String[] split = line.split(delimiter.toString());

                    if (split.length != 0) {
                        if (split[split.length - 1].startsWith("\"") && !split[split.length - 1].endsWith("\"")) {
                            part = line;
                        } else {
                            if (!part.isEmpty()) {
                                line = part + line;
                                part = "";
                                split = line.split(delimiter.toString());
                            }
                        }

                        if (part.isEmpty()) {
                            String partition;

                            if (partitionColumn == -1) {
                                partition = String.valueOf(Math.abs(Math.floorMod(lineNumber, SLICES)));
                            } else {
                                partition = split[partitionColumn].replaceAll("\\W", "");
                            }

                            if (!partitions.containsKey(partition)) {
                                String partitionPath = csvFile.getParent() + "/" + partition;
                                Files.createDirectories(Paths.get(partitionPath));
                                BufferedWriter bufferedWriter = new BufferedWriter(new FileWriter(partitionPath + "/" + UUID.randomUUID() + ".csv"));

                                partitions.put(partition, bufferedWriter);
                            }

                            partitions.get(partition).append(line + "\r\n");
                        }
                    }
                }

                lineNumber++;
            }
        } finally {
            LineIterator.closeQuietly(lineIterator);
        }

        //Flush and close the output stream.
        partitions.forEach((k, v) -> {
            try {
                v.flush();
                v.close();
            } catch (IOException ex) {
                Logger.getLogger(this.getClass()).error("Error [" + ex + "] closing writer");
                System.exit(1);
            }
        });
    }

    /**
     * Slow, but really reliable split strategy.
     *
     * @throws IOException
     */
    private void secureSplit() throws IOException {
        int lineNumber = 0;
        HashMap<String, CsvWriter> partitions = new HashMap<>();

        //Writer. 
        CsvWriterSettings writerSettings = new CsvWriterSettings();
        writerSettings.getFormat().setDelimiter(delimiter);
        writerSettings.getFormat().setQuote(quote);
        writerSettings.getFormat().setQuoteEscape(quoteEscape);
        writerSettings.setNullValue("");
        writerSettings.setMaxCharsPerColumn(-1);

        //Reader. 
        CsvParserSettings readerSettings = new CsvParserSettings();
        readerSettings.getFormat().setDelimiter(delimiter);
        readerSettings.getFormat().setQuote(quote);
        readerSettings.getFormat().setQuoteEscape(quoteEscape);
        readerSettings.setNullValue("");
        readerSettings.setMaxCharsPerColumn(-1);
        readerSettings.setInputBufferSize(5 * (1024 * 1024));

        CsvParser csvParser = new CsvParser(readerSettings);
        csvParser.beginParsing(csvFile);

        String[] record;

        while ((record = csvParser.parseNext()) != null) {
            if (!(lineNumber == 0 && header)) {
                String partition;

                if (partitionColumn == -1) {
                    partition = String.valueOf(Math.abs(Math.floorMod(lineNumber, SLICES)));
                } else {
                    partition = record[partitionColumn].replaceAll("\\W", "");
                }

                if (!partitions.containsKey(partition)) {
                    String partitionPath = csvFile.getParent() + "/" + partition;
                    Files.createDirectories(Paths.get(partitionPath));
                    partitions.put(partition, new CsvWriter(new FileWriter(partitionPath + "/" + UUID.randomUUID() + ".csv"), writerSettings));
                }

                partitions.get(partition).writeRow(record);
            }

            lineNumber++;
        }

        //Stop the parser.
        csvParser.stopParsing();

        //Flush and close the output stream.
        partitions.forEach((k, v) -> {
            v.flush();
            v.close();
        });
    }
}
