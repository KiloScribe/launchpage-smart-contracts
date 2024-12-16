export interface DecodedError {
  name?: string;
  params?: DecodedParameter[];
  data?: string;
  signature?: string;
}

export interface DecodedParameter {
  name: string;
  type: string;
  value: string | number | boolean;
}

export interface MirrorNodeResponse {
  results?: Array<{
    error_message?: string;
  }>;
}

export interface ContractArtifact {
  abi: any[];
}
