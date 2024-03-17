import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import * as fs from "fs";
import { DeploymentMode } from "../../src";
import dotenv from "dotenv";
import { config, publicConfig } from "./rpcConfig";
dotenv.config();

const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;

const s3Client = new S3Client({
  region: "us-east-1",
});

// File path for the JSON file
const fileName = deploymentMode + "RpcConfig.json";
const publicFileName = deploymentMode + "PublicConfig.json";

const bucketName = "socket-dl-" + deploymentMode;
const pubicBucketName = "socket-dl-" + deploymentMode + "-public";

const uploadToS3 = async (
  config: Object,
  bucketName: string,
  fileName: string
) => {
  try {
    const jsonString = JSON.stringify(config, null, 2); // Use null and 2 for pretty formatting

    // Write the JSON string to the local file
    fs.writeFileSync(fileName, jsonString);
    const fileBuffer = fs.readFileSync(fileName);

    // Create an S3 PUT operation command
    const putObjectCommand = new PutObjectCommand({
      Bucket: bucketName,
      Key: fileName,
      Body: fileBuffer,
      ContentType: "application/json",
    });

    // Execute the command and get the response
    const s3Response = await s3Client.send(putObjectCommand);

    console.log(
      `${fileName} File uploaded to S3. ETag: ${s3Response.ETag} mode : ${deploymentMode}`
    );
  } catch (error) {
    console.error("Error uploading data to S3:", error);
  }
};

uploadToS3(config, bucketName, fileName);
uploadToS3(publicConfig, pubicBucketName, publicFileName);

// npx ts-node scripts/rpcConfig/uploadS3Config.ts
