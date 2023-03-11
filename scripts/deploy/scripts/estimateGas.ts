require("dotenv").config();
import axios from "axios";

const deployerAddr = "0x752B38FA38F53dF7fa60e6113CFd9094b7e040Aa";
const apiKey = process.env.POLYGONSCAN_API_KEY;
const startBlock = "39623757";
const endBlock = "39661457";
const gasPrice = 25;
const url = `https://api.polygonscan.com/api?module=account&action=txlist&address=${deployerAddr}&sort=asc&apikey=${apiKey}${
  startBlock ? "&startBlock=" + startBlock : ""
}${endBlock ? "&endBlock=" + endBlock : ""}`;

// This script queries a set of txn between `startBlock` and `endBlock`. The result is used to get the sum of gasUsed
// for all the txns. Final sum is multiplied with gasPrice to get the total cost required to simulate them on chain.
async function main() {
  const { data } = await axios.get(url);

  let total = 0;
  data.result.forEach((tx) => {
    total += parseInt(tx.gasUsed);
  });

  // adding up 10% for opcode diff and addresses
  total = Math.ceil(total + total * 0.1);

  const costInEth = (total * gasPrice) / 1000000000;
  console.log(costInEth);
}

main();
