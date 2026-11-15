# Feedback API contract

Example bodies shared by both sides. The Worker tests check them against its Zod schema
(`server/test/contract.test.ts`), the app tests decode them (`FeedbackContractTests`). If one
side changes the shape, the other side's tests fail.

`POST /v1/feedback` with `request.json` returns one of `understood.json`, `partly.json`,
`missed.json`, or an error body `{"error": "<code>"}`:

| Status | Code | Meaning |
|---|---|---|
| 400 | `invalid_request` | Missing fields, blank or over 400 characters |
| 403 | `not_available` | Category without AI feedback (kids' school) |
| 404 | `unknown_question` | Question id is not in the app |
| 429 | `rate_limited` | Too many checks from this client in a minute |
| 502 | `cannot_check` | Claude refused or returned something unusable |
| 503 | `busy` | Anthropic is rate limiting the Worker |
