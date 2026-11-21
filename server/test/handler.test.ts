import { describe, expect, it, vi } from "vitest";
import { FeedbackError, type CheckRetelling } from "../src/feedback";
import { handle, type Limiter } from "../src/handler";
import { MAX_RETELLING_LENGTH, type Feedback } from "../src/prompt";

const understood: Feedback = { verdict: "understood", feedback: "Yes.", missed_points: [] };

const post = (body: unknown, headers: Record<string, string> = {}) =>
  new Request("https://worker.test/v1/feedback", {
    method: "POST",
    headers: { "content-type": "application/json", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });

const valid = { questionId: "intro-001", retelling: "Tell them about my background and why I moved here." };

async function call(request: Request, check: CheckRetelling = async () => understood, limiter?: Limiter) {
  const response = await handle(request, { check, limiter });
  return { status: response.status, body: (await response.json()) as Record<string, unknown> };
}

describe("POST /v1/feedback", () => {
  it("returns the checker's feedback for a known question", async () => {
    const check = vi.fn<CheckRetelling>(async () => understood);
    const { status, body } = await call(post(valid), check);
    expect(status).toBe(200);
    expect(body).toEqual(understood);
    expect(check).toHaveBeenCalledWith(expect.objectContaining({ id: "intro-001" }), valid.retelling);
  });

  it("trims the retelling before checking it", async () => {
    const check = vi.fn<CheckRetelling>(async () => understood);
    await call(post({ ...valid, retelling: "   my background  \n" }), check);
    expect(check.mock.calls[0][1]).toBe("my background");
  });

  it.each([
    ["not JSON", "{"],
    ["no questionId", { retelling: "hi" }],
    ["no retelling", { questionId: "intro-001" }],
    ["retelling is not a string", { questionId: "intro-001", retelling: 42 }],
    ["blank retelling", { questionId: "intro-001", retelling: "   " }],
    ["retelling over the limit", { questionId: "intro-001", retelling: "a".repeat(MAX_RETELLING_LENGTH + 1) }],
  ])("rejects a request with %s and never calls Claude", async (_, body) => {
    const check = vi.fn<CheckRetelling>();
    const { status, body: response } = await call(post(body), check);
    expect(status).toBe(400);
    expect(response).toEqual({ error: "invalid_request" });
    expect(check).not.toHaveBeenCalled();
  });

  it("accepts a retelling exactly at the limit", async () => {
    const { status } = await call(post({ ...valid, retelling: "a".repeat(MAX_RETELLING_LENGTH) }));
    expect(status).toBe(200);
  });

  it("only checks questions that ship in the app, so it is not an open proxy", async () => {
    const check = vi.fn<CheckRetelling>();
    const { status, body } = await call(post({ ...valid, questionId: "write-me-a-poem" }), check);
    expect(status).toBe(404);
    expect(body).toEqual({ error: "unknown_question" });
    expect(check).not.toHaveBeenCalled();
  });

  it("keeps the kids' school category off the network", async () => {
    const check = vi.fn<CheckRetelling>();
    const { status, body } = await call(post({ ...valid, questionId: "school-001" }), check);
    expect(status).toBe(403);
    expect(body).toEqual({ error: "not_available" });
    expect(check).not.toHaveBeenCalled();
  });

  it("limits each client by IP before calling Claude", async () => {
    const limiter = { limit: vi.fn(async () => ({ success: false })) };
    const check = vi.fn<CheckRetelling>();
    const { status, body } = await call(post(valid, { "cf-connecting-ip": "203.0.113.7" }), check, limiter);
    expect(status).toBe(429);
    expect(body).toEqual({ error: "rate_limited" });
    expect(limiter.limit).toHaveBeenCalledWith({ key: "203.0.113.7" });
    expect(check).not.toHaveBeenCalled();
  });

  it("does not spend the rate limit on invalid requests", async () => {
    const limiter = { limit: vi.fn(async () => ({ success: true })) };
    await call(post({ questionId: "intro-001" }), undefined, limiter);
    expect(limiter.limit).not.toHaveBeenCalled();
  });

  it.each([
    ["upstream_busy", 503, "busy"],
    ["upstream_error", 502, "cannot_check"],
    ["refused", 502, "cannot_check"],
    ["unparseable", 502, "cannot_check"],
  ] as const)("maps %s from the checker to %i %s", async (reason, status, code) => {
    const result = await call(post(valid), async () => { throw new FeedbackError(reason); });
    expect(result).toEqual({ status, body: { error: code } });
  });
});

describe("routing", () => {
  it("answers the health check", async () => {
    const { status, body } = await call(new Request("https://worker.test/health"));
    expect(status).toBe(200);
    expect(body).toEqual({ ok: true });
  });

  it("rejects GET on the feedback endpoint", async () => {
    const { status } = await call(new Request("https://worker.test/v1/feedback"));
    expect(status).toBe(405);
  });

  it("returns 404 for unknown paths", async () => {
    const { status } = await call(new Request("https://worker.test/v1/chat", { method: "POST", body: "{}" }));
    expect(status).toBe(404);
  });
});
