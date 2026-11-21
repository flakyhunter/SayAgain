import Anthropic from "@anthropic-ai/sdk";
import { describe, expect, it } from "vitest";
import { fakeChecker, FeedbackError, makeClaudeChecker } from "../src/feedback";
import { MODEL, SYSTEM_PROMPT } from "../src/prompt";
import { findQuestion } from "../src/questions";

const question = findQuestion("intro-001")!;

/** A client whose HTTP layer returns a canned Messages API response and records the request. */
function fakeClient(status: number, body: unknown) {
  const requests: Record<string, any>[] = [];
  const client = new Anthropic({
    apiKey: "test-key",
    maxRetries: 0,
    fetch: async (_url, init) => {
      requests.push(JSON.parse(String(init?.body)));
      return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
    },
  });
  return { client, requests };
}

const message = (text: string, stop_reason = "end_turn") => ({
  id: "msg_test", type: "message", role: "assistant", model: MODEL, stop_reason, stop_sequence: null,
  content: [{ type: "text", text }],
  usage: { input_tokens: 10, output_tokens: 10 },
});

describe("makeClaudeChecker", () => {
  it("sends the prompt and returns the parsed feedback", async () => {
    const answer = { verdict: "partly", feedback: "Close.", missed_points: ["why you came"] };
    const { client, requests } = fakeClient(200, message(JSON.stringify(answer)));
    const feedback = await makeClaudeChecker(client)(question, "my background");

    expect(feedback).toEqual(answer);
    const sent = requests[0];
    expect(sent.model).toBe(MODEL);
    expect(sent.system).toBe(SYSTEM_PROMPT);
    expect(sent.output_config.effort).toBe("low");
    expect(sent.output_config.format.type).toBe("json_schema");
    expect(sent.messages[0].content).toContain("<retelling>my background</retelling>");
    expect(sent).not.toHaveProperty("temperature");
  });

  it("throws refused when the model declines", async () => {
    const { client } = fakeClient(200, message("", "refusal"));
    await expect(makeClaudeChecker(client)(question, "x")).rejects.toEqual(new FeedbackError("refused"));
  });

  it("throws unparseable when the reply is cut off", async () => {
    const { client } = fakeClient(200, message('{"verdict": "unders', "max_tokens"));
    await expect(makeClaudeChecker(client)(question, "x")).rejects.toEqual(new FeedbackError("unparseable"));
  });

  it("throws unparseable when the JSON does not match the schema", async () => {
    const { client } = fakeClient(200, message('{"verdict": "great", "feedback": "", "missed_points": []}'));
    await expect(makeClaudeChecker(client)(question, "x")).rejects.toEqual(new FeedbackError("unparseable"));
  });

  it("throws upstream_busy on a 429 from Anthropic", async () => {
    const { client } = fakeClient(429, { type: "error", error: { type: "rate_limit_error", message: "slow down" } });
    await expect(makeClaudeChecker(client)(question, "x")).rejects.toEqual(new FeedbackError("upstream_busy"));
  });

  it("throws upstream_error on other API errors", async () => {
    const { client } = fakeClient(500, { type: "error", error: { type: "api_error", message: "boom" } });
    await expect(makeClaudeChecker(client)(question, "x")).rejects.toEqual(new FeedbackError("upstream_error"));
  });
});

describe("fakeChecker (local development only)", () => {
  it("says understood when the retelling shares most of the reference words", async () => {
    expect((await fakeChecker(question, question.gist)).verdict).toBe("understood");
  });

  it("says missed when nothing matches", async () => {
    expect((await fakeChecker(question, "what is your salary")).verdict).toBe("missed");
  });
});
