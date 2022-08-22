-include .env

# read json
define readSocketDeployments
$(shell node -p "require('./broadcast/Socket.s.sol/${1}/run-latest.json').transactions[${2}].contractAddress")
endef

define readDeployments
$(shell node -p "require('./deployments/${1}-${2}.json').deployedTo")
endef


# deployment
deploy :; @forge script scripts/${contract}.s.sol:Deploy${contract} --rpc-url ${rpc}  --private-key ${pk} --broadcast #--verify --etherscan-api-key ${etherscanApiKey}  -vvvv
create :; @forge create --json --rpc-url ${rpc}  --private-key ${pk} src/examples/${contract}.sol:${contract} --constructor-args ${constructorArgs}
#needs srcChainId
deploy-all :; make deploy contract=Socket rpc=${RINKEBY_RPC_URL} etherscanApiKey=${ETHERSCAN_API_KEY} pk=${SOCKET_OWNER_PRIVATE_KEY} && make create contract=Counter rpc=${RINKEBY_RPC_URL} etherscanApiKey=${ETHERSCAN_API_KEY} pk=${PLUG_OWNER_PRIVATE_KEY} constructorArgs=$(call readSocketDeployments,${srcChainId},1) | tee deployments/plug-${srcChainId}.json && make create contract=Counter rpc=${RINKEBY_RPC_URL} etherscanApiKey=${ETHERSCAN_API_KEY} pk=${PLUG_OWNER_PRIVATE_KEY} constructorArgs=$(call readSocketDeployments,${srcChainId},1) | tee deployments/verifier-${srcChainId}.json

# config
add-pauser :; cast send --private-key ${PLUG_OWNER_PRIVATE_KEY} $(call readDeployments,verifier,${srcChainId}) "AddPauser(address,uint256)" ${PAUSER_ADDRESS} ${destChainId}
set-config :; cast send --private-key ${PLUG_OWNER_PRIVATE_KEY} $(call readDeployments,plug,${srcChainId}) "setSocketConfig(uint256,address,address,address,bool)" ${destChainId} $(call readDeployments,verifier,${destChainId}) $(call readSocketDeployments,${srcChainId},5) $(call readSocketDeployments,${srcChainId},6) $(call verifier) ${IS_SEQUENTIAL} 
init-pauser :; cast send --private-key ${PAUSER_PRIVATE_KEY} $(call readDeployments,verifier,${srcChainId}) "Activate(uint256)" ${destChainId}
# needs srcChainId, destChainId
config :; make add-pauser && make set-config && make init-pauser