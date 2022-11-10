# Socket DL
The smart contracts that power the Data Layer of [Socket](https://socket.tech/). Socket DL is a protocol for generic message passing between chains. It has been designed to be highly configurable so that dapps (plugs) can choose the best tradeoffs for specific use cases.

## Local Development

### Prereqs
- Foundry
- NodeJS
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

### Project Layout
```
├── lib
│   └── forge-std - forge dependencies installed as git submodules
|
├── src
│   └── Contract.sol - Core contracts
|
└── test
|   └── Contract.t.sol - Tests for core contracts
|
└── Files for project setup
```

### Lint
Linter is run automatically before each commit.
It can also be triggered manually using yarn lint script.
```bash=
yarn lint
```

### Test
Tests are run using the [Forge](https://github.com/foundry-rs/foundry/tree/master/forge) tool of [Foundry](https://github.com/foundry-rs/foundry).
```bash=
forge test
```

### Deploy
Deployments use [Hardhat](https://github.com/NomicFoundation/hardhat)

Local deployments:
```bash=
npx hardhat run scripts/deploy.ts
```
- This will store addresses in deployments/ folder in root which are used to configure the contracts later for each remote chain.

### Publish

To publish, make sure contracts are compiled, run `yarn abi`. Then publish as normal.

### IDE Setup
It is recommended to setup the ide to work with solidity development. In case of VSCode, [Solidity](https://marketplace.visualstudio.com/items?itemName=JuanBlanco.solidity) and [Prettier](https://marketplace.visualstudio.com/items?itemName=esbenp.prettier-vscode) plugins should work best when configured using following settings -
```json=
{
    "solidity.compileUsingRemoteVersion": "v0.8.15+commit.e14f2714",
    "solidity.packageDefaultDependenciesContractsDirectory": "src",
    "solidity.packageDefaultDependenciesDirectory": "lib",
    "editor.formatOnSave": true,
    "[solidity]": {
        "editor.tabSize": 4,
        "editor.defaultFormatter": "esbenp.prettier-vscode"
    },
    "solidity.remappings": [
        "forge-std/=lib/forge-std/src/",
        "ds-test/=lib/forge-std/lib/ds-test/src/"
    ],
}
```

## Contributing
We really appreciate and value any form of contribution to Socket Data Layer Contracts. As a contributor, you are expected to fork this repository, work on your own fork and then submit pull requests. The PRs are expected to have a proper description to make reviewing easy. The code is expected to be properly linted and tested.

Smart contracts manage value and are highly vulnerable to errors and attacks. We have very strict guidlines, please make sure to follow these -

### Simple and Modular
We look for small files, small contracts, and small functions. If you can separate a contract into two independent functionalities you should probably do it.

### Naming Matters
We take our time with picking names. Code is going to be written once, and read hundreds of times. Renaming for clarity is encouraged. If any function or variable changes its intention, an accompanying name change is expected.

### Tests
Write tests for all your code. We encourage Test Driven Development so we know when our code is right. When writing tests ask yourself what is expected to be true before and after a function call. And perform explicit checks for those conditions. Write helper functions to make the tests as short and concise as possible.

### Code Consistency
The codebase should be as unified as possible. Read existing code and get inspired before you write your own. Don’t hesitate to ask for help on how to best write a specific piece of code.

### Code Style
In order to be consistent with all the other Solidity projects, we follow the official recommendations documented in the [Solidity style guide](https://docs.soliditylang.org/en/latest/style-guide.html).
Any exception or additions specific to our project are documented below.
- Try to avoid acronyms and abbreviations.
- All state variables should be private/internal. Write explicit getter functions where needed.
- All private and internal variables/functions should have an underscore prefix.
```solidity=
uint256 private _foo;
function _bar() internal {
    ...
}
```

- All function parameters should have an underscore postfix.
```solidity=
function foo(uint256 bar_) external {
    ...
}
```

- Contract instances should have double underscore postfix.
```solidity=
function foo() external {
    Bar bar__ = Bar(barAddress);
}
```

- Events should be emitted immediately after the state change that they represent, and consequently they should be named in past tense (when not in conflict with defined standard eg. ERC20).
```solidity=
function _burn(address who, uint256 value) internal {
    super._burn(who, value);
    emit TokensBurned(who, value);
}
```
