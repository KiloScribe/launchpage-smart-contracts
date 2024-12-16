import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { AccountId } from '@hashgraph/sdk';
// @ts-ignore
import abiDecoder from 'abi-decoder';
import axios from 'axios';
import { DecodedError, DecodedParameter, MirrorNodeResponse, ContractArtifact } from './types/decoder.js';

class ErrorDecoder {
  private contractId: string;
  private network: string;
  private readonly artifactsPath: string;

  constructor(network: string, contractId: string) {
    this.network = network;
    this.contractId = contractId;
    this.artifactsPath = path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      '..',
      'artifacts'
    );
    this.initializeAbiDecoder();
  }

  private initializeAbiDecoder(): void {
    try {
      const minterArtifact = this.loadArtifact('KiloScribeMinter');
      const launchpadArtifact = this.loadArtifact('LaunchpadLib');
      
      abiDecoder.addABI([...minterArtifact.abi, ...launchpadArtifact.abi]);
    } catch (error) {
      console.error('Failed to initialize ABI decoder:', error);
      process.exit(1);
    }
  }

  private loadArtifact(contractName: string): ContractArtifact {
    const artifactPath = path.resolve(
      this.artifactsPath,
      'contracts',
      `${contractName}.sol`,
      `${contractName}.json`
    );

    try {
      return JSON.parse(fs.readFileSync(artifactPath, 'utf8'));
    } catch (error) {
      throw new Error(`Failed to load artifact for ${contractName}: ${error}`);
    }
  }

  private async getErrorFromMirror(): Promise<DecodedError> {
    const url = `https://${this.network}.mirrornode.hedera.com/api/v1/contracts/${this.contractId}/results?order=desc&limit=10`;
    
    try {
      const response = await axios.get<MirrorNodeResponse>(url);
      const errorMessage = response.data?.results?.[0]?.error_message;

      if (!errorMessage) {
        throw new Error('No error message found in mirror node response');
      }

      return this.decodeError(errorMessage);
    } catch (error) {
      if (axios.isAxiosError(error)) {
        throw new Error(`Mirror node request failed: ${error.message}`);
      }
      throw error;
    }
  }

  private decodeError(errorMessage: string): DecodedError {
    try {
      const decodedError = abiDecoder.decodeMethod(errorMessage);
      return {
        name: decodedError?.name,
        params: decodedError?.params,
        data: errorMessage,
        signature: ''
      };
    } catch (error) {
      throw new Error(`Failed to decode error message: ${error}`);
    }
  }

  private async processError(error: DecodedError, indent: number = 0): Promise<void> {
    if (!error.data) return;

    const indentation = '.'.repeat(indent);
    
    if (error.name) {
      console.log(`${indentation}Error is ${error.name}`);
    }

    if (error.params) {
      for (const param of error.params) {
        console.log(`${indentation}Parameter (${param.type}) = ${param.value}`);

        if (param.type === 'address') {
          try {
            const hederaAddress = AccountId.fromSolidityAddress(param.value.toString());
            console.log(`${indentation}=> Hedera address ${hederaAddress}`);
          } catch (error) {
            console.error(`${indentation}Failed to convert Solidity address: ${error}`);
          }
        }

        if (param.type === 'bytes' && param.value) {
          try {
            const innerError = this.decodeError(param.value.toString());
            await this.processError(innerError, indent + 2);
          } catch (error) {
            console.error(`${indentation}Failed to process nested error: ${error}`);
          }
        }

        console.log('');
      }
    }
  }

  public async decode(): Promise<void> {
    try {
      console.log(`\nDecoding error for contract ${this.contractId} on ${this.network}\n`);
      const error = await this.getErrorFromMirror();
      await this.processError(error);
    } catch (error) {
      console.error('Error decoder failed:', error);
      process.exit(1);
    }
  }
}

async function main() {
  const args = process.argv.slice(2);
  
  if (args.length !== 2) {
    console.error('Usage: npm run decode -- <network> <contract-id>');
    console.error('Example: npm run decode -- testnet 0.0.1234567');
    process.exit(1);
  }

  const [network, contractId] = args;
  const decoder = new ErrorDecoder(network, contractId);
  await decoder.decode();
}

// Run if this is the main module
if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((error) => {
    console.error('Fatal error:', error);
    process.exit(1);
  });
}
