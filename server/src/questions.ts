import questions from "./questions.json";

export interface QuestionRecord {
  id: string;
  category: string;
  text: string;
  rephrase: string;
  gist: string;
}

/** Categories without AI feedback. The kids' school category stays fully on-device. */
export const CATEGORIES_WITHOUT_FEEDBACK = new Set(["school"]);

const byID = new Map<string, QuestionRecord>((questions as QuestionRecord[]).map((q) => [q.id, q]));

export function findQuestion(id: string): QuestionRecord | undefined {
  return byID.get(id);
}

export const questionCount = byID.size;
