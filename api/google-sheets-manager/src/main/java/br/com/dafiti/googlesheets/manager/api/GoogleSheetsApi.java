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
package br.com.dafiti.googlesheets.manager.api;

import br.com.dafiti.googlesheets.manager.model.SheetDetails;
import com.google.api.client.auth.oauth2.Credential;
import com.google.api.client.extensions.java6.auth.oauth2.AuthorizationCodeInstalledApp;
import com.google.api.client.extensions.jetty.auth.oauth2.LocalServerReceiver;
import com.google.api.client.googleapis.auth.oauth2.GoogleAuthorizationCodeFlow;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.http.HttpRequest;
import com.google.api.client.http.HttpRequestInitializer;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.client.json.jackson2.JacksonFactory;
import com.google.api.client.util.BackOff;
import com.google.api.client.util.ExponentialBackOff;
import com.google.api.client.util.store.FileDataStoreFactory;
import com.google.api.services.sheets.v4.SheetsScopes;
import com.google.api.services.sheets.v4.model.BatchUpdateSpreadsheetRequest;
import com.google.api.services.sheets.v4.model.DeleteDimensionRequest;
import com.google.api.services.sheets.v4.model.DimensionRange;
import com.google.api.services.sheets.v4.model.GridRange;
import com.google.api.services.sheets.v4.model.InsertDimensionRequest;
import com.google.api.services.sheets.v4.model.Request;
import com.google.api.services.sheets.v4.model.Sheet;
import com.google.api.services.sheets.v4.model.Spreadsheet;
import com.google.api.services.sheets.v4.model.SpreadsheetProperties;
import com.google.api.services.sheets.v4.model.UpdateCellsRequest;
import com.google.api.services.sheets.v4.model.ValueRange;

import com.google.api.services.sheets.v4.Sheets;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.file.Paths;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 *
 * @author flavialima
 * @author Helio Leal
 */
public class GoogleSheetsApi {

    private final String sheetName;
    private Sheets service;
    private Spreadsheet spreadsheet;
    private boolean debug;

    /**
     * Credentials file.
     *
     * @param sheetName
     */
    public GoogleSheetsApi(String sheetName, boolean debug) {
        this.sheetName = sheetName;
        this.debug = debug;
    }

    /**
     * Authenticate on Google Spreadsheet API.
     *
     * @param credentials
     * @param spreadSheetId
     * @return GoogleSheetsApi
     */
    public GoogleSheetsApi authenticate(String credentials, String spreadSheetId) {
        try {
            //Build a new authorized API client service.
            NetHttpTransport netHttpTransport
                    = GoogleNetHttpTransport.newTrustedTransport();

            //Json instance.
            JsonFactory jsonFactory = JacksonFactory.getDefaultInstance();

            //Load client secrets.
            GoogleClientSecrets googleClientSecrets
                    = GoogleClientSecrets.load(
                            jsonFactory,
                            new InputStreamReader(
                                    new FileInputStream(
                                            credentials)));

            //Build flow and trigger user authorization request.
            GoogleAuthorizationCodeFlow googleAuthorizationCodeFlow
                    = new GoogleAuthorizationCodeFlow.Builder(
                            netHttpTransport,
                            jsonFactory,
                            googleClientSecrets,
                            Collections.singletonList(SheetsScopes.SPREADSHEETS))
                            .setDataStoreFactory(
                                    new FileDataStoreFactory(
                                            new File(Paths.get(credentials).getParent().toString() + "/tokens")))
                            .setAccessType("offline")
                            .build();

            //Authorize.
            Credential credential = new AuthorizationCodeInstalledApp(googleAuthorizationCodeFlow, new LocalServerReceiver()).authorize("user");

            //Instance of sheets service.
            this.service = new Sheets.Builder(netHttpTransport, jsonFactory, setHttpTimeout(credential))
                    .setApplicationName("Google Sheets Export API")
                    .build();

            //Inits spreadsheet object.
            this.spreadsheet = this.service
                    .spreadsheets()
                    .get(spreadSheetId).execute();

        } catch (GeneralSecurityException
                | IOException ex) {
            System.err.println("Error on authenticate: " + ex.getMessage());
        }

        return this;
    }

    /**
     *
     * @param requestInitializer
     * @return
     */
    private HttpRequestInitializer setHttpTimeout(final HttpRequestInitializer requestInitializer) {
        return new HttpRequestInitializer() {
            @Override
            public void initialize(HttpRequest httpRequest) throws IOException {
                requestInitializer.initialize(httpRequest);
                httpRequest.setConnectTimeout(3 * 60000);  // 3 minutes connect timeout
                httpRequest.setReadTimeout(3 * 60000);  // 3 minutes read timeout
            }
        };
    }

    /**
     * Clear cells range.
     *
     * @param sheet SheetDetails
     */
    public void cleanCells(SheetDetails sheet) {
        try {
            System.out.println("Clearing cells from sheet: " + sheet.getName() + " (" + sheet.getId() + ")");

            List<Request> requests = new ArrayList<>();
            requests.add(
                    new Request().setUpdateCells(
                            new UpdateCellsRequest()
                                    .setRange(new GridRange().setSheetId(sheet.getId()))
                                    .setFields("userEnteredValue")));
            this.service
                    .spreadsheets()
                    .batchUpdate(this.spreadsheet.getSpreadsheetId(), new BatchUpdateSpreadsheetRequest().setRequests(requests))
                    .execute();

        } catch (IOException ex) {
            System.err.println("Error clearing cells: " + ex.getMessage());
        }
    }

    /**
     * Add new columns.
     *
     * @param sheet Sheet Details
     * @param endIndex Add column until index
     */
    public void addColumns(SheetDetails sheet, int endIndex) {
        System.out.println("Adding columns from " + this.getColumnName(sheet.getColumnCount()) + " to " + this.getColumnName(endIndex) + " because process need more columns.");

        try {
            Request request = new Request()
                    .setInsertDimension(new InsertDimensionRequest()
                            .setRange(new DimensionRange()
                                    .setSheetId(sheet.getId())
                                    .setDimension("COLUMNS")
                                    .setStartIndex(sheet.getColumnCount() - 1)
                                    .setEndIndex(endIndex - 1)
                            )
                    );

            List<Request> requests = new ArrayList();
            requests.add(request);

            Sheets.Spreadsheets.BatchUpdate batchUpdate = this.service
                    .spreadsheets()
                    .batchUpdate(this.spreadsheet.getSpreadsheetId(), new BatchUpdateSpreadsheetRequest().setRequests(requests));
            batchUpdate.execute();
        } catch (IOException ex) {
            System.err.println("Error addings columns: " + ex.getMessage());
        }
    }

    /**
     * Remove unused columns.
     *
     * @param sheet Sheet details
     * @param startIndex Remove column from index
     */
    public void removeColumns(SheetDetails sheet, int startIndex) {

        System.out.println("Deleting columns from " + this.getColumnName(startIndex + 1) + " because they won't be used.");

        try {
            Request request = new Request()
                    .setDeleteDimension(new DeleteDimensionRequest()
                            .setRange(new DimensionRange()
                                    .setSheetId(sheet.getId())
                                    .setDimension("COLUMNS")
                                    .setStartIndex(startIndex)
                            )
                    );

            List<Request> requests = new ArrayList();
            requests.add(request);

            Sheets.Spreadsheets.BatchUpdate batchUpdate = service
                    .spreadsheets()
                    .batchUpdate(this.spreadsheet.getSpreadsheetId(), new BatchUpdateSpreadsheetRequest().setRequests(requests));
            batchUpdate.execute();
        } catch (IOException ex) {
            System.err.println("Error removing columns: " + ex.getMessage());
        }
    }

    /**
     * Update data.
     *
     * @param values
     * @param start
     * @param columns
     * @param rows
     */
    public void update(List<List<Object>> values, int start, int columns, int rows) {

        try {
            String rangeStart = this.sheetName + "!A" + start;
            String rangeEnd = getColumnName(columns) + rows;

            ValueRange body = new ValueRange().setValues(values);

            this.service
                    .spreadsheets()
                    .values()
                    .update(this.spreadsheet.getSpreadsheetId(), rangeStart + ":" + rangeEnd, body)
                    .setValueInputOption("USER_ENTERED")
                    .execute();

        } catch (IOException ex) {
            System.err.println("Error updating data: " + ex.getMessage());
        }
    }

    /**
     * Append New data.
     *
     * @param values
     * @param start
     * @param columns
     * @param rows
     * @throws java.io.IOException
     * @throws java.lang.InterruptedException
     */
    public void append(List<List<Object>> values, int start, int columns, int rows)
            throws IOException, InterruptedException {

        //Defines the exponential backoff for multiples retries.
        boolean retry = true;
        ExponentialBackOff backOff = new ExponentialBackOff.Builder()
                .setMaxElapsedTimeMillis(60 * 5 * 1000)
                .build();

        do {
            try {
                String rangeStart = this.sheetName + "!A" + start;
                String rangeEnd = getColumnName(columns) + rows;

                System.out.println("Appending cells range: " + rangeStart + ":" + rangeEnd);

                ValueRange body = new ValueRange().setValues(values);

                this.service
                        .spreadsheets()
                        .values()
                        .append(this.spreadsheet.getSpreadsheetId(), rangeStart + ":" + rangeEnd, body)
                        .setValueInputOption("USER_ENTERED")
                        .execute();

                retry = false;
            } catch (IOException ex) {
                long sleep = backOff.nextBackOffMillis();

                if (sleep == BackOff.STOP) {
                    retry = false;
                    System.err.println("Append cells failed after maximum elapsed millis: " + backOff.getMaxElapsedTimeMillis() + ", Error: " + ex.getMessage());

                } else {

                    System.err.println("Trying to recover of: " + ex.getMessage());
                    Thread.sleep(sleep);
                }
            }
        } while (retry);
    }

    /**
     * Get details about a sheet.
     *
     * @return
     */
    public SheetDetails getSheetDetails() {
        SheetDetails details = new SheetDetails();
        List<Sheet> sheetList = this.spreadsheet.getSheets();

        //Read sheets to get id, name and column count of a sheet.
        for (Sheet sheet : sheetList) {
            details.setName(sheet.getProperties().getTitle());

            if (details.getName().equalsIgnoreCase(this.sheetName)) {
                details.setId(sheet.getProperties().getSheetId());
                details.setColumnCount(sheet.getProperties().getGridProperties().getColumnCount());
                details.setRowCount(sheet.getProperties().getGridProperties().getRowCount());
                break;
            }
        }

        return details;
    }

    /**
     * Based on a column count, return the column name to use on Google
     * Spreadsheet.
     *
     * Logic taken from:
     * https://stackoverflow.com/questions/181596/how-to-convert-a-column-number-e-g-127-into-an-excel-column-e-g-aa?page=1&tab=votes#tab-top
     *
     * @param columnNumber
     * @return
     */
    public String getColumnName(int columnNumber) {
        int dividend = columnNumber;
        int i;
        String columnName = "";
        int modulo;
        while (dividend > 0) {
            modulo = (dividend - 1) % 26;
            i = 65 + modulo;
            columnName = new Character((char) i).toString() + columnName;
            dividend = (int) ((dividend - modulo) / 26);
        }
        return columnName;
    }

    /**
     * Identify if a sheet has values.
     *
     * @param sheet SheetDetails
     * @param startIndex Start index.
     * @return
     */
    public boolean hasValues(SheetDetails sheet, int startIndex) {
        try {
            String start = this.sheetName + "!A" + startIndex;
            String end = this.getColumnName(sheet.getColumnCount()) + sheet.getRowCount();

            //Get filled cells.
            ValueRange result = this.service
                    .spreadsheets()
                    .values()
                    .get(this.spreadsheet.getSpreadsheetId(), start + ":" + end)
                    .execute();
            return result.getValues() != null;

        } catch (IOException ex) {
            System.err.println("Error getting cells values: " + ex.getMessage());
        }

        return false;
    }

    /**
     * Get quantity of cells in all sheets, except target sheet.
     *
     * @return
     */
    public long getCellsCount() {
        List<Sheet> sheetList = this.spreadsheet.getSheets();
        int count = 0;

        for (Sheet sheet : sheetList) {
            if (!this.sheetName.equalsIgnoreCase(sheet.getProperties().getTitle())) {
                count = count + (sheet.getProperties().getGridProperties().getRowCount() * sheet.getProperties().getGridProperties().getColumnCount());
            }
        }
        return count;
    }

    /**
     * Gets spreadsheet title.
     *
     * @return
     */
    public String getSpreadsheetTitle() {
        return this.spreadsheet.getProperties().getTitle();
    }

    /**
     * Create a new spreadsheet.
     *
     * @param sheetName Logic taken from:
     * https://github.com/googleworkspace/java-samples/blob/master/sheets/snippets/src/main/java/SpreadsheetSnippets.java
     * @return
     * @throws java.io.IOException
     */
    public String createSpreadsheet(String sheetName) throws IOException {
        Sheets service = this.service;

        Spreadsheet spreadsheet = new Spreadsheet().setProperties(new SpreadsheetProperties()
                .setTitle(sheetName));
        spreadsheet = service.spreadsheets().create(spreadsheet)
                .setFields("spreadsheetID").execute();
        System.out.println("Spreadsheet ID: " + spreadsheet.getSpreadsheetId());
        return spreadsheet.getSpreadsheetId();
    }
}
