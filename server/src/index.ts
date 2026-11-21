import Anthropic from "@anthropic-ai/sdk";
import { fakeChecker, makeClaudeChecker } from "./feedback";
import { handle } from "./handler";

export interface Env {
  /** Secret, set with `wrangler secret put ANTHROPIC_API_KEY`. Never in the app or the repo. */
  ANTHROPIC_API_KEY: string;
  PER_IP?: RateLimit;
  /** "1" in `.dev.vars` for local runs without an API key: answers come from `fakeChecker`. */
  FAKE_FEEDBACK?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const check = env.FAKE_FEEDBACK === "1"
      ? fakeChecker
      : makeClaudeChecker(new Anthropic({ apiKey: env.ANTHROPIC_API_KEY, maxRetries: 1, timeout: 20_000 }));
    const started = Date.now();
    const response = await handle(request, { check, limiter: env.PER_IP });
    // Status and timing only. The retelling itself is never logged.
    console.log(JSON.stringify({ path: new URL(request.url).pathname, status: response.status, ms: Date.now() - started }));
    return response;
  },
} satisfies ExportedHandler<Env>;
