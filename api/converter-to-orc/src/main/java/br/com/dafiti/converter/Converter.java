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
package br.com.dafiti.converter;

import br.com.dafiti.datalake.S3;
import com.univocity.parsers.csv.CsvParser;
import com.univocity.parsers.csv.CsvParserSettings;
import java.io.File;
import java.sql.Date;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import org.apache.commons.lang.BooleanUtils;
import org.apache.commons.lang.math.NumberUtils;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.hive.ql.exec.vector.BytesColumnVector;
import org.apache.hadoop.hive.ql.exec.vector.DecimalColumnVector;
import org.apache.hadoop.hive.ql.exec.vector.DoubleColumnVector;
import org.apache.hadoop.hive.ql.exec.vector.LongColumnVector;
import org.apache.hadoop.hive.ql.exec.vector.TimestampColumnVector;
import org.apache.hadoop.hive.ql.exec.vector.VectorizedRowBatch;
import org.apache.hadoop.hive.serde2.io.DateWritable;
import org.apache.hadoop.hive.serde2.io.HiveDecimalWritable;
import org.apache.log4j.Logger;
import org.apache.orc.CompressionKind;
import org.apache.orc.OrcFile;
import org.apache.orc.OrcFile.EncodingStrategy;
import org.apache.orc.Reader;
import org.apache.orc.RecordReader;
import org.apache.orc.TypeDescription;
import org.apache.orc.TypeDescription.Category;
import org.apache.orc.Writer;
import org.apache.orc.mapred.OrcTimestamp;

/**
 * This class read a csv file and write the records into a orc file
 *
 * @author Guilherme OLIVEIRA
 * @author Valdiney V GOMES
 */
public class Converter implements Runnable {

    private final File csvFile;
    private final TypeDescription schema;
    private final CompressionKind compression;
    private final Character delimiter;
    private final Character quote;
    private final Character quoteEscape;
    private final boolean replace;
    private final boolean header;
    private final int fieldKey;
    private final boolean duplicated;
    private final boolean merge;
    private final String bucketPath;
    private final String mode;

    /**
     * Constructor.
     *
     * @param csvFile CSV file.
     * @param compression Orc file compression.
     * @param delimiter File delimiter.
     * @param quote File quote.
     * @param quoteEscape File escape.
     * @param schema Avro schema file.
     * @param header Identify if the file has header.
     * @param replace Identify if should replace the orignal file.
     * @param fieldKey Unique key field.
     * @param duplicated Identify if duplicated is allowed
     * @param merge Identify if should merge existing files.
     * @param bucket Identify storage bucket.
     * @param mode Identify partition mode.
     */
    public Converter(
            File csvFile,
            String compression,
            Character delimiter,
            Character quote,
            Character quoteEscape,
            TypeDescription schema,
            boolean header,
            boolean replace,
            int fieldKey,
            boolean duplicated,
            boolean merge,
            String bucket,
            String mode) {

        this.csvFile = csvFile;
        this.schema = schema;
        this.delimiter = delimiter;
        this.quote = quote;
        this.quoteEscape = quoteEscape;
        this.replace = replace;
        this.header = header;
        this.fieldKey = fieldKey;
        this.duplicated = duplicated;
        this.merge = merge;
        this.bucketPath = bucket;
        this.mode = mode;

        switch (compression) {
            case "lz4":
                this.compression = CompressionKind.LZ4;
                break;
            case "lzo":
                this.compression = CompressionKind.LZO;
                break;
            case "snappy":
                this.compression = CompressionKind.SNAPPY;
                break;
            case "zlib":
                this.compression = CompressionKind.ZLIB;
                break;
            case "none":
                this.compression = CompressionKind.NONE;
                break;
            default:
                this.compression = CompressionKind.ZLIB;
                break;
        }
    }

    /**
     * Convert a csv file to a orc file based on determined struct.
     */
    @Override
    public void run() {
        //Line being processed.
        int rowNumber = 0;

        //Row being processed.
        String name;

        //Value being processed.
        String[] record;
        String value;
        int row = 0;

        //Unique key list.
        HashSet<String> key = new HashSet();

        //Statistics.
        int csvRecords = 0;
        int orcRecords = 0;
        int updatedRecords = 0;
        int duplicatedRecords = 0;

        //Log the process init.
        Logger.getLogger(this.getClass()).info("Converting CSV to ORC: " + csvFile.getAbsolutePath());

        try {
            //Get the orc file.
            File orcFile = new File(csvFile.getAbsolutePath().replace(".csv", "." + this.compression.toString().toLowerCase() + ".orc"));
            File originalFile = new File(orcFile.getAbsolutePath().replace(".orc", ".original.orc"));

            //Remove old files. 
            if (orcFile.exists()) {
                orcFile.delete();
            }

            if (merge) {
                if (originalFile.exists()) {
                    originalFile.delete();
                }
            }

            //Define the writer.
            Writer orcWriter = OrcFile.createWriter(new Path(orcFile.getAbsolutePath()), OrcFile
                    .writerOptions(new Configuration())
                    .setSchema(this.schema)
                    .compress(this.compression)
                    .encodingStrategy(EncodingStrategy.SPEED));

            //Define the vectorized row batch.
            VectorizedRowBatch rowBatchWriter = schema.createRowBatch();

            //List the type description.
            List<TypeDescription> typeDescription = schema.getChildren();

            //List the field name.
            List<String> fieldNames = schema.getFieldNames();

            //Define a settings.
            CsvParserSettings parserSettings = new CsvParserSettings();
            parserSettings.setNullValue("");
            parserSettings.setMaxCharsPerColumn(-1);

            //Define format settings
            parserSettings.getFormat().setDelimiter(delimiter);
            parserSettings.getFormat().setQuote(quote);
            parserSettings.getFormat().setQuoteEscape(quoteEscape);

            //Define the input buffer.
            parserSettings.setInputBufferSize(3 * (1024 * 1024));

            //Define a csv parser.
            CsvParser csvParser = new CsvParser(parserSettings);

            //Init a parser.
            csvParser.beginParsing(csvFile);

            //Process each csv line.
            while ((record = csvParser.parseNext()) != null) {
                boolean add = false;

                //Identifies if the csv the field count specified in the schema.                
                if (record.length < rowBatchWriter.numCols) {
                    throw new Exception(csvFile.getName() + " expected " + rowBatchWriter.numCols + " fields, but received only " + record.length + " : " + String.join("|", record));
                }

                //Identify insert rule. 
                if (fieldKey < 0 || duplicated) {
                    add = true;
                } else if (fieldKey >= 0 && !duplicated) {
                    add = key.add(record[fieldKey]);
                }

                //Identify duplicated key.
                if (!add) {
                    System.out.println("Duplicated key in file: [" + record[fieldKey] + "]");
                    duplicatedRecords++;
                } else {
                    csvRecords++;
                }

                //Ignore the header.
                if (!(rowNumber == 0 && header) && add) {
                    //Identify the batch size. 
                    row = rowBatchWriter.size++;

                    for (int column = 0; column < fieldNames.size(); column++) {
                        value = "";

                        //Get field name.
                        name = fieldNames.get(column);

                        //Get field category.
                        Category category = typeDescription.get(column).getCategory();

                        //Get field value.
                        if ((record.length - 1) >= column) {
                            value = record[column];
                        }

                        //Identify if the field is empty.
                        if (value == null || value.isEmpty()) {
                            value = null;
                        }

                        //Write data into a row batch. 
                        this.rowBatchAppend(value, category, row, column, rowBatchWriter);
                    }

                    //Write data into orc file.
                    if (rowBatchWriter.size == rowBatchWriter.getMaxSize()) {
                        orcWriter.addRowBatch(rowBatchWriter);
                        rowBatchWriter.reset();
                    }
                }

                //Identify the record being processed.
                rowNumber++;
            }

            //Stop the parser.
            csvParser.stopParsing();

            if (merge) {
                String object = orcFile.getName();

                //Download the original object. 
                new S3().downloadObject(bucketPath, object, mode, originalFile);

                //Identify if the original file was downloaded. 
                if (originalFile.exists()) {
                    //Define the reader.
                    Reader reader = OrcFile.createReader(new Path(originalFile.getAbsolutePath()),
                            OrcFile.readerOptions(new Configuration()));

                    //Define the row.
                    RecordReader rows = reader.rows();

                    //Define the batch.
                    VectorizedRowBatch rowBatchReader = reader.getSchema().createRowBatch();

                    //Read a orc file.
                    while (rows.nextBatch(rowBatchReader)) {
                        for (int originalFileRow = 0; originalFileRow < rowBatchReader.size; ++originalFileRow) {
                            boolean add = true;

                            //Identify merge file records.
                            orcRecords++;

                            //Define the buffer to stringify values. 
                            StringBuilder readerValue;

                            //Identify if can add a record.
                            if (fieldKey >= 0 && !duplicated) {
                                readerValue = new StringBuilder();
                                rowBatchReader.cols[fieldKey].stringifyValue(readerValue, originalFileRow);

                                //Get the field value.
                                value = readerValue.toString().replaceAll("^\"|\"$", "");

                                //Idenfify if should insert or update a record.
                                add = !key.contains(value);
                            }

                            if (add) {
                                //Identify the batch size. 
                                row = rowBatchWriter.size++;

                                for (int column = 0; column < fieldNames.size(); column++) {
                                    //stringify the value.
                                    readerValue = new StringBuilder();
                                    rowBatchReader.cols[column].stringifyValue(readerValue, originalFileRow);

                                    //Get the field value.
                                    value = readerValue.toString();

                                    //Get field category.
                                    Category category = typeDescription.get(column).getCategory();

                                    //Identify if the field is empty.
                                    if (value == null || value.isEmpty()) {
                                        value = null;
                                    }

                                    //Write data into a row batch. 
                                    this.rowBatchAppend(value, category, row, column, rowBatchWriter);
                                }

                                //Write data into orc file.
                                if (rowBatchWriter.size == rowBatchWriter.getMaxSize()) {
                                    orcWriter.addRowBatch(rowBatchWriter);
                                    rowBatchWriter.reset();
                                }
                            } else {
                                updatedRecords++;
                            }

                            //Identify the record being processed.
                            rowNumber++;
                        }
                    }
                }
            }

            //Write remaining data into orc file.
            if (rowBatchWriter.size != 0) {
                orcWriter.addRowBatch(rowBatchWriter);
                rowBatchWriter.reset();
            }

            //Close the orc file.
            orcWriter.close();

            //Identifies if the csv file is empty.
            if (rowNumber == 0) {
                throw new Exception("Empty csv file!");
            } else {
                //Print on console.
                System.out.println("[" + orcFile.getName() + "] records: "
                        + orcRecords
                        + ", Delta: "
                        + csvRecords
                        + ", ( Updated: " + updatedRecords + ", Inserted: " + (csvRecords - updatedRecords) + ", Duplicated:" + duplicatedRecords + " )"
                        + " Final: "
                        + (orcRecords + (csvRecords - updatedRecords)));
            }

            //Remove the original file.
            if (merge) {
                if (originalFile.exists()) {
                    originalFile.delete();
                }
            }

            //Identify if should remove csv file. 
            if (replace) {
                if (csvFile.exists()) {
                    csvFile.delete();
                }
            }
        } catch (Exception ex) {
            Logger.getLogger(this.getClass()).error("Error [" + ex + "] converting CSV to ORC at line [" + rowNumber + "]");
            Logger.getLogger(this.getClass()).error(Arrays.toString(ex.getStackTrace()));

            System.exit(1);
        }
    }

    /**
     * Append a value int a specific row and column.
     *
     * @param value Value
     * @param category Category
     * @param column Column
     * @param row Row
     * @param batchWriter BatchWriter
     * @throws ParseException
     */
    private void rowBatchAppend(
            String value,
            Category category,
            int row,
            int column,
            VectorizedRowBatch batchWriter) throws ParseException {

        //Identify if the value is null.
        if (value == null) {
            batchWriter.cols[column].noNulls = false;
            batchWriter.cols[column].isNull[row] = true;
        } else {
            //Convert values to fit the category.
            switch (category) {
                case BOOLEAN:
                    ((LongColumnVector) batchWriter.cols[column]).vector[row] = BooleanUtils.toBoolean(value) ? 1 : 0;
                    break;
                case DATE:
                    SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd");
                    ((LongColumnVector) batchWriter.cols[column]).vector[row] = new DateWritable((Date) format.parse(value)).getDays();
                    break;
                case TIMESTAMP:
                    ((TimestampColumnVector) batchWriter.cols[column]).set(row, new OrcTimestamp(value));
                    break;
                case INT:
                    ((LongColumnVector) batchWriter.cols[column]).vector[row] = NumberUtils.toInt(value);
                    break;
                case LONG:
                    ((LongColumnVector) batchWriter.cols[column]).vector[row] = NumberUtils.toLong(value);
                    break;
                case FLOAT:
                    ((DoubleColumnVector) batchWriter.cols[column]).vector[row] = NumberUtils.toFloat(value);
                    break;
                case DOUBLE:
                    ((DoubleColumnVector) batchWriter.cols[column]).vector[row] = NumberUtils.toDouble(value);
                    break;
                case DECIMAL:
                    ((DecimalColumnVector) batchWriter.cols[column]).set(row, new HiveDecimalWritable(value));
                    break;
                case STRING:
                    ((BytesColumnVector) batchWriter.cols[column]).setVal(row, value.replaceAll("^\"|\"$", "").getBytes());
                    break;
                default:
                    break;
            }
        }
    }
}
