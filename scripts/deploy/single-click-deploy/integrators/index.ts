import prompts from "prompts";

import { deploySocket } from "./deploySocket";
import { writeConfigs } from "./writeConfigs";

async function main() {
  const response = await prompts([
    {
      name: "option",
      type: "select",
      message: "What would you like to do?",
      choices: [
        {
          title: "Add chain configs",
          value: "add",
        },
        {
          title: "Deploy contracts",
          value: "deploy",
        },
        { title: "Exit", value: "exit" },
      ],
    },
  ]);

  switch (response.option) {
    case "add":
      await writeConfigs();
      break;
    case "deploy":
      await deploySocket();
      break;
    case "exit":
      process.exit(0);
  }
}

async function start() {
  while (true) {
    await main();
  }
}

(async () => {
  start();
})();
