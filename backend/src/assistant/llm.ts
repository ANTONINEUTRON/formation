/**
 * What the assistant needs from a language model, and nothing more. Gemini is
 * the only implementation; tests swap in a fake through [LLM_PROVIDER].
 */
export interface LlmMessage {
  role: 'user' | 'model';
  text: string;
}

export interface LlmRequest {
  system: string;
  messages: LlmMessage[];
  /** JSON Schema the reply must match. */
  schema: Record<string, unknown>;
  maxOutputTokens: number;
}

export interface LlmResponse {
  /** The reply, parsed from JSON. Validated by the caller, never trusted. */
  json: unknown;
  tokensIn: number;
  tokensOut: number;
}

export interface SearchSource {
  title: string;
  url: string;
}

/** A short answer written from live web results, with where it came from. */
export interface SearchResult {
  text: string;
  sources: SearchSource[];
  tokensIn: number;
  tokensOut: number;
}

export interface LlmProvider {
  /** False when no key is configured, so callers can refuse before charging. */
  readonly available: boolean;
  generate(request: LlmRequest): Promise<LlmResponse>;
  /** Answers [prompt] from a live web search. Plain text, never trusted for numbers. */
  search(prompt: string, maxOutputTokens: number): Promise<SearchResult>;
}

export const LLM_PROVIDER = Symbol('LLM_PROVIDER');

/** Thrown when the model fails or returns something unusable. */
export class LlmError extends Error {}
