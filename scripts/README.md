# Deployment

### Deploy:

1. Check if the blockchain is configured in `hardhat.config.ts`, if not add it.
2. Update `config.ts` for following:
  - attester address (for both source and destination)
  - executor address (for both source and destination)
  - timeout (time after which message will execute for attested packets if slow path)
  - totalRemoteChains (add destination chains for source getting deployed)
3. Run command `npx hardhat run --network <network-name> srcipts/deploy.ts`

For all chains, update the totalRemoteChains in `config.ts` and repeat step 3.

### Configure:

1. You will find addresses stored in deployments folder as json with file name same as chainid.
2. In the `config.ts`, update the `remoteChainId` for the chain you want to configure.
3. Run command `npx hardhat run --network <network-name> srcipts/configure.ts`.

For all chains, update the remoteChainId in `config.ts` and repeat step 3.