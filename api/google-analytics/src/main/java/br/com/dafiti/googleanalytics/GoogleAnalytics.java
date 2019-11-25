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
package br.com.dafiti.googleanalytics;

import br.com.dafiti.mitt.Mitt;
import br.com.dafiti.mitt.cli.CommandLineInterface;
import br.com.dafiti.mitt.exception.DuplicateEntityException;
import br.com.dafiti.mitt.transformation.embedded.Concat;
import br.com.dafiti.mitt.transformation.embedded.Now;
import com.google.api.client.auth.oauth2.Credential;
import com.google.api.client.extensions.java6.auth.oauth2.AuthorizationCodeInstalledApp;
import com.google.api.client.extensions.jetty.auth.oauth2.LocalServerReceiver;

import com.google.api.client.googleapis.auth.oauth2.GoogleAuthorizationCodeFlow;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.client.json.gson.GsonFactory;
import com.google.api.client.util.store.FileDataStoreFactory;
import com.google.api.services.analyticsreporting.v4.AnalyticsReporting;
import com.google.api.services.analyticsreporting.v4.AnalyticsReportingScopes;
import com.google.api.services.analyticsreporting.v4.model.ColumnHeader;
import com.google.api.services.analyticsreporting.v4.model.DateRange;
import com.google.api.services.analyticsreporting.v4.model.DateRangeValues;
import com.google.api.services.analyticsreporting.v4.model.Dimension;
import com.google.api.services.analyticsreporting.v4.model.GetReportsRequest;
import com.google.api.services.analyticsreporting.v4.model.GetReportsResponse;
import com.google.api.services.analyticsreporting.v4.model.Metric;
import com.google.api.services.analyticsreporting.v4.model.MetricHeaderEntry;
import com.google.api.services.analyticsreporting.v4.model.ReportRequest;
import com.google.api.services.analyticsreporting.v4.model.ReportRow;
import java.io.FileInputStream;
import java.io.File;
import java.io.IOException;
import java.io.InputStreamReader;
import java.security.GeneralSecurityException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.logging.Level;
import java.util.logging.Logger;

/**
 *
 * @author Valdiney V GOMES
 */
public class GoogleAnalytics {

    private static final String APPLICATION_NAME = "Google Analytics Reporting (V4)";
    private static final JsonFactory JSON_FACTORY = GsonFactory.getDefaultInstance();

    public static void main(String[] args) {
        //Defines a MITT instance. 
        Mitt mitt = new Mitt();

        try {
            Logger.getLogger(GoogleAnalytics.class.getName()).log(Level.INFO, "GLOVE - Google Analytics Extractor started");

            //Defines parameters.
            mitt.getConfiguration()
                    .addParameter("c", "client_secret", "Client secrets json file path", "", true, false)
                    .addParameter("v", "view_id", "Google analytics project view ID", "", true, false)
                    .addParameter("s", "start_date", "Start date", "", true, false)
                    .addParameter("e", "end_date", "End date", "", true, false)
                    .addParameter("d", "dimensions", "Dimensions, divided by + if has more than one", "", true, false)
                    .addParameter("m", "metrics", "Metrics, divided by + if has more than one", "", true, false)
                    .addParameter("o", "output", "Output file", "", true, false)
                    .addParameter("p", "partition", "(Optional)  Partition, divided by + if has more than one")
                    .addParameter("k", "key", "(Optional) Unique key, divided by + if has more than one", "");

            //Read the command line interface. 
            CommandLineInterface cli = mitt.getCommandLineInterface(args);

            //Defines output file.
            mitt.setOutput(cli.getParameter("output"));

            //Defines fields.
            mitt.getConfiguration()
                    .addCustomField("partition_field", new Concat((List) cli.getParameterAsList("partition", "\\+")))
                    .addCustomField("custom_primary_key", new Concat((List) cli.getParameterAsList("key", "\\+")))
                    .addCustomField("etl_load_date", new Now())
                    .addField("start_date")
                    .addField("end_date")
                    .addField("view_id")
                    .addField(cli.getParameterAsList("dimensions", "\\+"))
                    .addField(cli.getParameterAsList("metrics", "\\+"));

            //Define the transport.
            NetHttpTransport httpTransport = GoogleNetHttpTransport.newTrustedTransport();

            //Load client secrets.
            GoogleClientSecrets clientSecrets = GoogleClientSecrets.load(JSON_FACTORY, new InputStreamReader(new FileInputStream((String) cli.getParameter("client_secret"))));

            //Set up authorization code flow for all authorization scopes.
            GoogleAuthorizationCodeFlow flow = new GoogleAuthorizationCodeFlow.Builder(httpTransport, JSON_FACTORY, clientSecrets, AnalyticsReportingScopes.all())
                    .setDataStoreFactory(new FileDataStoreFactory(new File(System.getProperty("user.home"), ".store/google_analytics_reporting")))
                    .build();

            //Authorize.
            Credential credential = new AuthorizationCodeInstalledApp(flow, new LocalServerReceiver()).authorize("user");

            //Construct the Analytics GoogleAnalytics service object.
            AnalyticsReporting service = new AnalyticsReporting.Builder(httpTransport, JSON_FACTORY, credential)
                    .setApplicationName(APPLICATION_NAME)
                    .build();

            //Create the DateRange object.
            DateRange dateRange = new DateRange();
            dateRange.setStartDate((String) cli.getParameter("start_date"));
            dateRange.setEndDate((String) cli.getParameter("end_date"));

            //Create the Dimensions object.
            List<Dimension> dimensions = new ArrayList();

            cli.getParameterAsList("dimensions", "\\+").forEach((dimension) -> {
                dimensions.add(new Dimension().setName(dimension));
            });

            //Create the Metrics object.
            List<Metric> metrics = new ArrayList();

            cli.getParameterAsList("metrics", "\\+").forEach((metric) -> {
                metrics.add(new Metric().setExpression(metric));
            });

            //Create the ReportRequest object.
            ReportRequest request = new ReportRequest()
                    .setViewId((String) cli.getParameter("view_id"))
                    .setDateRanges(Arrays.asList(dateRange))
                    .setDimensions(dimensions)
                    .setMetrics(metrics);

            ArrayList<ReportRequest> requests = new ArrayList();
            requests.add(request);

            //Create the GetReportsRequest object.
            GetReportsRequest getReport = new GetReportsRequest().setReportRequests(requests);

            //Call the batchGet method.
            GetReportsResponse response = service.reports().batchGet(getReport).execute();

            //Reads the response.
            response.getReports().forEach((report) -> {
                ColumnHeader header = report.getColumnHeader();
                List<MetricHeaderEntry> metricHeaders = header.getMetricHeader().getMetricHeaderEntries();
                List<ReportRow> rows = report.getData().getRows();

                if (rows == null) {
                    Logger.getLogger(GoogleAnalytics.class.getName()).log(Level.INFO, "No data found for {0} in interval {1} and {2}", new Object[]{(String) cli.getParameter("view_id"), dateRange.getStartDate(), dateRange.getEndDate()});
                    return;
                }

                //Reads each report row.
                rows.forEach((row) -> {
                    ArrayList<Object> record = new ArrayList();

                    //Writes parameters.                    
                    record.add(dateRange.getStartDate());
                    record.add(dateRange.getEndDate());
                    record.add((String) cli.getParameter("view_id"));

                    //Writes dimensions.
                    row.getDimensions().forEach((dimension) -> {
                        record.add(dimension);
                    });

                    //Writes metrics.
                    List<DateRangeValues> reportMetrics = row.getMetrics();

                    for (int i = 0; i < reportMetrics.size(); i++) {
                        DateRangeValues values = reportMetrics.get(i);
                        for (int j = 0; j < values.getValues().size() && j < metricHeaders.size(); j++) {
                            record.add(values.getValues().get(j));
                        }
                    }

                    mitt.write(record);
                });
            });
        } catch (DuplicateEntityException
                | IOException
                | GeneralSecurityException ex) {

            Logger.getLogger(GoogleAnalytics.class.getName()).log(Level.SEVERE, "Google Analytics Reporting fail: ", ex);
            System.exit(1);
        } finally {
            mitt.close();
            Logger.getLogger(GoogleAnalytics.class.getName()).log(Level.INFO, "GLOVE - Google Analytics Extractor finished");
        }
    }
}
