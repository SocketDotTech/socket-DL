import { ethers, Signer } from "ethers";
import TrezorConnect, {
  DEVICE,
  DEVICE_EVENT,
  TRANSPORT,
  TRANSPORT_EVENT,
  UI,
  UI_EVENT,
  UI_RESPONSE,
} from "@trezor/connect";
import createPrompt from "prompt-sync";
import { Device } from "@trezor/connect/lib/device/Device";

class TrezorSigner extends Signer {
  public provider: ethers.providers.Provider;

  constructor(provider: ethers.providers.Provider) {
    super();
    this.provider = provider;

    TrezorConnect.init({
      popup: false, // render your own UI
      debug: false, // see what's going on inside connect
      manifest: {
        email: "support@kinto.xyz",
        appUrl: "kinto.xyz",
      },
      // transports: ['BridgeTransport'],
    })
      .then(() => {
        // console.log("Trezor is ready!");
      })
      .catch((error) => {
        console.log(error.message);
      });

    TrezorConnect.on(TRANSPORT_EVENT, (event) => {
      if (event.type === TRANSPORT.ERROR) {
        console.log("Transport is missing");
      }
      if (event.type === TRANSPORT.START) {
        // console.log(event);
      }
    });

    TrezorConnect.on(DEVICE_EVENT, (event) => {
      if (event.type === DEVICE.CONNECT_UNACQUIRED) {
        // connected device is unknown or busy
        // most common reasons is that either device is currently used somewhere else
        // or app refreshed during call and trezor-bridge didn't managed to release the session
        // render "Acquire device" button and after click try to fetch device features using:
        // TrezorConnect.getFeatures();
        console.log("Connected device is unknown or busy...");
      }
    });

    TrezorConnect.on(UI_EVENT, (event) => {
      if (event.type === UI.REQUEST_PIN) {
        // FIXME: not sure what's the positions of the PIN on the screen, grid is 3x3 and the positions are 1-9
        // 1st position is top left, 9th position is bottom right
        const prompt = createPrompt({});
        const positions = prompt.hide("Enter your the positions of your PIN number:");
        TrezorConnect.uiResponse({ type: UI.RECEIVE_PIN, payload: positions });
      }

      if (event.type === UI.REQUEST_PASSPHRASE) {
        if (
          event.payload.device.features.capabilities.includes(
            "Capability_PassphraseEntry"
          )
        ) {
          const prompt = createPrompt({});
          const passphrase = prompt.hide(
            "Enter your passphrase: (empty for default)"
          );
          TrezorConnect.uiResponse({
            type: UI.RECEIVE_PASSPHRASE,
            payload: { passphraseOnDevice: true, value: passphrase },
          });
        } else {
          const prompt = createPrompt({});
          const passphrase = prompt.hide(
            "Enter your passphrase: (empty for default)"
          );
          TrezorConnect.uiResponse({
            type: UI.RECEIVE_PASSPHRASE,
            payload: { value: passphrase, save: true },
          });
        }
      }

      if (event.type === UI.SELECT_DEVICE) {
        if (event.payload.devices.length > 0) {
          // more then one device connected
          // example how to respond to select device
          TrezorConnect.uiResponse({
            type: UI_RESPONSE.RECEIVE_DEVICE,
            payload: {
              device: event.payload.devices[0],
            },
          });
        } else {
          // no devices connected, waiting for connection
          console.log(
            "\nATTENTION: No devices connected. Waiting Trezor to be connected..."
          );
        }
      }

      if (event.type === UI.REQUEST_CONFIRMATION) {
        // payload: true - user decides to continue anyway
        TrezorConnect.uiResponse({
          type: UI.RECEIVE_CONFIRMATION,
          payload: false,
        });
      }
    });
  }

  async getAddress(): Promise<string> {
    const response = await TrezorConnect.ethereumGetAddress({
      path: "m/44'/60'/0'/0/0",
      showOnTrezor: false,
    });

    if (response.success) {
      return response.payload.address;
    } else {
      throw new Error(
        `Failed to get address from Trezor: ${JSON.stringify(response.payload)}`
      );
    }
  }

  async signMessage(message: string): Promise<string> {
    const response = await TrezorConnect.ethereumSignMessage({
      path: "m/44'/60'/0'/0/0",
      message: ethers.utils.hexlify(ethers.utils.toUtf8Bytes(message)),
    });

    if (response.success) {
      return response.payload.signature;
    } else {
      throw new Error(
        `Failed to sign message with Trezor: ${JSON.stringify(
          response.payload
        )}`
      );
    }
  }

  async signTransaction(
    transaction: ethers.providers.TransactionRequest
  ): Promise<string> {
    const tx = await ethers.utils.resolveProperties(transaction);

    const response = await TrezorConnect.ethereumSignTransaction({
      path: "m/44'/60'/0'/0/0",
      transaction: {
        to: tx.to!,
        value: ethers.utils.hexlify(tx.value!),
        gasPrice: ethers.utils.hexlify(tx.gasPrice!),
        gasLimit: ethers.utils.hexlify(tx.gasLimit!),
        nonce: ethers.utils.hexlify(tx.nonce!),
        data: tx.data ? ethers.utils.hexlify(tx.data as Uint8Array) : "0x",
        chainId: tx.chainId!,
      },
    });

    if (response.success) {
      return ethers.utils.serializeTransaction(tx, {
        v: response.payload.v,
        r: response.payload.r,
        s: response.payload.s,
      });
    } else {
      throw new Error(
        `Failed to sign transaction with Trezor: ${JSON.stringify(
          response.payload
        )}`
      );
    }
  }

  connect(provider: ethers.providers.Provider): Signer {
    return new TrezorSigner(provider);
  }
}

export default TrezorSigner;
