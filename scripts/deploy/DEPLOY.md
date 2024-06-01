# Deployment

To deploy the entire setup, follow these steps:

- [Deploy Socket](#deploy-socket): deploy core contracts
- [Grant Roles](#grant-roles): grant roles for different actions (watcher/transmitter/executor/governance, etc.)
- [Configure](#configure): configure chains for their siblings
- [Connect](#connect): configure example counters to send messages to siblings
- [Verify setup](#verify-setup): queries contracts available in `${mode}_addresses.json` and checks if everything is set as expected.

There are three different modes for deployment (prod, dev, and surge) which are used in naming address JSON and selecting configurations. All deploy scripts use [config.ts](./config.ts).

### Set up .env

- Update .env file. See [.example.env](../.env.example).
- Check the following (important) -
  - deployment mode (dev,surge,prod)
  - socket signer private key (deployer)
  - socket owner address
  - RPCs
  - etherscan API keys (used for verification)
- Check if the blockchain is configured in `hardhat.config.ts`, if not add it.

### Setup overrides

Each blockchain has separate nuances when sending transaction. For example, ethers don't have proper gas estimation for type 2 transactions on polygon. Arbitrum has inconsistent gas limits. To add any overrides for these properties, add them in overrides object in `config.ts`.

### Deploy Socket

- Go to [config.ts](./config.ts) and configure:

  - The chains you want to deploy on in the `chains` array
  - The script checks the existing addresses in the `${mode}_addresses.json` file and deploys only if missing. Hence, clear the existing address if you want to redeploy. If deploying all the contracts again, replace current addresses with just empty json object ({}) in both `${mode}_addresses.json` and `${mode}_verification.json`.

- Run the script with the command:
  `npx hardhat run scripts/deploy/index.ts`

This script adds the addresses to `${mode}_addresses.json` and verification data to `${mode}_verification.json`. Contracts can be verified separately with the command: `npx hardhat run scripts/deploy/verify.ts`.

### Grant Roles

- For granting roles, the configuration uses the following variables:
  - `sendTransaction`: boolean (if the role is not set, should we send a transaction or not?)
  - `newRoleStatus`: boolean (the expected role status, should be true or false)
  - `filterChains`: ChainSlugs[] (the chains which you want to check/set the following roles for)
- Check the `mode` set in .env and update all the related addresses in [config.ts](./config.ts):
  - `executorAddresses`
  - `transmitterAddresses`
  - `watcherAddresses`
- Run the script with the command:
  `npx hardhat run scripts/deploy/checkRoles.ts`

### Configure

- To run this script, make sure the contracts exist in `${mode}_addresses.json`
- Run the script with the command:
  `npx hardhat run scripts/deploy/configure.ts`

This script:

- registers all the switchboards deployed on socket for all the siblings and updates the capacitor and decapacitor addresses in deployments JSON.
- updates the msg value min/max thresholds in ExecutionManager
- updates transmitManager and executionManager address in socket
- updates the remote switchboard addresses for native switchboards

### Connect

- To run this script, make sure the contract addresses and your plug (as "Counter") exist in `${mode}_addresses.json`
- Run the script with the command:
  `npx hardhat run scripts/deploy/connect.ts`

This script connects the plugs to their siblings for all the chains that exist in the `integrations` object for that chain.

### Verify Setup

- To run this script, make sure the contract addresses exist in `${mode}_verification.json`
- Run the script with the command:
  `npx hardhat run scripts/deploy/verifyDeployments.ts`

The output will show if all the configurations are set properly.
