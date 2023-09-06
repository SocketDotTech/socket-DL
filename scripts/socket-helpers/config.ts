export const addresses = {
  "10": {
    USDC: {
      connectors: {
        "2999": {
          FAST: "0x1812ff6bd726934f18159164e2927B34949B16a8",
        },
      },
    },
  },
  "2999": {
    USDC: {
      connectors: {
        "10": {
          FAST: "0x7b9ed5C43E87DAFB03211651d4FA41fEa1Eb9b3D",
        },
        "42161": {
          FAST: "0x73019b64e31e699fFd27d54E91D686313C14191C",
        },
      },
    },
  },
  "42161": {
    USDC: {
      connectors: {
        "2999": {
          FAST: "0x69Adf49285c25d9f840c577A0e3cb134caF944D3",
        },
      },
    },
  },
};

export const srcChainSlug = 2999;
export const dstChainSlug = 42161;
