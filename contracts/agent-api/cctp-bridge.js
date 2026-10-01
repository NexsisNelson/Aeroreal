const { ethers } = require('ethers');

const ADDRESSES = {
  baseSepolia: {
    usdc: '0x036CbD53842c5426634e7929541eC2318f3dCF7e',
    tokenMessenger: '0x8FE6B999Dc680CcFDD5Bf7EB0974218be2542DAA',
    domain: 6,
    rpc: process.env.BASE_SEPOLIA_RPC_URL || 'https://sepolia.base.org',
  },
  monadTestnet: {
    usdc: '0x534b2f3A21130d7a60830c2Df862319e593943A3',
    messageTransmitter: '0xE737e5cEBEEBa77EFE34D4aa090756590b1CE275',
    domain: 15,
    rpc: process.env.MONAD_RPC_URL || 'https://10143.rpc.thirdweb.com',
  },
};

const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
];
const TOKEN_MESSENGER_ABI = [
  'function depositForBurn(uint256 amount, uint32 destinationDomain, bytes32 mintRecipient, address burnToken) returns (uint64)',
  'event MessageSent(bytes message)',
];
const MESSAGE_TRANSMITTER_ABI = [
  'function receiveMessage(bytes message, bytes attestation) returns (bool)',
];
const CIRCLE_ATTESTATION_API = 'https://iris-api-sandbox.circle.com/attestations';

class CctpBridge {
  constructor(privateKey) {
    if (!privateKey) throw new Error('CCTP_BRIDGE_PRIVATE_KEY is not configured');
    this.baseProvider = new ethers.JsonRpcProvider(ADDRESSES.baseSepolia.rpc);
    this.monadProvider = new ethers.JsonRpcProvider(ADDRESSES.monadTestnet.rpc);
    this.baseSigner = new ethers.Wallet(privateKey, this.baseProvider);
    this.monadSigner = new ethers.Wallet(privateKey, this.monadProvider);
    this.messengerInterface = new ethers.Interface(TOKEN_MESSENGER_ABI);
  }

  async bridge({ amount, recipientAddress }) {
    const recipient = ethers.getAddress(recipientAddress);
    const usdc = new ethers.Contract(ADDRESSES.baseSepolia.usdc, ERC20_ABI, this.baseSigner);
    const messenger = new ethers.Contract(
      ADDRESSES.baseSepolia.tokenMessenger,
      TOKEN_MESSENGER_ABI,
      this.baseSigner,
    );

    const approval = await usdc.approve(ADDRESSES.baseSepolia.tokenMessenger, amount);
    await approval.wait();

    const mintRecipient = ethers.zeroPadValue(recipient, 32);
    const burn = await messenger.depositForBurn(
      amount,
      ADDRESSES.monadTestnet.domain,
      mintRecipient,
      ADDRESSES.baseSepolia.usdc,
    );
    const receipt = await burn.wait();
    const messageLog = receipt.logs
      .map((log) => {
        try {
          return this.messengerInterface.parseLog(log);
        } catch (_) {
          return null;
        }
      })
      .find((parsed) => parsed?.name === 'MessageSent');

    if (!messageLog) throw new Error('MessageSent event not found in burn receipt');
    const message = messageLog.args.message;
    const messageHash = ethers.keccak256(message);
    const attestation = await this.waitForAttestation(messageHash);

    const transmitter = new ethers.Contract(
      ADDRESSES.monadTestnet.messageTransmitter,
      MESSAGE_TRANSMITTER_ABI,
      this.monadSigner,
    );
    const mint = await transmitter.receiveMessage(message, attestation);
    await mint.wait();

    return { burnTx: burn.hash, mintTx: mint.hash, messageHash };
  }

  async waitForAttestation(messageHash, maxAttempts = 60) {
    for (let attempt = 0; attempt < maxAttempts; attempt += 1) {
      const response = await fetch(`${CIRCLE_ATTESTATION_API}/${messageHash}`);
      if (response.ok) {
        const data = await response.json();
        if (data.status === 'complete' && data.attestation) return data.attestation;
      }
      await new Promise((resolve) => setTimeout(resolve, 5000));
    }
    throw new Error('Circle attestation timed out');
  }
}

module.exports = { CctpBridge, ADDRESSES };
