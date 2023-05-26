npx hardhat run scripts/deploy/index.ts  && 
npx ts-node scripts/deploy/checkRoles.ts --no-compile && 
npx hardhat run scripts/deploy/configure.ts --no-compile && 
npx hardhat run scripts/deploy/connect.ts --no-compile &&
npx hardhat run scripts/deploy/verify.ts --no-compile
