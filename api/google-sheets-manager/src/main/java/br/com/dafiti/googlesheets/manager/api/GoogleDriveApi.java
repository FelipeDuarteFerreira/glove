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

import com.google.api.client.auth.oauth2.Credential;
import com.google.api.client.extensions.java6.auth.oauth2.AuthorizationCodeInstalledApp;
import com.google.api.client.extensions.jetty.auth.oauth2.LocalServerReceiver;
import com.google.api.client.googleapis.auth.oauth2.GoogleAuthorizationCodeFlow;
import com.google.api.client.googleapis.auth.oauth2.GoogleClientSecrets;
import com.google.api.client.googleapis.batch.BatchRequest;
import com.google.api.client.googleapis.batch.json.JsonBatchCallback;
import com.google.api.client.googleapis.javanet.GoogleNetHttpTransport;
import com.google.api.client.googleapis.json.GoogleJsonError;
import com.google.api.client.http.HttpHeaders;
import com.google.api.client.http.HttpRequest;
import com.google.api.client.http.HttpRequestInitializer;
import com.google.api.client.http.javanet.NetHttpTransport;
import com.google.api.client.json.JsonFactory;
import com.google.api.client.json.jackson2.JacksonFactory;
import com.google.api.client.util.store.FileDataStoreFactory;
import com.google.api.services.drive.Drive;
import com.google.api.services.drive.DriveScopes;
import com.google.api.services.drive.model.File;
import com.google.api.services.drive.model.Permission;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.security.GeneralSecurityException;
import java.util.List;

/**
 *
 * @author Flávia Lima
 * @author Helio Leal
 */
public class GoogleDriveApi {

    private static final JsonFactory JSON_FACTORY = JacksonFactory.getDefaultInstance();
    private Drive service;

    /**
     * Authenticate on Google Drive API.
     *
     * @param credentials
     * @return GoogleDriveApi
     */
    public GoogleDriveApi authenticate(String credentials) {
        try {

            //Define the transport.
            NetHttpTransport httpTransport = GoogleNetHttpTransport.newTrustedTransport();

            //Load client secrets.
            GoogleClientSecrets clientSecrets = GoogleClientSecrets.load(JSON_FACTORY, new InputStreamReader(new FileInputStream(credentials)));

            //Set up authorization code flow for all authorization scopes.
            GoogleAuthorizationCodeFlow flow = new GoogleAuthorizationCodeFlow.Builder(httpTransport, JSON_FACTORY, clientSecrets, DriveScopes.all())
                    .setDataStoreFactory(new FileDataStoreFactory(new java.io.File(System.getProperty("user.home"), ".store/google_drive")))
                    .setAccessType("offline")
                    .build();

            //Authorize.
            Credential credential = new AuthorizationCodeInstalledApp(flow, new LocalServerReceiver()).authorize("user");

            //Build the service object.
            this.service = new Drive.Builder(httpTransport, JSON_FACTORY, this.setHttpTimeout(credential))
                    .setApplicationName("GLOVE - Google Drive API")
                    .build();

        } catch (GeneralSecurityException
                | IOException ex) {
            System.err.println("Error on authenticate: " + ex.getMessage());
        }

        return this;
    }

    /**
     * Set the Google Drive API timeout.
     *
     * @param requestInitializer
     * @return
     */
    private HttpRequestInitializer setHttpTimeout(final HttpRequestInitializer requestInitializer) {
        return (HttpRequest httpRequest) -> {
            requestInitializer.initialize(httpRequest);
            httpRequest.setConnectTimeout(5 * 60000);
            httpRequest.setReadTimeout(5 * 60000);
        };
    }

    /**
     * Clone a google drive file by its ID.
     *
     * @param id File id
     * @param newTitle New file title
     * @return Metadata of new file
     */
    public File copy(String id, String newTitle) {
        File metadata = null;

        try {
            File copyMetadata = new File().setName(newTitle);
            metadata = this.service.files().copy(id, copyMetadata).execute();

        } catch (IOException ex) {
            System.err.println("Error on copy: " + ex.getMessage());
        }

        return metadata;
    }

    /**
     * Copy permissions from one file to another
     *
     * @param from Origin file id.
     * @param to Target file id.
     */
    public void copyPermissions(String from, String to) {
        try {
            //Get permissions of the source file.
            List<Permission> permissions = this.service
                    .permissions()
                    .list(from)
                    .setFields("permissions/role,permissions/type,permissions/emailAddress")
                    .execute()
                    .getPermissions();

            //Handles the return.
            JsonBatchCallback<Permission> callback = new JsonBatchCallback<Permission>() {
                @Override
                public void onFailure(GoogleJsonError e,
                        HttpHeaders responseHeaders)
                        throws IOException {
                    // Handle error
                    System.err.println(e.getMessage());
                }

                @Override
                public void onSuccess(Permission permission,
                        HttpHeaders responseHeaders)
                        throws IOException {
                }
            };

            //Starts batch operation.
            BatchRequest batch = this.service.batch();

            //Fetchs source file permissions to copy them.
            for (Permission permission : permissions) {

                //Build permission object.
                Permission userPermission = new Permission()
                        .setType(permission.getType())
                        .setRole(permission.getRole())
                        .setEmailAddress(permission.getEmailAddress());

                //Put copy permission request to batch queue.
                this.service.permissions()
                        .create(to, userPermission)
                        .queue(batch, callback);

            }

            //Execute all operations.
            batch.execute();

        } catch (IOException ex) {
            System.err.println("Error on copy: " + ex.getMessage());
        }

    }
}
