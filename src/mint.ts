import {
  AccountId,
  Client,
  CustomRoyaltyFee,
  PrivateKey,
  TokenSupplyType,
  TokenType,
  TokenCreateTransaction,
} from "@hashgraph/sdk";
import dotenv from "dotenv";
import { Logger } from "./logger.js";
import { TokenConfig, TokenDeploymentResult } from "./types/contracts.js";

dotenv.config();

console.log = function (...args: any[]) {
  Logger.info({ message: args });
};

export const createToken = async (
  props: TokenConfig
): Promise<TokenDeploymentResult> => {
  const KEY = PrivateKey.fromStringED25519(process.env.HEDERAS_OPERATOR_KEY!);
  const operatorId = AccountId.fromString(process.env.HEDERAS_OPERATOR_ID!);

  const client = Client.forTestnet().setOperator(operatorId, KEY);

  console.log(
    "Creating token with operator ID:",
    operatorId.toString(),
    "Key type:",
    KEY.toString()
  );

  const { maxSupply, tokenName, tokenSymbol, memo } = props;

  // Generate new keys
  const supplyKey = KEY; // Use operator key for supply
  const adminKey = KEY; // Use operator key for admin

  // Create token with the Hedera SDK
  const transaction = new TokenCreateTransaction()
    .setTokenName(tokenName)
    .setTokenSymbol(tokenSymbol)
    .setTokenType(TokenType.NonFungibleUnique)
    .setDecimals(0)
    .setInitialSupply(0)
    .setTreasuryAccountId(operatorId)
    .setSupplyType(TokenSupplyType.Finite)
    .setMaxSupply(maxSupply || 0)
    .setSupplyKey(supplyKey)
    .setAdminKey(adminKey)
    .setTokenMemo(memo || "");

  console.log("Freezing transaction...");
  const frozenTx = await transaction.freezeWith(client);

  // console.log("Signing transaction with key...");
  // const signTx = await frozenTx.sign(KEY);

  console.log("Executing transaction...");
  const txResponse = await frozenTx.execute(client);

  console.log("Getting receipt...");
  const receipt = await txResponse.getReceipt(client);

  // Get the token ID from the receipt
  const tokenId = receipt.tokenId!;

  console.log(`Created token with ID: ${tokenId}`);

  return {
    tokenId,
    supplyKey: KEY.toStringRaw(),
    adminKey: KEY.toStringRaw(),
  };
};
