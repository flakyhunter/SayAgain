import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { FeedbackSchema } from "../src/prompt";
import { findQuestion } from "../src/questions";

const read = (name: string) => JSON.parse(readFileSync(`../contract/feedback/${name}`, "utf8"));

describe("shared API contract (contract/feedback)", () => {
  it.each(["understood.json", "partly.json", "missed.json"])("%s matches the Worker's response schema", (name) => {
    expect(FeedbackSchema.parse(read(name))).toEqual(read(name));
  });

  it("request.json names a real question", () => {
    expect(findQuestion(read("request.json").questionId)).toBeDefined();
  });
});
