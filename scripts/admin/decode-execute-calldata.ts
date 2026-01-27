import { ethers } from "ethers";
import SocketArtifact from "../../out/Socket.sol/Socket.json";

const calldata1 =
  "0x275c41c9000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001800000a4b129ebc834d24af22b9466a4150425354998c3e800000000000000cbe600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000041a20c9a07a47f49b70e42f8aad9c3990f6393f4d068bb825ee6e59dc7eff95cff6e38a2a151d7f55df20af5339c8d5e7b7aadbddee6fbbb760f8ea957de8c72771b000000000000000000000000000000000000000000000000000000000000000000a4b126e5ce884875ea3776a57f0b225b1ea8d2e9beeb00000000000608cb000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000008cb4c89cc297e07c7a309af8b16cc2f5f62a3b1300000000000000000000000000000000000000000000000000000000062ebe4d";

const calldata2 =
  "0x275c41c9000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001800000a4b129ebc834d24af22b9466a4150425354998c3e800000000000000cbe600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030d4000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000418bcb00358fcd84308ba164116edb8d4e38edee4a72ebada016feb4188baedbb23e411b394c91fccf6dce30b21a5ecdb12d747df590d9ccd804803210373c23071c000000000000000000000000000000000000000000000000000000000000000000a4b126e5ce884875ea3776a57f0b225b1ea8d2e9beeb00000000000608cb0000000000000000000000000000000000000000000000000000007cedc515b500000000000000000000000000000000000000000000000000000000000186a0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000400000000000000000000000008cb4c89cc297e07c7a309af8b16cc2f5f62a3b1300000000000000000000000000000000000000000000000000000000062ebe4d";

const socketInterface = new ethers.utils.Interface(SocketArtifact.abi);

console.log("=== CALLDATA 1 ===\n");
try {
  const decoded1 = socketInterface.decodeFunctionData("execute", calldata1);
  console.log("ExecutionDetails:");
  console.log("  packetId:", decoded1.executionDetails_.packetId);
  console.log(
    "  proposalCount:",
    decoded1.executionDetails_.proposalCount.toString()
  );
  console.log(
    "  executionGasLimit:",
    decoded1.executionDetails_.executionGasLimit.toString()
  );
  console.log(
    "  decapacitorProof:",
    decoded1.executionDetails_.decapacitorProof
  );
  console.log("  signature:", decoded1.executionDetails_.signature);
  console.log("\nMessageDetails:");
  console.log("  msgId:", decoded1.messageDetails_.msgId);
  console.log(
    "  executionFee:",
    decoded1.messageDetails_.executionFee.toString()
  );
  console.log(
    "  minMsgGasLimit:",
    decoded1.messageDetails_.minMsgGasLimit.toString()
  );
  console.log("  executionParams:", decoded1.messageDetails_.executionParams);
  console.log("  payload:", decoded1.messageDetails_.payload);
} catch (e: any) {
  console.error("Error decoding:", e.message);
}

console.log("\n=== CALLDATA 2 ===\n");
try {
  const decoded2 = socketInterface.decodeFunctionData("execute", calldata2);
  console.log("ExecutionDetails:");
  console.log("  packetId:", decoded2.executionDetails_.packetId);
  console.log(
    "  proposalCount:",
    decoded2.executionDetails_.proposalCount.toString()
  );
  console.log(
    "  executionGasLimit:",
    decoded2.executionDetails_.executionGasLimit.toString()
  );
  console.log(
    "  decapacitorProof:",
    decoded2.executionDetails_.decapacitorProof
  );
  console.log("  signature:", decoded2.executionDetails_.signature);
  console.log("\nMessageDetails:");
  console.log("  msgId:", decoded2.messageDetails_.msgId);
  console.log(
    "  executionFee:",
    decoded2.messageDetails_.executionFee.toString()
  );
  console.log(
    "  minMsgGasLimit:",
    decoded2.messageDetails_.minMsgGasLimit.toString()
  );
  console.log("  executionParams:", decoded2.messageDetails_.executionParams);
  console.log("  payload:", decoded2.messageDetails_.payload);
} catch (e: any) {
  console.error("Error decoding:", e.message);
}

console.log("\n=== DIFFERENCES ===\n");
try {
  const decoded1 = socketInterface.decodeFunctionData("execute", calldata1);
  const decoded2 = socketInterface.decodeFunctionData("execute", calldata2);

  // Compare ExecutionDetails
  if (
    decoded1.executionDetails_.packetId !== decoded2.executionDetails_.packetId
  ) {
    console.log("❌ packetId differs");
    console.log("  Calldata 1:", decoded1.executionDetails_.packetId);
    console.log("  Calldata 2:", decoded2.executionDetails_.packetId);
  } else {
    console.log("✓ packetId matches");
  }

  if (
    !decoded1.executionDetails_.proposalCount.eq(
      decoded2.executionDetails_.proposalCount
    )
  ) {
    console.log("❌ proposalCount differs");
    console.log(
      "  Calldata 1:",
      decoded1.executionDetails_.proposalCount.toString()
    );
    console.log(
      "  Calldata 2:",
      decoded2.executionDetails_.proposalCount.toString()
    );
  } else {
    console.log("✓ proposalCount matches");
  }

  if (
    !decoded1.executionDetails_.executionGasLimit.eq(
      decoded2.executionDetails_.executionGasLimit
    )
  ) {
    console.log("❌ executionGasLimit differs");
    console.log(
      "  Calldata 1:",
      decoded1.executionDetails_.executionGasLimit.toString()
    );
    console.log(
      "  Calldata 2:",
      decoded2.executionDetails_.executionGasLimit.toString()
    );
  } else {
    console.log("✓ executionGasLimit matches");
  }

  if (
    decoded1.executionDetails_.decapacitorProof !==
    decoded2.executionDetails_.decapacitorProof
  ) {
    console.log("❌ decapacitorProof differs");
    console.log("  Calldata 1:", decoded1.executionDetails_.decapacitorProof);
    console.log("  Calldata 2:", decoded2.executionDetails_.decapacitorProof);
  } else {
    console.log("✓ decapacitorProof matches");
  }

  if (
    decoded1.executionDetails_.signature !==
    decoded2.executionDetails_.signature
  ) {
    console.log("❌ signature differs");
    console.log("  Calldata 1:", decoded1.executionDetails_.signature);
    console.log("  Calldata 2:", decoded2.executionDetails_.signature);
  } else {
    console.log("✓ signature matches");
  }

  // Compare MessageDetails
  if (decoded1.messageDetails_.msgId !== decoded2.messageDetails_.msgId) {
    console.log("❌ msgId differs");
    console.log("  Calldata 1:", decoded1.messageDetails_.msgId);
    console.log("  Calldata 2:", decoded2.messageDetails_.msgId);
  } else {
    console.log("✓ msgId matches");
  }

  if (
    !decoded1.messageDetails_.executionFee.eq(
      decoded2.messageDetails_.executionFee
    )
  ) {
    console.log("❌ executionFee differs");
    console.log(
      "  Calldata 1:",
      decoded1.messageDetails_.executionFee.toString()
    );
    console.log(
      "  Calldata 2:",
      decoded2.messageDetails_.executionFee.toString()
    );
  } else {
    console.log("✓ executionFee matches");
  }

  if (
    !decoded1.messageDetails_.minMsgGasLimit.eq(
      decoded2.messageDetails_.minMsgGasLimit
    )
  ) {
    console.log("❌ minMsgGasLimit differs");
    console.log(
      "  Calldata 1:",
      decoded1.messageDetails_.minMsgGasLimit.toString()
    );
    console.log(
      "  Calldata 2:",
      decoded2.messageDetails_.minMsgGasLimit.toString()
    );
  } else {
    console.log("✓ minMsgGasLimit matches");
  }

  if (
    decoded1.messageDetails_.executionParams !==
    decoded2.messageDetails_.executionParams
  ) {
    console.log("❌ executionParams differs");
    console.log("  Calldata 1:", decoded1.messageDetails_.executionParams);
    console.log("  Calldata 2:", decoded2.messageDetails_.executionParams);
  } else {
    console.log("✓ executionParams matches");
  }

  if (decoded1.messageDetails_.payload !== decoded2.messageDetails_.payload) {
    console.log("❌ payload differs");
    console.log("  Calldata 1:", decoded1.messageDetails_.payload);
    console.log("  Calldata 2:", decoded2.messageDetails_.payload);
  } else {
    console.log("✓ payload matches");
  }
} catch (e: any) {
  console.error("Error comparing:", e.message);
}
