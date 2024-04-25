import { PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import * as fs from "fs";
import { DeploymentMode, TxData } from "../../src";
import dotenv from "dotenv";
import { generateDevConfig, generateProdConfig } from "./rpcConfig";
import { getTxData } from "./txdata-builder/generate-calldata";
dotenv.config();

const deploymentMode = process.env.DEPLOYMENT_MODE as DeploymentMode;
const s3Client = new S3Client({
  region: "us-east-1",
});

// File path for the JSON file
const fileName = deploymentMode + "RpcConfig.json";
const localFilePath = fileName;

const bucketName = "socket-ll-" + deploymentMode;
const s3FileKey = fileName; // File key in S3

const createConfig = async () => {
  console.log("getting tx data");
  const txData: TxData = await getTxData();

  console.log("generating config");
  const config =
    deploymentMode === "prod"
      ? await generateProdConfig(txData)
      : await generateDevConfig(txData);
  const jsonString = JSON.stringify(config, null, 2); // Use null and 2 for pretty formatting

  // Write the JSON string to the local file
  fs.writeFileSync(localFilePath, jsonString);
};

const uploadToS3 = async () => {
  try {
    await createConfig();
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

// npx ts-node scripts/rpcConfig/uploadS3Config.ts
uploadToS3();
