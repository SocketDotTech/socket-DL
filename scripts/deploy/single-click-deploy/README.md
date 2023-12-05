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

# install forge dependencies
forge install

# install node modules
yarn install
```

### Deploy

Deployments use [Hardhat](https://github.com/NomicFoundation/hardhat)

# Setup config and env:

    - Run command: `yarn setup` and select first option `Add chain configs`.
    - Add all the required details, you can skip configs which are not required by leaving blank and pressing enter.
    - Once done, go to .env and check if owner address, rpc and private key are correctly set!

    - Next compile contracts, `npx hardhat compile`

# Deploy contracts:

    - Ensure you have enough balance in your account to deploy 10-12 contracts.
    - Next compile contracts, `npx hardhat compile`
    - Run command: `yarn setup` and select second option, this will deploy contracts and store them in `prod_addresses.json`.

# Create a PR:

    - Once contracts are deployed, push them to the repo and create a PR
    - contracts will be used by SOCKET to run the infra and connect them with existing deployments on other chains.

# FAQ:

    - max msg value transfer limit: Socket DL supports native asset bridge between 2 chains, the max value which can be bridged is controlled by this value.

    - timeout: Socket DL supports Fast and Optimistic Switchboards which has 1/n trust assumption from watchers, find more here https://developer.socket.tech/Learn/Components/Switchboards.
    In case no one trips a packet in this timeout period, the switchboard considers the packet valid. Socket DL assumes it to be 2 hrs by default.

# Note:

Transactions are reverting with insufficient balance or other gas problems:
Go to `chainConfig.json` present in the root. You can configure overrides there which are used in all the transactions going through.

    For example:
    ```
    "overrides": {
      "type": 1,
      "gasLimit": 20000000,
      "gasPrice": 1000000000000
    }
    ```
