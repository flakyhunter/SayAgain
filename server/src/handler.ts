import { FeedbackError, type CheckRetelling } from "./feedback";
import { MAX_RETELLING_LENGTH } from "./prompt";
import { CATEGORIES_WITHOUT_FEEDBACK, findQuestion } from "./questions";

export interface Limiter {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface Deps {
  check: CheckRetelling;
  /** Per-client burst limit. Missing in local tests and `wrangler dev` without the binding. */
  limiter?: Limiter;
}

/** Error codes are part of the contract with the app (`FeedbackServiceError` on the Swift side). */
export type ErrorCode =
  | "not_found"
  | "method_not_allowed"
  | "invalid_request"
  | "unknown_question"
  | "not_available"
  | "rate_limited"
  | "busy"
  | "cannot_check";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });

const error = (code: ErrorCode, status: number) => json({ error: code }, status);

export async function handle(request: Request, deps: Deps): Promise<Response> {
  const url = new URL(request.url);
  if (url.pathname === "/health") return json({ ok: true });
  if (url.pathname !== "/v1/feedback") return error("not_found", 404);
  if (request.method !== "POST") return error("method_not_allowed", 405);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return error("invalid_request", 400);
  }
  const { questionId, retelling } = (body ?? {}) as Record<string, unknown>;
  if (typeof questionId !== "string" || typeof retelling !== "string") return error("invalid_request", 400);
  const text = retelling.trim();
  if (text.length === 0 || text.length > MAX_RETELLING_LENGTH) return error("invalid_request", 400);

  const question = findQuestion(questionId);
  if (!question) return error("unknown_question", 404);
  if (CATEGORIES_WITHOUT_FEEDBACK.has(question.category)) return error("not_available", 403);

  if (deps.limiter) {
    const key = request.headers.get("cf-connecting-ip") ?? "unknown";
    const { success } = await deps.limiter.limit({ key });
    if (!success) return error("rate_limited", 429);
  }

  try {
    const feedback = await deps.check(question, text);
    return json(feedback);
  } catch (e) {
    if (e instanceof FeedbackError) {
      return e.reason === "upstream_busy" ? error("busy", 503) : error("cannot_check", 502);
    }
    throw e;
  }
}
