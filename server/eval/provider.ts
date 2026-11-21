// Promptfoo provider that runs the Worker's own checker, so the eval tests the shipped prompt,
// model and parsing, not a copy of them.
import Anthropic from "@anthropic-ai/sdk";
import { fakeChecker, makeClaudeChecker, FeedbackError } from "../src/feedback";
import { findQuestion } from "../src/questions";

export default class RetellingChecker {
  // EVAL_FAKE=1 checks the eval wiring offline, without a key and without spending money.
  private readonly check = process.env.EVAL_FAKE === "1"
    ? fakeChecker
    : makeClaudeChecker(new Anthropic({ maxRetries: 3 }), process.env.EVAL_MODEL);

  id() {
    return `sayagain-checker:${process.env.EVAL_MODEL ?? "default"}`;
  }

  async callApi(_prompt: string, context: { vars: Record<string, unknown> }) {
    const question = findQuestion(String(context.vars.questionId));
    if (!question) return { error: `Unknown question ${context.vars.questionId}` };
    try {
      const feedback = await this.check(question, String(context.vars.retelling));
      return { output: JSON.stringify(feedback) };
    } catch (error) {
      if (error instanceof FeedbackError) return { output: JSON.stringify({ error: error.reason }) };
      return { error: String(error) };
    }
  }
}
