// Lesson / quiz construction for Muse Spark, plus deterministic fallbacks.
// The fallbacks are built only from what Spark already said about each part
// (label / spoken / detail), so a lesson or quiz can never hard-fail on stage:
// if the model call fails or returns junk, the student still gets a lesson.
import { extractJson } from "./json.js";

const clampText = (v, max = 600) => String(v ?? "").trim().slice(0, max);

/** Normalise the regions a client sends us. Never trust ids/labels blindly. */
export function cleanRegions(regions) {
  return (Array.isArray(regions) ? regions : [])
    .filter((r) => r && typeof r.id === "string" && r.id.trim() && typeof r.label === "string" && r.label.trim())
    .slice(0, 8)
    .map((r) => ({
      id: r.id.slice(0, 80),
      label: clampText(r.label, 120),
      spoken: clampText(r.spoken ?? r.label, 400),
      detail: clampText(r.detail ?? r.spoken ?? r.label, 900),
    }));
}

const regionList = (regions) =>
  regions.map((r, i) => `${i + 1}. id="${r.id}" label="${r.label}" spoken="${r.spoken}" detail="${r.detail}"`).join("\n");

export function lessonPrompt({ title, overview, regions }) {
  return `A blind student is exploring a picture by touch. It is titled "${title}". Overview: ${overview}
Its parts, in reading order:
${regionList(regions)}

Write a short guided lesson that walks the student through the parts in this order, one step at a time.
Return only JSON in this shape:
{"steps": [{"regionId": "...", "say": "..."}]}
Rules:
- First step: regionId null, welcome the student and say what the lesson will cover, in one or two plain sentences.
- Then exactly one step per part, in the order above, with that part's regionId. Each step: two to three plain sentences that teach what the part is and why it matters, building on the parts before it. Write for listening, not reading.
- Last step: regionId null, sum up how the parts fit together in one or two sentences.
- Never invent numbers, words or facts that are not in the parts above. No lists, no markdown.`;
}

export function quizPrompt({ title, regions }) {
  return `A blind student has just explored a picture by touch, titled "${title}". Its parts:
${regionList(regions)}

Write a short check-your-understanding quiz. Return only JSON in this shape:
{"questions": [{"kind": "find", "regionId": "...", "question": "..."}, {"kind": "say", "regionId": "...", "question": "...", "expected": "..."}]}
Rules:
- 3 to 5 questions total, mixed kinds, in reading order of the parts they ask about.
- "find": ask the student to touch one part, e.g. "Find the sun." regionId is that part. One part per question.
- "say": ask a short spoken question whose answer is in that part's detail. "expected" is a short phrase with the key facts a correct answer must contain.
- Plain words, no lists, no markdown. Never invent facts not in the parts above.`;
}

export function gradePrompt({ question, expected, answer }) {
  return `A blind student was asked: "${question}"
A correct answer contains: "${expected}"
The student answered: "${answer}"
Is the student's answer correct in meaning (wording may differ)? Return only JSON: {"correct": true, "say": "..."}
"say" is one short plain sentence read aloud: say whether it is right, and if not, gently give the right answer. No lists, no markdown.`;
}

export function parseLesson(text, regions) {
  const json = extractJson(text);
  const ids = new Set(regions.map((r) => r.id));
  const steps = (Array.isArray(json.steps) ? json.steps : [])
    .filter((s) => s && clampText(s.say, 20))
    .slice(0, regions.length + 2)
    .map((s) => ({
      regionId: typeof s.regionId === "string" && ids.has(s.regionId) ? s.regionId : null,
      say: clampText(s.say, 700),
    }));
  if (steps.length < 2) throw new Error("The model returned no usable lesson.");
  return { steps };
}

export function parseQuiz(text, regions) {
  const json = extractJson(text);
  const byId = new Map(regions.map((r) => [r.id, r]));
  const questions = (Array.isArray(json.questions) ? json.questions : [])
    .filter((q) => q && byId.has(q.regionId) && clampText(q.question, 10))
    .slice(0, 5)
    .map((q) =>
      q.kind === "say"
        ? { kind: "say", regionId: q.regionId, question: clampText(q.question, 400), expected: clampText(q.expected ?? byId.get(q.regionId).detail, 400) }
        : { kind: "find", regionId: q.regionId, question: clampText(q.question, 400) },
    );
  if (!questions.length) throw new Error("The model returned no usable quiz.");
  return { questions };
}

export function parseGrade(text) {
  const json = extractJson(text);
  return { correct: json.correct === true, say: clampText(json.say, 400) || (json.correct ? "Correct." : "Not quite.") };
}

/** A lesson with no model at all: intro, each part's own words, summary. */
export function fallbackLesson({ title, overview, regions }) {
  return {
    steps: [
      { regionId: null, say: `Lesson: ${title}. ${overview} We will visit ${regions.length} parts, one at a time. Swipe the left edge, or use the next step button, to move on.` },
      ...regions.map((r) => ({ regionId: r.id, say: `${r.label}. ${r.detail}` })),
      { regionId: null, say: `That is the whole picture. ${overview} You can go back to exploring, or try the quiz.` },
    ],
  };
}

/** A quiz with no model at all: find every part, then one spoken recall. */
export function fallbackQuiz({ regions }) {
  const questions = regions.slice(0, 4).map((r) => ({
    kind: "find",
    regionId: r.id,
    question: `Find the ${r.label}. Drag a finger over the picture until you feel it.`,
  }));
  const last = regions[regions.length - 1];
  if (last) {
    questions.push({
      kind: "say",
      regionId: last.id,
      question: `In your own words: what is the ${last.label}, and why does it matter here?`,
      expected: last.detail,
    });
  }
  return { questions };
}
