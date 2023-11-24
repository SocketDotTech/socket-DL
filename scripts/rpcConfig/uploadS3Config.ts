import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import * as fs from "fs";
import { DeploymentMode } from "../../src";
import dotenv from "dotenv";
import { config } from "./rpcConfig";
dotenv.config();

const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;

const s3Client = new S3Client({
  region: "us-east-1",
});

const jsonString = JSON.stringify(config, null, 2); // Use null and 2 for pretty formatting

// File path for the JSON file
const fileName = deploymentMode + "RpcConfig.json";
const localFilePath = fileName;

// Write the JSON string to the local file
fs.writeFileSync(localFilePath, jsonString);

const bucketName = "socket-dl-" + deploymentMode;
const s3FileKey = fileName; // File key in S3

const uploadToS3 = async () => {
  try {
    const fileBuffer = fs.readFileSync(localFilePath);

    // Create an S3 PUT operation command
    const putObjectCommand = new PutObjectCommand({
      Bucket: bucketName,
      Key: s3FileKey,
      Body: fileBuffer,
      ContentType: "application/json",
    });

    // Execute the command and get the response
    const s3Response = await s3Client.send(putObjectCommand);

    console.log(
      `File uploaded to S3. ETag: ${s3Response.ETag} mode : ${deploymentMode}`
    );
  } catch (error) {
    console.error("Error uploading data to S3:", error);
  }
};

uploadToS3();


// npx ts-node scripts/rpcConfig/uploadS3Config.ts