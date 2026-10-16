// BIMuttern's logo: an otter holding a cube (the model) against its chest, drawn once in a 512
// grid and rendered as
//   colour  -> BIMCamel/Resources/otter_{16,32}.png (head only: ribbon, panel header) and otter_64.png (About box)
//   mono    -> out/bimuttern-catalog.png, 600 px, white on #1B1B1B like the other catalog icons
// The 16 and 32 px icons are the head alone (otter-small.svg): at that size a body and cube are noise.
//   cd tools && npm install --no-save @resvg/resvg-js@2.6.2 && node otter_logo.mjs
import { Resvg } from "@resvg/resvg-js";
import { mkdirSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const res = join(here, "..", "BIMCamel", "Resources");
const out = join(here, "..", "out");
mkdirSync(out, { recursive: true });

const palettes = {
  colour: { bg: null, fur: "#8A5A36", dark: "#5E3A20", light: "#EAD9C2", ink: "#1A120C", hi: "#FFFFFF",
            cubeTop: "#6AAEF0", cubeL: "#2F7FD8", cubeR: "#1E5FAA", cubeLine: "#163F73" },
  mono:   { bg: "#1B1B1B", fur: "#FFFFFF", dark: "#9A9A9A", light: "#CFCFCF", ink: "#1B1B1B", hi: "#FFFFFF",
            cubeTop: "#FFFFFF", cubeL: "#1B1B1B", cubeR: "#1B1B1B", cubeLine: "#1B1B1B" },
};

// Isometric cube with its centre at (cx, cy), half-width w.
function cube(p, cx, cy, w) {
  const h = w * 0.58;
  const pts = (a) => a.map(([x, y]) => `${x},${y}`).join(" ");
  const top = pts([[cx, cy - 2 * h], [cx + w, cy - h], [cx, cy], [cx - w, cy - h]]);
  const left = pts([[cx - w, cy - h], [cx, cy], [cx, cy + 2 * h], [cx - w, cy + h]]);
  const right = pts([[cx + w, cy - h], [cx, cy], [cx, cy + 2 * h], [cx + w, cy + h]]);
  const edge = `stroke="${p.cubeLine}" stroke-width="7" stroke-linejoin="round"`;
  return `<polygon points="${left}" fill="${p.cubeL}" ${edge}/>` +
         `<polygon points="${right}" fill="${p.cubeR}" ${edge}/>` +
         `<polygon points="${top}" fill="${p.cubeTop}" ${edge}/>`;
}

function head(p, cy, detail) {
  const s = [];
  // Small rounded ears, set low on the sides of a broad, flat head.
  for (const x of [150, 362]) {
    s.push(`<circle cx="${x}" cy="${cy - 70}" r="28" fill="${p.fur}"/>`);
    s.push(`<circle cx="${x}" cy="${cy - 70}" r="13" fill="${p.dark}"/>`);
  }
  s.push(`<ellipse cx="256" cy="${cy}" rx="134" ry="102" fill="${p.fur}"/>`);
  // The two whisker pads that make an otter's face, with a chin below.
  s.push(`<ellipse cx="256" cy="${cy + 66}" rx="48" ry="26" fill="${p.light}"/>`);
  for (const x of [222, 290]) s.push(`<ellipse cx="${x}" cy="${cy + 44}" rx="44" ry="34" fill="${p.light}"/>`);
  for (const x of [204, 308]) {
    s.push(`<circle cx="${x}" cy="${cy - 12}" r="${detail ? 15 : 20}" fill="${p.ink}"/>`);
    if (detail) s.push(`<circle cx="${x + 5}" cy="${cy - 17}" r="5" fill="${p.hi}"/>`);
  }
  s.push(`<path d="M 226 ${cy + 16} Q 256 ${cy + 4} 286 ${cy + 16} Q 282 ${cy + 36} 256 ${cy + 44} Q 230 ${cy + 36} 226 ${cy + 16} Z" fill="${p.ink}"/>`);
  if (detail) {
    s.push(`<path d="M 256 ${cy + 44} v 14" stroke="${p.ink}" stroke-width="7" stroke-linecap="round"/>`);
    for (const [x1, y1, x2, y2] of [[196, 40, 112, 26], [198, 56, 116, 64], [316, 40, 400, 26], [314, 56, 396, 64]])
      s.push(`<line x1="${x1}" y1="${cy + y1}" x2="${x2}" y2="${cy + y2}" stroke="${p.ink}" stroke-width="5" stroke-linecap="round"/>`);
  }
  return s.join("");
}

function otter(p) {
  const s = [];
  if (p.bg) s.push(`<rect width="512" height="512" fill="${p.bg}"/>`);
  // Body: a long, rounded trunk under the head, with a lighter chest.
  s.push(`<path d="M 150 250 C 120 330 130 430 176 486 L 336 486 C 382 430 392 330 362 250 Z" fill="${p.fur}"/>`);
  s.push(`<ellipse cx="256" cy="372" rx="78" ry="104" fill="${p.light}"/>`);
  s.push(head(p, 168, true));
  // The cube held against the chest, a paw on each side.
  s.push(cube(p, 256, 384, 66));
  for (const x of [180, 332]) s.push(`<ellipse cx="${x}" cy="378" rx="30" ry="40" fill="${p.dark}"/>`);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">${s.join("")}</svg>`;
}

function otterSmall(p) {
  // Head only, enlarged to fill the square.
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="96 60 320 320">${head(p, 230, false)}</svg>`;
}

function render(svg, size, file) {
  const png = new Resvg(svg, { fitTo: { mode: "width", value: size } }).render().asPng();
  writeFileSync(file, png);
  console.log(`${file.split(/[\\/]/).pop()} ${size}px ${png.length} bytes`);
}

const colour = otter(palettes.colour);
writeFileSync(join(res, "otter.svg"), colour);
writeFileSync(join(res, "otter-small.svg"), otterSmall(palettes.colour));
render(otterSmall(palettes.colour), 16, join(res, "otter_16.png"));
render(otterSmall(palettes.colour), 32, join(res, "otter_32.png"));
render(colour, 64, join(res, "otter_64.png"));
render(colour, 256, join(out, "otter_preview_colour.png"));
render(otterSmall(palettes.colour), 256, join(out, "otter_preview_small.png"));
render(otter(palettes.mono), 600, join(out, "bimuttern-catalog.png"));
