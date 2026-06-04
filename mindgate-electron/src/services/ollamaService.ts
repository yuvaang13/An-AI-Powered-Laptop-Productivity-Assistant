import { DecisionResult } from '../types';

export class OllamaService {
  private baseURL: string;
  private model: string;

  constructor(baseURL: string, model: string) {
    this.baseURL = baseURL;
    this.model = model;
  }

  async checkConnection(): Promise<boolean> {
    try {
      const response = await fetch(`${this.baseURL.replace('/api/generate', '/api/tags')}`, {
        method: 'GET'
      });
      return response.ok;
    } catch (error) {
      console.error('Ollama connection failed:', error);
      return false;
    }
  }

async evaluateRequest(userInput: string): Promise<DecisionResult> {
    try {
      const response = await fetch(this.baseURL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: this.model,
          prompt: `Evaluate this request for distraction access: "${userInput}". Is this a valid, productive reason? Respond with JSON containing isApproved (true/false) and a brief message explaining the decision.`,
          stream: false
        })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      const responseText = data.response || data.message || '';

      try {
        const parsed = JSON.parse(responseText);
        return {
          isApproved: parsed.isApproved ?? false,
          message: parsed.message ?? 'Unable to determine approval'
        };
      } catch {
        const isApproved = responseText.toLowerCase().includes('approved') ||
                          responseText.toLowerCase().includes('valid');
        return {
          isApproved,
          message: responseText || 'No response from AI'
        };
      }
    } catch (error) {
      console.error('Ollama request failed:', error);
      return {
        isApproved: false,
        message: `Error: ${error instanceof Error ? error.message : 'Unknown error'}`
      };
    }
  }

  async generateRawResponse(prompt: string): Promise<string> {
    try {
      const response = await fetch(this.baseURL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: this.model,
          prompt,
          stream: false,
          options: {
            temperature: 0.7,
            top_p: 0.9
          }
        })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      return (data.response || '').trim();
    } catch (error) {
      console.error('Ollama raw request failed:', error);
      throw error;
    }
  }
}