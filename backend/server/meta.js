// Everything that talks to the Meta Model API lives here.
//   Muse Spark (muse-spark-1.3): looks at the picture, names its parts, answers questions.
//   SAM 3.1   (sam-3.1)        : returns the exact pixels of each named part.
import OpenAI from "openai";
import { parseImageStream } from "@meta-sam/parser";
import { extractJson } from "./json.js";
import { fallbackLesson, fallbackQuiz, gradePrompt, lessonPrompt, parseGrade, parseLesson, parseQuiz, quizPrompt } from "./learn.js";

const PARTS_PROMPT = `You are helping a blind student explore a picture by touch. List the distinct parts of this picture that the student would want to find with a finger and hear about.

Return only JSON in this shape:
{"title": "...", "kind": "chart | diagram | photo | map | other", "overview": "...", "parts": [{"label": "...", "where": [0.0, 0.0, 1.0, 1.0], "spoken": "...", "detail": "..."}]}

Rules:
- overview: two or three plain sentences saying what the picture is and how it is laid out (what is at the top, bottom, left and right).
- parts: 3 to 8, in reading order (top to bottom, left to right). Fewer is better than padding.
- label: a short, concrete noun phrase of 1 to 4 words naming something you can see, such as "red bar" or "left lung". It is sent to an image segmentation model, so describe what the thing looks like. No verbs, questions, lists or abstract ideas. One thing per label. If several things look alike, separate them with a visible attribute or position in the label.
- spoken: one short sentence read aloud the moment a finger rests on the part.
- detail: two to four sentences: what it is, why it matters, and any numbers or words printed on or beside it. Plain words.
- Never invent text or numbers that are not in the picture.
- where: a rough box around the part as fractions of the whole picture, [left, top, right, bottom], each from 0 to 1, with 0,0 at the top left corner. It only needs to be roughly right.
- Pages with several photographs or panels (textbook spreads, figure grids, collages): treat each whole photograph or panel as ONE part. Its label names what the whole photo shows (such as "teeth with braces photo"), its where box covers the whole photo, not one tooth or detail inside it.
- Avoid labels ending in row, pair, group, set or close-up, and never name a single small repeated item (one tooth, one bar, one dot) when the student needs the whole group it belongs to.`;

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

export async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let next = 0;
  const workers = Array.from({ length: Math.min(limit, items.length) }, async () => {
    while (next < items.length) {
      const i = next++;
      out[i] = await fn(items[i], i);
    }
  });
  await Promise.all(workers);
  return out;
}

export function normBox(v) {
  if (!Array.isArray(v) || v.length !== 4) return null;
  const n = v.map(Number);
  if (n.some((x) => !Number.isFinite(x) || x < 0 || x > 1)) return null;
  const [l, t, r, b] = n;
  return r > l && b > t ? [l, t, r, b] : null;
}
export function createMeta({ apiKey, baseURL = "https://api.meta.ai/v1", sparkModel = "muse-spark-1.3", samModel = "sam-3.1", effort = "low" }) {
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
    samModel,

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

    /** One concept per request: SAM 3.1 does not accept lists. Zero matches is a normal result. */
    async segment(dataUrl, concept) {
      return withRetry(async () => {
        const events = await client.responses.create({
          model: samModel,
          input: [
            {
              type: "message",
              role: "user",
              content: [
                { type: "input_text", text: concept },
                { type: "input_image", image_url: dataUrl },
              ],
            },
          ],
          stream: true,
          metadata: { mask_encoding: "one_bit", include_confidence: "true" },
        });
        try {
          return await parseImageStream(events).finalResult;
        } catch (err) {
          // Zero matches can arrive as a stream with no output text at all. That is a normal result.
          if (err?.code === "response_lane") return { records: [], diagnostics: [], outcome: { status: "completed" } };
          throw err;
        }
      });
    },

    async ask(dataUrl, question, { title, regionLabel }) {
      const where = regionLabel
        ? `The student's finger is on "${regionLabel}".`
        : "The student's finger is not on a named part right now.";
      const prompt = `A blind student is exploring this picture by touch${title ? ` (it is titled "${title}")` : ""}. ${where}
Answer their question in at most three short sentences, in plain words that sound natural read aloud. No lists, no markdown. If the picture does not show the answer, say so.
Question: ${question}`;
      return (
        await spark(
          [
            { type: "input_text", text: prompt },
            { type: "input_image", image_url: dataUrl },
          ],
          3000,
        )
      ).trim();
    },

    /** Text-only Spark call: lesson/quiz work is built from region text, never a second image read. */
    async generate(prompt, maxTokens = 3000) {
      return spark([{ type: "input_text", text: prompt }], maxTokens);
    },

    /** Guided lesson steps. Falls back to a template lesson so it can never hard-fail. */
    async lesson(ctx) {
      try {
        return parseLesson(await this.generate(lessonPrompt(ctx), 4000), ctx.regions);
      } catch (err) {
        console.error("lesson generation failed, using fallback:", err?.message ?? err);
        return fallbackLesson(ctx);
      }
    },

    /** Quiz questions (find-it + say-it). Falls back to find-it questions from the regions. */
    async quiz(ctx) {
      try {
        return parseQuiz(await this.generate(quizPrompt(ctx), 3000), ctx.regions);
      } catch (err) {
        console.error("quiz generation failed, using fallback:", err?.message ?? err);
        return fallbackQuiz(ctx);
      }
    },

    async grade({ question, expected, answer }) {
      return parseGrade(await this.generate(gradePrompt({ question, expected, answer }), 800));
    },

    /** Multi-turn voice tutor: like ask(), but the conversation so far travels with the question. */
    async chat(dataUrl, question, { title, regionLabel, history = [] }) {
      const where = regionLabel
        ? `The student's finger is on "${regionLabel}".`
        : "The student's finger is not on a named part right now.";
      const past = history
        .slice(-6)
        .map((h) => `Student: ${h.q}\nTutor: ${h.a}`)
        .join("\n");
      const prompt = `You are a patient tutor helping a blind student explore this picture by touch${title ? ` (it is titled "${title}")` : ""}. ${where}
${past ? `Conversation so far:\n${past}\n` : ""}Answer the new question in at most three short sentences, in plain words that sound natural read aloud. No lists, no markdown. Build on what was already discussed. If the picture does not show the answer, say so.
New question: ${question}`;
      return (
        await spark(
          [
            { type: "input_text", text: prompt },
            { type: "input_image", image_url: dataUrl },
          ],
          3000,
        )
      ).trim();
    },
  };
}
