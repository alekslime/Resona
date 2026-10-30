// Pull a JSON object out of model text that may include code fences or chatter.
export function extractJson(text) {
  if (typeof text !== "string") throw new Error("The model returned no text.");
  const unfenced = text.replace(/```(?:json)?/gi, "");
  const start = unfenced.indexOf("{");
  const end = unfenced.lastIndexOf("}");
  if (start === -1 || end <= start) throw new Error("The model did not return JSON.");
  return JSON.parse(unfenced.slice(start, end + 1));
}
