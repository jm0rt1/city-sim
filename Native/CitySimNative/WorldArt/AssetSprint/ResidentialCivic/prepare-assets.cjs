#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const sharp = require("sharp");

const root = __dirname;
const sourceDirectory = path.join(root, "GeneratedSources");
const outputDirectory = path.resolve(
  root,
  "../../../Sources/CitySimNative/Resources/WorldAssets.atlas/AssetSprintResidentialCivic"
);

const assets = [
  { name: "cedar-craftsman", footprint: [2, 2] },
  { name: "cedar-rowhouses", footprint: [2, 3] },
  { name: "cedar-courtyard-apartments", footprint: [3, 3] },
  { name: "cedar-neighborhood-library", footprint: [3, 3] },
  { name: "cedar-city-hall", footprint: [4, 4] },
];

async function removeMagentaKey({ name, footprint }) {
  const input = path.join(sourceDirectory, `${name}-source.png`);
  const output = path.join(outputDirectory, `${name}.png`);
  const { data, info } = await sharp(input)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });

  const pixelCount = info.width * info.height;
  const background = new Uint8Array(pixelCount);
  const queue = new Int32Array(pixelCount);
  let head = 0;
  let tail = 0;

  function isBackdrop(index) {
    const offset = index * 4;
    const red = data[offset];
    const green = data[offset + 1];
    const blue = data[offset + 2];
    return red > 138 && blue > 112 && Math.min(red, blue) - green > 24;
  }

  function enqueue(index) {
    if (background[index] || !isBackdrop(index)) return;
    background[index] = 1;
    queue[tail++] = index;
  }

  for (let x = 0; x < info.width; x += 1) {
    enqueue(x);
    enqueue((info.height - 1) * info.width + x);
  }
  for (let y = 0; y < info.height; y += 1) {
    enqueue(y * info.width);
    enqueue(y * info.width + info.width - 1);
  }

  while (head < tail) {
    const index = queue[head++];
    const x = index % info.width;
    const y = Math.floor(index / info.width);
    if (x > 0) enqueue(index - 1);
    if (x + 1 < info.width) enqueue(index + 1);
    if (y > 0) enqueue(index - info.width);
    if (y + 1 < info.height) enqueue(index + info.width);
  }

  for (let index = 0; index < pixelCount; index += 1) {
    data[index * 4 + 3] = background[index] ? 0 : 255;
  }

  let minimumX = info.width;
  let maximumX = 0;
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] < 24) continue;
    const x = (offset / 4) % info.width;
    minimumX = Math.min(minimumX, x);
    maximumX = Math.max(maximumX, x);
  }

  const authoredWidth = maximumX - minimumX + 1;
  const projectedFootprintWidth = (footprint[0] + footprint[1]) * 44;
  const normalizedWidth = Math.round(info.width * projectedFootprintWidth / authoredWidth);

  await sharp(data, { raw: info })
    .resize({ width: normalizedWidth, kernel: sharp.kernel.lanczos3 })
    .png({ compressionLevel: 9, adaptiveFiltering: false, palette: false })
    .toFile(output);
}

async function main() {
  fs.mkdirSync(outputDirectory, { recursive: true });
  for (const asset of assets) await removeMagentaKey(asset);
}

main().catch((error) => {
  process.stderr.write(`${error.stack ?? error}\n`);
  process.exitCode = 1;
});
