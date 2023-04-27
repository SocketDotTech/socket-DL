npx hardhat run scripts/deploy/index.ts && 
npx ts-node scripts/deploy/checkRoles.ts && 
npx hardhat run scripts/deploy/configure.ts && 
npx hardhat run scripts/deploy/connect &&
npx hardhat run scripts/deploy/verify.ts
