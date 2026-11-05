// Everything that talks to the Meta Model API lives here.
//   Muse Spark (muse-spark-1.3): looks at the picture, names its parts, answers questions.
import OpenAI from "openai";
import { extractJson } from "./json.js";

const PARTS_PROMPT = `You are helping a blind student explore a picture by touch. List the distinct parts of this picture that the student would want to find with a finger and hear about.

Return only JSON in this shape:
{"title": "...", "kind": "chart | diagram | photo | map | other", "overview": "...", "parts": [{"label": "...", "where": [0.0, 0.0, 1.0, 1.0], "spoken": "...", "detail": "..."}]}

Rules:
- overview: two or three plain sentences saying what the picture is and how it is laid out (what is at the top, bottom, left and right).
- parts: 3 to 8, in reading order (top to bottom, left to right). Fewer is better than padding.
- label: a short, concrete noun phrase of 1 to 4 words naming something you can see, such as "red bar" or "left lung". Name it by what it looks like. No verbs, questions, lists or abstract ideas. One thing per label. If several things look alike, separate them with a visible attribute or position in the label.
- spoken: one short sentence read aloud the moment a finger rests on the part.
- detail: two to four sentences: what it is, why it matters, and any numbers or words printed on or beside it. Plain words.
- Never invent text or numbers that are not in the picture.
- where: a tight box around the part as fractions of the whole picture, [left, top, right, bottom], each from 0 to 1, with 0,0 at the top left corner. Hug the part's edges with no empty margins: the box is the touch target, so a loose box makes the wrong part speak. Boxes must not overlap unless the parts truly overlap.
- Pages with several photographs or panels (textbook spreads, figure grids, collages): treat each whole photograph or panel as ONE part. Its label names what the whole photo shows (such as "teeth with braces photo"), its where box covers the whole photo, not one tooth or detail inside it.
- Avoid labels ending in row, pair, group, set or close-up, and never name a single small repeated item (one tooth, one bar, one dot) when the student needs the whole group it belongs to.`;

const QUIZ_PROMPT = `You are writing a short self-test for a blind student who just discussed a topic with a tutor. The questions are read aloud, so every word must sound natural spoken.

Return only JSON in this shape:
{"questions": [{"prompt": "...", "options": ["...", "...", "..."], "correct": 0, "explanation": "..."}]}

Rules:
- questions: exactly 5, each testing one idea from the conversation below. Ask about what was discussed, not trivia from elsewhere.
- prompt: one plain question, no markdown, no lists.
- options: 3 or 4 short answers in plain words. Wrong options must be plausible but clearly wrong.
- correct: the 0-based index of the right option.
- explanation: one short sentence saying why the right answer is right.
- If the conversation is too thin for 5 questions, still write 5 about the topic itself.`;

/**
 * The validated quiz payload: exactly 5 questions with 3-4 options each,
 * a correct index and a one-line explanation. Anything short of that is
 * an error, never a half-empty quiz.
 */
export function quizPayload(topic, json) {
  const questions = (Array.isArray(json?.questions) ? json.questions : [])
    .filter((q) => q && typeof q.prompt === "string" && q.prompt.trim())
    .map((q) => ({
      prompt: q.prompt.trim(),
      options: (Array.isArray(q.options) ? q.options : [])
        .filter((o) => typeof o === "string" && o.trim())
        .map((o) => o.trim())
        .slice(0, 4),
      correctIndex: Number(q.correct),
      explanation: String(q.explanation ?? "").trim(),
    }))
    .filter(
      (q) =>
        q.options.length >= 3 &&
        Number.isInteger(q.correctIndex) &&
        q.correctIndex >= 0 &&
        q.correctIndex < q.options.length &&
        q.explanation,
    )
    .slice(0, 5);
  if (questions.length < 5) throw new Error("The model did not return a full quiz.");
  return { topic, questions };
}

export function textOf(response) {
  if (typeof response?.output_text === "string" && response.output_text) return response.output_text;
  const chunks = [];
  for (const item of response?.output ?? []) {
    for (const part of item?.content ?? []) {
      if (part?.type === "output_text" && typeof part.text === "string") chunks.push(part.text);
    }
  }
  return chunks.join("");
}

async function withRetry(fn, tries = 2) {
  let last;
  for (let i = 0; i < tries; i++) {
    try {
      return await fn();
    } catch (err) {
      last = err;
      const status = err?.status;
      const retryable = status === 429 || (status >= 500 && status < 600) || status === undefined;
      if (!retryable || i === tries - 1) break;
      await new Promise((r) => setTimeout(r, 800 * (i + 1)));
    }
  }
  throw last;
}

export function normBox(v) {
  if (!Array.isArray(v) || v.length !== 4) return null;
  const n = v.map(Number);
  if (n.some((x) => !Number.isFinite(x) || x < 0 || x > 1)) return null;
  const [l, t, r, b] = n;
  return r > l && b > t ? [l, t, r, b] : null;
}
export function createMeta({ apiKey, baseURL = "https://api.meta.ai/v1", sparkModel = "muse-spark-1.3", effort = "low" }) {
  const client = new OpenAI({ apiKey, baseURL });

  // Muse Spark is a reasoning model. Try with our preferred options first, then drop any the API rejects.
  async function spark(content, maxTokens) {
    const base = { model: sparkModel, input: [{ type: "message", role: "user", content }] };
    const variants = [
      { ...base, reasoning: { effort }, max_output_tokens: maxTokens },
      { ...base, max_output_tokens: maxTokens },
      base,
    ];
    let lastErr;
    for (const body of variants) {
      try {
        return textOf(await withRetry(() => client.responses.create(body)));
      } catch (err) {
        lastErr = err;
        if (err?.status !== 400) throw err;
      }
    }
    throw lastErr;
  }

  return {
    sparkModel,

    async describeParts(dataUrl) {
      const text = await spark(
        [
          { type: "input_text", text: PARTS_PROMPT },
          { type: "input_image", image_url: dataUrl },
        ],
        6000,
      );
      const json = extractJson(text);
      const parts = (Array.isArray(json.parts) ? json.parts : [])
        .filter((p) => p && typeof p.label === "string" && p.label.trim())
        .slice(0, 8)
        .map((p) => ({
          label: p.label.trim(),
          spoken: String(p.spoken ?? p.label).trim(),
          detail: String(p.detail ?? p.spoken ?? p.label).trim(),
          where: normBox(p.where),
        }));
      if (!parts.length) throw new Error("The model found no parts in this picture.");
      return {
        title: String(json.title ?? "Picture").trim(),
        kind: String(json.kind ?? "other").trim(),
        overview: String(json.overview ?? "").trim(),
        parts,
      };
    },

    /**
     * Multi-turn voice tutor: like ask(), but the conversation so far travels
     * with the question. Without a picture it is a text-only tutor: same
     * voice, no picture to look at.
     */
    async chat(dataUrl, question, { title, regionLabel, history = [] }) {
      const past = history
        .slice(-6)
        .map((h) => `Student: ${h.q}\nTutor: ${h.a}`)
        .join("\n");
      const pastBlock = past ? `Conversation so far:\n${past}\n` : "";
      const style =
        "Answer the new question in at most three short sentences, in plain words that sound natural read aloud. No lists, no markdown. Build on what was already discussed.";
      const prompt = dataUrl
        ? `You are a patient tutor helping a blind student explore this picture by touch${title ? ` (it is titled "${title}")` : ""}. ${
            regionLabel
              ? `The student's finger is on "${regionLabel}".`
              : "The student's finger is not on a named part right now."
          }
${pastBlock}${style} If the picture does not show the answer, say so.
New question: ${question}`
        : `You are a patient tutor chatting with a blind student. No picture is open.
${pastBlock}${style} If you do not know the answer, say so.
New question: ${question}`;
      const content = [{ type: "input_text", text: prompt }];
      if (dataUrl) content.push({ type: "input_image", image_url: dataUrl });
      return (await spark(content, 3000)).trim();
    },

    /**
     * A 5-question self-test on what was just discussed. Text only: the
     * topic plus the conversation so far, through the same Spark box as
     * chat. Anything short of 5 valid questions is an error, never a
     * half-empty quiz.
     */
    async quiz(topic, { history = [] }) {
      const past = history
        .slice(-6)
        .map((h) => `Student: ${h.q}\nTutor: ${h.a}`)
        .join("\n");
      const text = await spark(
        [
          {
            type: "input_text",
            text: `${QUIZ_PROMPT}\nTopic: ${topic}\nConversation:\n${past || "(none yet)"}`,
          },
        ],
        4000,
      );
      return quizPayload(topic, extractJson(text));
    },
  };
}
