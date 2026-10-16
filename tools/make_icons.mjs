// Renders BIMCamel/Resources/otter.svg to the ribbon/About icons otter_16.png and otter_32.png.
//   cd tools && npm install @resvg/resvg-js@2.6.2 && node make_icons.mjs
import { Resvg } from "@resvg/resvg-js";
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const res = join(dirname(fileURLToPath(import.meta.url)), "..", "BIMCamel", "Resources");
const svg = readFileSync(join(res, "otter.svg"));
for (const size of [16, 32]) {
  const png = new Resvg(svg, { fitTo: { mode: "width", value: size } }).render().asPng();
  writeFileSync(join(res, `otter_${size}.png`), png);
  console.log(`otter_${size}.png ${png.length} bytes`);
}
