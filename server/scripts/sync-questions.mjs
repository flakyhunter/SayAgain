// Copies the fields the Worker needs from the app's question bank into src/questions.json.
// The Worker only checks retellings of questions that ship in the app, so it can't be used
// as a general-purpose proxy to Claude.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const here = path.dirname(fileURLToPath(import.meta.url));
const source = path.join(here, "../../Packages/SayAgainKit/Sources/SayAgainKit/Resources/questions.json");
const target = path.join(here, "../src/questions.json");

const questions = JSON.parse(readFileSync(source, "utf8")).map(({ id, category, text, rephrase, gist }) => ({
  id, category, text, rephrase, gist,
}));
const output = JSON.stringify(questions, null, 2) + "\n";

if (process.argv.includes("--check")) {
  const current = readFileSync(target, "utf8");
  if (current !== output) {
    console.error("src/questions.json is out of date. Run: npm run sync-questions");
    process.exit(1);
  }
  console.log(`src/questions.json is up to date (${questions.length} questions).`);
} else {
  writeFileSync(target, output);
  console.log(`Wrote ${questions.length} questions to src/questions.json`);
}
