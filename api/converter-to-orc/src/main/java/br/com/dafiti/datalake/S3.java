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
package br.com.dafiti.datalake;

import com.amazonaws.AmazonClientException;
import com.amazonaws.AmazonServiceException;
import com.amazonaws.services.s3.AmazonS3;
import com.amazonaws.services.s3.AmazonS3ClientBuilder;
import com.amazonaws.services.s3.transfer.Download;
import com.amazonaws.services.s3.transfer.Transfer.TransferState;
import com.amazonaws.services.s3.transfer.TransferManager;
import com.amazonaws.services.s3.transfer.TransferManagerBuilder;
import java.io.File;
import org.apache.commons.lang.StringUtils;

/**
 *
 * @author Valdiney V GOMES
 */
public class S3 {

    /**
     * Identify if a object exists.
     *
     * @param bucket Bucket.
     * @param object Object.
     * @return Identify if a object exists
     */
    public boolean exists(String bucket, String object) {
        AmazonS3 s3client = AmazonS3ClientBuilder.standard().build();
        return s3client.doesObjectExist(bucket, object);
    }

    /**
     * Download a object.
     *
     * @param bucket Bucket.
     * @param object Object.
     * @param outputFile Output file.
     * @return TransferState.
     * @throws InterruptedException
     */
    public TransferState downloadObject(String bucket, String object, File outputFile)
            throws AmazonServiceException, AmazonClientException, InterruptedException {
        TransferManager transferManager = TransferManagerBuilder.standard().build();
        Download download = transferManager.download(bucket, object, outputFile);
        download.waitForCompletion();
        transferManager.shutdownNow();
        return download.getState();
    }

    /**
     * Download a object.
     *
     * @param objectPath Bucket path.
     * @param objectName Object.
     * @param mode Mode
     * @param outputFile Output file.
     * @throws AmazonClientException
     * @throws AmazonServiceException
     * @throws InterruptedException
     * @throws Exception
     */
    public void downloadObject(String objectPath, String objectName, String mode, File outputFile)
            throws AmazonClientException, AmazonServiceException, InterruptedException, Exception {

        if (objectPath.startsWith("s3://")) {
            S3 s3 = new S3();
            String directory = objectPath.replace("s3://", "");
            String bucket = StringUtils.substringBefore(directory, "/");
            String path = StringUtils.substringAfter(directory, "/");
            StringBuilder object = new StringBuilder();

            //Identify the partition mode.
            if ("real".equalsIgnoreCase(mode)) {
                object
                        .append(path)
                        .append("partition_value=")
                        .append(StringUtils.substringBefore(objectName, "."))
                        .append("/")
                        .append(objectName);
            } else {
                object
                        .append(path)
                        .append(objectName);
            }

            if (s3.exists(bucket, object.toString())) {
                //Download original file from S3. 
                TransferState state = s3.downloadObject(bucket, object.toString(), outputFile);

                if (!state.equals(TransferState.Completed)) {
                    //Retry two times. 
                    for (int i = 0; i < 2; i++) {
                        state = s3.downloadObject(bucket, object.toString(), outputFile);

                        if (state.equals(TransferState.Completed)) {
                            break;
                        }
                    }

                    if (!state.equals(TransferState.Completed)) {
                        throw new Exception("Fail downloading object" + bucket + "/" + object.toString() + " with state " + state.name() + "!");
                    }
                }
            }
        }
    }
}
