import { ContractId, TokenId } from "@hashgraph/sdk";

export interface DeploymentConfig {
  tokenAddress: string;
  discountedMintPrice: number;
  allowListMintPrice: number;
  mintPrice: number;
  tokensRemaining: number;
  launchpadFees: number[];
  feeAddresses: string[];
  baseTokenURI: string;
  isHashinal?: boolean;
  totalSupply?: number;
}

export interface DeploymentResult {
  factoryContractId: ContractId;
  newContractAddress?: string;
  launchpadLibId: ContractId;
  abi?: any;
}

export interface SystemDeploymentResult {
  tokenId: TokenId;
  factoryContractId: ContractId;
  mintContractId?: string;
  launchpadLibId: ContractId;
}

export interface TokenConfig {
  maxSupply?: number;
  tokenName: string;
  tokenSymbol: string;
  customFeeRoyaltyAccountId?: string;
  customFeeRoyaltyAmount?: string;
  customFeeRoyaltyAccountId2?: string;
  customFeeRoyaltyAmount2?: string;
  wipeKeyEnabled?: boolean;
  feeScheduleKeyEnabled?: boolean;
  memo?: string;
}

export interface TokenDeploymentResult {
  tokenId: TokenId;
  supplyKey: string;
  adminKey: string;
}
