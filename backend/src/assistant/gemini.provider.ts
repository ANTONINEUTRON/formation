import { GoogleGenAI } from '@google/genai';
import { Inject, Injectable } from '@nestjs/common';
import { CONFIG } from '../core/config.js';
import type { AppConfig } from '../core/config.js';
import { LlmError } from './llm.js';
import type { ImageData, LlmProvider, LlmRequest, LlmResponse, SearchResult, SearchSource } from './llm.js';

/** Replies longer than this are cut off rather than left hanging. */
const TIMEOUT_MS = 30_000;
const IMAGE_TIMEOUT_MS = 90_000;

@Injectable()
export class GeminiProvider implements LlmProvider {
  private readonly client: GoogleGenAI | null;

  constructor(@Inject(CONFIG) private readonly config: AppConfig) {
    this.client = config.geminiApiKey ? new GoogleGenAI({ apiKey: config.geminiApiKey }) : null;
  }

  get available(): boolean {
    return this.client !== null;
  }

  async generate(request: LlmRequest): Promise<LlmResponse> {
    if (!this.client) throw new LlmError('No Gemini API key is configured');

    let response;
    try {
      response = await this.client.models.generateContent({
        model: this.config.geminiModel,
        contents: request.messages.map((m) => ({ role: m.role, parts: [{ text: m.text }] })),
        config: {
          systemInstruction: request.system,
          responseMimeType: 'application/json',
          responseJsonSchema: request.schema,
          maxOutputTokens: request.maxOutputTokens,
          temperature: 0.7,
          abortSignal: AbortSignal.timeout(TIMEOUT_MS),
        },
      });
    } catch (e) {
      throw new LlmError(`Gemini request failed: ${String(e)}`);
    }

    const text = response.text;
    if (!text) throw new LlmError('Gemini returned no text');
    let json: unknown;
    try {
      json = JSON.parse(text);
    } catch {
      throw new LlmError('Gemini returned malformed JSON');
    }
    return {
      json,
      tokensIn: response.usageMetadata?.promptTokenCount ?? 0,
      tokensOut: response.usageMetadata?.candidatesTokenCount ?? 0,
    };
  }

  /** Image in, image out, through the image model (GEMINI_IMAGE_MODEL). */
  async editImage(prompt: string, image: ImageData): Promise<ImageData> {
    if (!this.client) throw new LlmError('No Gemini API key is configured');
    let response;
    try {
      response = await this.client.models.generateContent({
        model: this.config.geminiImageModel,
        contents: [
          {
            role: 'user',
            parts: [{ inlineData: { mimeType: image.mime, data: image.data.toString('base64') } }, { text: prompt }],
          },
        ],
        config: { responseModalities: ['IMAGE'], abortSignal: AbortSignal.timeout(IMAGE_TIMEOUT_MS) },
      });
    } catch (e) {
      throw new LlmError(`Gemini image request failed: ${String(e)}`);
    }
    const part = response.candidates?.[0]?.content?.parts?.find((p) => p.inlineData?.data);
    if (!part?.inlineData?.data) {
      // No image usually means the safety filters declined the photo.
      throw new LlmError('Gemini returned no image');
    }
    return { mime: part.inlineData.mimeType ?? 'image/png', data: Buffer.from(part.inlineData.data, 'base64') };
  }

  /**
   * Google Search grounding. Kept a separate call from [generate] because a
   * grounded reply can't also be held to a JSON schema; this one only ever
   * returns prose plus its sources.
   */
  async search(prompt: string, maxOutputTokens: number): Promise<SearchResult> {
    if (!this.client) throw new LlmError('No Gemini API key is configured');
    let response;
    try {
      response = await this.client.models.generateContent({
        model: this.config.geminiModel,
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
        config: {
          tools: [{ googleSearch: {} }],
          maxOutputTokens,
          temperature: 0.3,
          abortSignal: AbortSignal.timeout(TIMEOUT_MS),
        },
      });
    } catch (e) {
      throw new LlmError(`Gemini search failed: ${String(e)}`);
    }
    const text = response.text?.trim();
    if (!text) throw new LlmError('Gemini search returned no text');

    const seen = new Set<string>();
    const sources: SearchSource[] = [];
    for (const chunk of response.candidates?.[0]?.groundingMetadata?.groundingChunks ?? []) {
      const url = chunk.web?.uri;
      if (!url || seen.has(url)) continue;
      seen.add(url);
      sources.push({ title: chunk.web?.title || new URL(url).hostname, url });
    }
    return {
      text,
      sources: sources.slice(0, 4),
      tokensIn: response.usageMetadata?.promptTokenCount ?? 0,
      tokensOut: response.usageMetadata?.candidatesTokenCount ?? 0,
    };
  }
}
