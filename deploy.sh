#!/bin/sh

# keep package.json version updated
# setup chain details 
npx ts-node scripts/deploy/writeChainConfig.ts

# deploy contracts
npx hardhat run scripts/deploy/deploy.ts

# publish package
yarn build 

npm publish

# upload s3 config
npx ts-node scripts/rpcConfig/uploadS3Config.ts