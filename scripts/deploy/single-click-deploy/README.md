# Socket DL deployment

## Local Development

### Prereqs

- Hardhat
- Foundry
- NodeJS (Supported version: "^14.0.0 || ^16.0.0 || ^18.0.0")
- Yarn

### Setup

Clone project and install dependencies.

```bash=
# clone the repository
git clone https://github.com/SocketDotTech/socket-dl

# move to repository folder
cd socket-dl

# checkout to this branch
git checkout feat/write-enums

# install forge dependencies
forge install

# install node modules
yarn install
```

### Deploy

Deployments use [Hardhat](https://github.com/NomicFoundation/hardhat)

# Setup config and env:

    - Run command: `yarn setup` and select first option
    - Add all the required details, you can skip configs which are not required
    - Once done, go to .env and check if last owner address, rpc and private key are correctly set!

    - Next compile contracts, `npx hardhat compile`

# Deploy contracts:

    - Ensure you have enough balance in your account to deploy 10-12 contracts.
    - Next compile contracts, `npx hardhat compile`
    - Run command: `yarn setup` and select second option, this will deploy contracts and store them in `prod_addresses.json`.

# Create a PR:

    - Once contracts are deployed, push them to the repo and create a PR
    - contracts will be used by SOCKET to run the infra and connect them with existing deployments on other chains.
