import { arrayify, defaultAbiCoder, keccak256 } from "ethers/lib/utils";

const createSignature = async (digest, signer) => {
  return await signer.signMessage(arrayify(digest));
};

const createDigest = (sigIdentifier, srcSlug, dstSlug, nonce, gasLimit) => {
  return keccak256(
    defaultAbiCoder.encode(
      ["string", "uint256", "uint256", "uint256", "uint256"],
      [sigIdentifier, srcSlug, dstSlug, nonce, gasLimit]
    )
  );
};

export { createSignature, createDigest };
