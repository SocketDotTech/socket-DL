#!/bin/bash

npx hardhat run scripts/deploy/1-deploy.ts && 
npx ts-node scripts/deploy/2-check-roles.ts --no-compile && 
npx hardhat run scripts/deploy/3-configure.ts --no-compile && 
# npx hardhat run scripts/deploy/4-connect.ts --no-compile &&
npx hardhat run scripts/deploy/5-verify.ts --no-compile
