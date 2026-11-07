// Optional asset maintenance: node tools/build-favicon.mjs
// Requires rsvg-convert (librsvg); not needed for normal development builds.
import { execFileSync } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const source = fileURLToPath(new URL('../web/favicon.svg', import.meta.url));
const sizes = [16, 32, 48];
const images = sizes.map(size => execFileSync('rsvg-convert', ['-w', String(size), '-h', String(size), source]));
const header = Buffer.alloc(6 + sizes.length * 16);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(sizes.length, 4);
let offset = header.length;
images.forEach((png, index) => {
  const entry = 6 + index * 16;
  header[entry] = sizes[index];
  header[entry + 1] = sizes[index];
  header.writeUInt16LE(1, entry + 4);
  header.writeUInt16LE(32, entry + 6);
  header.writeUInt32LE(png.length, entry + 8);
  header.writeUInt32LE(offset, entry + 12);
  offset += png.length;
});
writeFileSync(new URL('../web/favicon.ico', import.meta.url), Buffer.concat([header, ...images]));
