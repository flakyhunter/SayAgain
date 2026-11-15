import Anthropic from "@anthropic-ai/sdk";
import { zodOutputFormat } from "@anthropic-ai/sdk/helpers/zod";
import { buildUserMessage, FeedbackSchema, MODEL, SYSTEM_PROMPT, type Feedback } from "./prompt";
import type { QuestionRecord } from "./questions";

/** Why a check could not produce feedback. The handler maps each one to an HTTP status. */
export class FeedbackError extends Error {
  constructor(readonly reason: "refused" | "unparseable" | "upstream_busy" | "upstream_error") {
    super(reason);
  }
}

export type CheckRetelling = (question: QuestionRecord, retelling: string) => Promise<Feedback>;

/** Asks Claude to judge one retelling. Returns schema-checked feedback or throws `FeedbackError`. */
export function makeClaudeChecker(client: Anthropic, model: string = MODEL): CheckRetelling {
  return async (question, retelling) => {
    let response;
    try {
      // create, not parse: parse throws on an empty or cut-off reply before we can see why.
      response = await client.messages.create({
        model,
        max_tokens: 2000,
        system: SYSTEM_PROMPT,
        output_config: { effort: "low", format: zodOutputFormat(FeedbackSchema) },
        messages: [{ role: "user", content: buildUserMessage(question, retelling) }],
      });
    } catch (error) {
      if (error instanceof Anthropic.RateLimitError) throw new FeedbackError("upstream_busy");
      if (error instanceof Anthropic.APIError) throw new FeedbackError("upstream_error");
      throw error;
    }
    if (response.stop_reason === "refusal") throw new FeedbackError("refused");
    const text = response.content.flatMap((block) => (block.type === "text" ? [block.text] : [])).join("");
    let parsed;
    try {
      parsed = FeedbackSchema.safeParse(JSON.parse(text));
    } catch {
      throw new FeedbackError("unparseable");
    }
    if (!parsed.success) throw new FeedbackError("unparseable");
    return parsed.data;
  };
}

/**
 * Offline stand-in for local development: no network, no key, predictable answers.
 * Counts how many words of the reference meaning the retelling shares.
 */
export const fakeChecker: CheckRetelling = async (question, retelling) => {
  const words = (text: string) => new Set(text.toLowerCase().match(/[a-z']{5,}/g) ?? []);
  const reference = words(question.gist);
  const shared = [...words(retelling)].filter((w) => reference.has(w)).length;
  const ratio = reference.size === 0 ? 0 : shared / reference.size;
  const verdict = ratio >= 0.5 ? "understood" : ratio > 0 ? "partly" : "missed";
  return {
    verdict,
    feedback: verdict === "understood"
      ? "Yes, that is what they asked. (Offline test feedback.)"
      : `They asked: ${question.gist} (Offline test feedback.)`,
    missed_points: verdict === "understood" ? [] : [question.gist],
  };
};
