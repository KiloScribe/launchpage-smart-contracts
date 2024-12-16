import { fileURLToPath } from "url";
import {
  AccountId,
  Client,
  ContractCallQuery,
  ContractCreateFlow,
  ContractExecuteTransaction,
  ContractFunctionParameters,
  ContractId,
  Hbar,
  PrivateKey,
  TokenId,
  TokenUpdateTransaction,
  AccountAllowanceApproveTransaction,
  TokenAssociateTransaction,
} from "@hashgraph/sdk";
import dotenv from "dotenv";
import { getAddress, solidityPackedKeccak256 } from "ethers";
import { createToken } from "./mint.js";
import * as fs from "fs";
import * as path from "path";
import { Logger } from "./logger.js";
import {
  DeploymentConfig,
  DeploymentResult,
  TokenConfig,
  SystemDeploymentResult,
} from "./types/contracts.js";

dotenv.config();

console.log = function (...args: any[]) {
  Logger.info({ message: args });
};

const OP_KEY = PrivateKey.fromString(process.env.HEDERAS_OPERATOR_KEY!);
const operatorId = AccountId.fromString(process.env.HEDERAS_OPERATOR_ID!);

const client = Client.forTestnet()
  .setOperator(operatorId, OP_KEY)
  .setMaxExecutionTime(120)
  .setMaxAttempts(40);

const sleep = (ms: number): Promise<void> => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

const tryGetContractId = async (
  contractId: string,
  network: string,
  tries: number = 0
): Promise<ContractId | undefined> => {
  try {
    const url = `https://${network}.mirrornode.hedera.com/api/v1/contracts/${contractId}`;
    console.log("trying contract url", url);
    const request = await fetch(url);
    const response = (await request.json()) as any;
    const id = response.contract_id;
    return ContractId.fromString(id);
  } catch (e) {
    if (tries < 3) {
      console.log("retrying", tries);
      return await tryGetContractId(contractId, network, tries + 1);
    }
    console.log("could not get contract", e);
    return undefined;
  }
};

const deployKiloScribeFactory = async (): Promise<DeploymentResult> => {
  console.log("deploying factory");

  // First compile LaunchpadLib
  console.log("Deploying LaunchpadLib...");

  const artifactsPath = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    "..",
    "artifacts"
  );

  // Load the compiled artifacts
  const launchpadLibArtifact = JSON.parse(
    // @ts-ignore
    fs.readFileSync(
      path.join(artifactsPath, "contracts/LaunchpadLib.sol/LaunchpadLib.json")
    )
  );

  let launchpadLibBytecode = launchpadLibArtifact.bytecode;
  console.log("LaunchpadLib bytecode length:", launchpadLibBytecode.length);

  // Deploy LaunchpadLib
  console.log("calling contract create flow");
  const launchpadLibTx = new ContractCreateFlow()
    .setBytecode(launchpadLibBytecode)
    .setMaxChunks(30)
    .setGas(13_000_000)
    .setContractMemo("LaunchpadLib library");

  const launchpadLibResponse = await launchpadLibTx.execute(client);
  const launchpadLibReceipt = await launchpadLibResponse.getReceipt(client);
  const launchpadLibId = launchpadLibReceipt.contractId!;
  console.log("LaunchpadLib deployed at:", launchpadLibId.toString());

  // Load the factory artifact
  console.log("Loading KiloScribeMinterFactory artifact...");
  const factoryArtifact = JSON.parse(
    // @ts-ignore
    fs.readFileSync(
      path.join(
        artifactsPath,
        "contracts/KiloScribeMinterFactory.sol/KiloScribeMinterFactory.json"
      )
    )
  );

  function linkLibrary(
    bytecode: string,
    libraries: Record<string, string>
  ): string {
    let linkedBytecode = bytecode;

    for (const [name, address] of Object.entries(libraries)) {
      const placeholder = `__$${solidityPackedKeccak256(
        ["string"],
        [name]
      ).slice(2, 36)}$__`;

      const formattedAddress = getAddress(address)
        .toLowerCase()
        .replace("0x", "");

      if (linkedBytecode.indexOf(placeholder) === -1) {
        throw new Error(`Unable to find placeholder for library ${name}`);
      }

      while (linkedBytecode.indexOf(placeholder) !== -1) {
        linkedBytecode = linkedBytecode.replace(placeholder, formattedAddress);
      }
    }

    return linkedBytecode;
  }

  // Use ethers to link the library
  const libraryAddress = launchpadLibId.toSolidityAddress();
  const linkedBytecode = linkLibrary(factoryArtifact.bytecode, {
    "contracts/LaunchpadLib.sol:LaunchpadLib": libraryAddress,
  });

  // Deploy the factory
  const contractCreate = new ContractCreateFlow()
    .setGas(4000000)
    .setBytecode(linkedBytecode)
    .setMaxChunks(30)
    .setAdminKey(OP_KEY);

  const contractResponse = await contractCreate.execute(client);
  const contractReceipt = await contractResponse.getReceipt(client);
  const factoryContractId = contractReceipt.contractId!;

  return {
    factoryContractId,
    abi: factoryArtifact.abi,
    launchpadLibId,
  };
};

const createKiloScribeContract = async (
  factoryContractId: string | ContractId,
  config: DeploymentConfig
): Promise<string> => {
  // Create contract call to factory
  const contractExecuteTx = new ContractExecuteTransaction()
    .setContractId(ContractId.fromString(factoryContractId.toString()))
    .setGas(1300000)
    .setFunction(
      "createContract",
      new ContractFunctionParameters()
        .addAddress(config.tokenAddress)
        .addUint64(config.discountedMintPrice)
        .addUint64(config.allowListMintPrice)
        .addUint64(config.mintPrice)
        .addUint64(config.tokensRemaining)
        .addUint64Array(config.launchpadFees)
        .addAddressArray(config.feeAddresses)
        .addString(config.baseTokenURI)
        .addBool(config.baseTokenURI.includes("hcs://"))
    );

  const response = await contractExecuteTx.execute(client);
  const record = await response.getRecord(client);

  // Get the contract creation event from logs
  const contractCreatedId = record.contractFunctionResult!.getAddress(0);
  const evmContractid = ContractId.fromEvmAddress(
    0,
    0,
    `0x${contractCreatedId.toString()}`
  );
  await sleep(5000);
  const actualContractId = await tryGetContractId(
    contractCreatedId,
    "testnet",
    0
  );
  console.log("contractCreatedId", contractCreatedId, evmContractid);
  console.log("contractFromEVM", record.contractFunctionResult);
  console.log("evmToId", actualContractId);

  if (!actualContractId) {
    throw new Error("Could not find ContractCreated event in logs");
  }

  return actualContractId.toString();
};

const testMinting = async (mintContractId: ContractId, tokenId: TokenId) => {
  // First enable minting
  const enableMintTx = new ContractExecuteTransaction()
    .setContractId(mintContractId)
    .setGas(300000)
    .setFunction(
      "toggleMintEnabled",
      new ContractFunctionParameters().addBool(true)
    );

  let response = await enableMintTx.execute(client);
  let receipt = await response.getReceipt(client);
  console.log("Minting enabled, receipt:", receipt);

  // Try to mint a token
  const mintTx = new ContractExecuteTransaction()
    .setContractId(mintContractId)
    .setGas(1200000)
    .setPayableAmount(new Hbar(1)) // 1 HBAR as per the mint price
    .setFunction(
      "mint",
      new ContractFunctionParameters()
        .addAddress(
          AccountId.fromString(
            process.env.TESTNET_LP_ADDRESS_1!
          ).toSolidityAddress()
        )
        .addUint8(1)
    );

  response = await mintTx.execute(client);
  receipt = await response.getReceipt(client);
  console.log("Mint transaction receipt:", receipt);

  // Check token balance
  const balanceCheckTx = new ContractCallQuery()
    .setContractId(mintContractId)
    .setGas(100000)
    .setFunction("tokensRemaining", new ContractFunctionParameters());

  const balanceResult = await balanceCheckTx.execute(client);
  const tokensRemaining = balanceResult.getUint64(0);
  console.log("Tokens remaining:", tokensRemaining);

  return receipt;
};

async function setSupplyKey(
  currentLiveTokenId: string,
  currentContract: string,
  actualSupplyKey: PrivateKey
): Promise<void> {
  let tokenUpdateTx = await new TokenUpdateTransaction()
    .setTokenId(TokenId.fromString(currentLiveTokenId))
    .setSupplyKey(ContractId.fromString(currentContract))
    .setTreasuryAccountId(currentContract)
    .freezeWith(client)
    .sign(actualSupplyKey);

  const tokenUpdateSubmit = await tokenUpdateTx.execute(client);
  const tokenUpdateRx = await tokenUpdateSubmit.getReceipt(client);
  console.log(`- Token update status:`, `${tokenUpdateRx}`);
}

export const allowance = async (
  accountId: AccountId | string,
  spender: AccountId | string,
  amount: Hbar
): Promise<void> => {
  try {
    const associateTx = await new AccountAllowanceApproveTransaction()
      .approveHbarAllowance(accountId, spender, amount)
      .freezeWith(client);

    const signAssociateTx = await associateTx.sign(OP_KEY);

    const tx = await signAssociateTx.execute(client);
    const rx = await tx.getReceipt(client);

    console.log(rx, accountId);
  } catch (e) {
    console.log("failed to add allowance", e);
  }
};

export const associate = async (
  accountId: AccountId | string,
  token: TokenId
): Promise<void> => {
  try {
    const associateTx = await new TokenAssociateTransaction()
      .setTokenIds([token])
      .setAccountId(accountId)
      .freezeWith(client);

    const signAssociateTx = await associateTx.sign(OP_KEY);

    const tx = await signAssociateTx.execute(client);
    const rx = await tx.getReceipt(client);

    console.log(rx, accountId);
  } catch (e) {
    console.log("failed to associate", e);
  }
};

let launchpadLibId: ContractId | undefined;

const deployFullKiloScribeSystem = async (
  config: Partial<DeploymentConfig> & { tokenAddress: string },
  factoryContract: ContractId | string
): Promise<DeploymentResult> => {
  const completeConfig: DeploymentConfig = {
    ...config,
    tokenAddress: config.tokenAddress,
    discountedMintPrice: 100000000, // 1 HBAR in tinybars
    allowListMintPrice: 100000000,
    mintPrice: 100000000,
    tokensRemaining: 3000,
    totalSupply: 3000, // Set the total supply to 3000 tokens
    launchpadFees: [1000, 1000], // 10% fees for each launchpad
    feeAddresses: [
      AccountId.fromString(process.env.FEE_ADDRESS!).toSolidityAddress(),
      AccountId.fromString(process.env.FEE_ADDRESS_2!).toSolidityAddress(),
    ],
    baseTokenURI: "hcs://1/0.0.4840712",
  };

  // Then use the factory to create a new minter contract
  const newContractAddress = await createKiloScribeContract(
    factoryContract,
    completeConfig
  );

  if (!launchpadLibId) {
    throw new Error("LaunchpadLib ID not set. Deploy factory first.");
  }

  return {
    factoryContractId:
      typeof factoryContract === "string"
        ? ContractId.fromString(factoryContract)
        : factoryContract,
    newContractAddress,
    launchpadLibId,
  };
};

async function main(): Promise<SystemDeploymentResult> {
  try {
    // Step 1: Create the token
    const tokenConfig: TokenConfig = {
      tokenName: "KiloScribe",
      tokenSymbol: "KILO",
      maxSupply: 3000,
      customFeeRoyaltyAccountId: process.env.FEE_ADDRESS,
      customFeeRoyaltyAmount: "1000", // 10%
      customFeeRoyaltyAccountId2: process.env.FEE_ADDRESS_2,
      customFeeRoyaltyAmount2: "1000", // 10%
      wipeKeyEnabled: true,
      feeScheduleKeyEnabled: true,
      memo: "KiloScribe NFT Collection",
    };

    console.log("Creating token...");
    const tokenResult = await createToken(tokenConfig);
    console.log("Token created:", tokenResult);

    // Step 2: Deploy the factory and library
    console.log("Deploying factory...");
    const factoryResult = await deployKiloScribeFactory();
    console.log("Factory deployed:", factoryResult);

    // Step 3: Deploy the minting contract
    console.log("Deploying minting contract...");
    const mintingResult = await deployFullKiloScribeSystem(
      { tokenAddress: tokenResult.tokenId.toSolidityAddress() },
      factoryResult.factoryContractId
    );
    console.log("Minting contract deployed:", mintingResult);

    // Step 4: Update token supply key
    if (mintingResult.newContractAddress) {
      console.log("Updating token supply key...");
      await setSupplyKey(
        tokenResult.tokenId.toString(),
        mintingResult.newContractAddress,
        PrivateKey.fromString(tokenResult.supplyKey)
      );
    }

    // Step 5: Test minting
    if (mintingResult.newContractAddress) {
      console.log("Testing minting...");
      await testMinting(
        ContractId.fromString(mintingResult.newContractAddress),
        tokenResult.tokenId
      );
    }

    console.log("Deployment complete!");
    return {
      tokenId: tokenResult.tokenId,
      factoryContractId: factoryResult.factoryContractId,
      mintContractId: mintingResult.newContractAddress,
      launchpadLibId: mintingResult.launchpadLibId,
    };
  } catch (error) {
    console.error("Deployment failed:", error);
    throw error;
  }
}

// Run if this is the main module
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  console.log("hello world...");
  main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
  });
}

export {
  deployKiloScribeFactory,
  createKiloScribeContract,
  testMinting,
  setSupplyKey,
  deployFullKiloScribeSystem,
  main,
};
