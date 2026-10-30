import { parseImageStream } from "@meta-sam/parser";

// One frame line copied from Meta's SAM docs (https://dev.meta.ai/docs/sam/reading-segmentation):
// two "button" matches, 320x334 source. Used as a real-format fixture for the parser wiring.
export const DOCS_LINE =
  "<0f>0<|box;x1=211;y1=228;x2=270;y2=254;w=320;h=334|><|mask;x=0;y=0;data=27,60,~!!!!M!0c[0o91w?q1!pIH4pPRVp2B3'7`e.ioeAf6-k/#Xd8%dX9x(|>," +
  "1<|box;x1=155;y1=228;x2=202;y2=254;w=320;h=334|><|mask;x=0;y=0;data=27,48,~!!!!J!0c[q=Pj_zs=*4C4(/./x#:/`S_GnD`=o3?X{emCgO$y@|>";

const lane = { item_id: "item", output_index: 0, content_index: 0 };

export async function parseLine(line) {
  async function* events() {
    if (line) yield { type: "response.output_text.delta", delta: line, ...lane };
    yield { type: "response.output_text.done", text: line, ...lane };
    yield { type: "response.completed" };
  }
  return parseImageStream(events()).finalResult;
}
