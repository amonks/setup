#!/usr/bin/env node

// # curl 'https://api.earthclassmail.com/v1/bulk-download?per_page=500' \
// # 	-H "x-api-key: $EARTH_CLASS_MAIL_API_KEY" \
// # 	-o mail.json

const https = require("https");
const fs = require("fs");
const path = require("path");
const child_process = require("child_process");
const { promisify } = require("util");
const fs_stat = promisify(fs.stat);
const fs_mkdir = promisify(fs.mkdir);

main().catch((e) => {
  process.stderr.write(`error: ${e}\n`);
});

async function main() {
  let apiKey = process.env.EARTH_CLASS_MAIL_API_KEY;

  if (!apiKey) {
    const lines = fs
      .readFileSync(path.join(__dirname, ".envrc"), { encoding: "utf8" })
      .split("\n");
    const line = lines.find((l) => l.includes("EARTH_CLASS_MAIL_API_KEY"));
    const parts = line.split("=");
    const key = parts[1].replaceAll('"', "");
    apiKey = key;
  }

  if (!apiKey) {
    throw Error("no api key");
  }

  const data = await apiGet(apiKey, "v1/bulk-download?per_page=500");

  const pieces = JSON.parse(data).data;

  const toDownload = [];
  process.stderr.write(`${pieces.length} pieces\n`);
  for (const piece of pieces) {
    const { created_at, piece_id } = piece;

    const ymd = created_at.slice(0, 10);
    const dir = `/data/tank/mirror/mail/${ymd}/${piece_id}/`;
    if (!(await stat(dir))) {
      await fs_mkdir(dir, { recursive: true });
    }

    for (const scan of piece.media) {
      const { url } = scan;

      const name = nameMedia(scan);
      const path = dir + name;

      if (await stat(path)) {
        process.stderr.write(`skip: ${path}\n`);
        continue;
      }

      toDownload.push([url, path]);
    }
  }
  process.stderr.write(`${toDownload.length} to download\n`);
  for (let i = 0; i < toDownload.length; i++) {
    const [url, path] = toDownload[i];
    process.stderr.write(`download [${i + 1}/${toDownload.length}]: ${path}\n`);
    await download(url, path);
  }
}

async function apiGet(apiKey, path) {
  const httpOptions = {
    headers: {
      "x-api-key": apiKey,
    },
  };

  const response = await new Promise((res, rej) => {
    https.get(
      `https://api.earthclassmail.com/${path}`,
      httpOptions,
      (response, err) => {
        if (err) {
          rej(err);
        }
        res(response);
      },
    );
  });

  let data = "";
  response.on("data", (chunk) => {
    data += chunk;
  });

  await new Promise((res) => {
    response.on("end", () => {
      res();
    });
  });

  return data;
}

function download(url, target) {
  return new Promise((res, rej) => {
    child_process.exec(
      `curl "${url}" -o ${target}`,
      (error, stdout, stderr) => {
        if (error) {
          if (stderr) {
            process.stderr.write(stderr);
            prorcess.stderr.write(stdout);
          }
          rej(error);
          return;
        }
        res();
      },
    );
  });
}

async function stat(path) {
  try {
    const stats = await fs_stat(path);
    return stats.isDirectory() || stats.isFile();
  } catch (e) {
    return false;
  }
}

function nameMedia(media) {
  const { tags, content_type } = media;
  const suffix = content_type.split("/")[1];
  if (tags.includes("enclosure")) {
    if (tags.includes("front")) {
      return `front-enclosure.${suffix}`;
    }
    if (tags.includes("back")) {
      return `back-enclosure.${suffix}`;
    }
  }
  if (tags.includes("scan")) {
    return `scan.${suffix}`;
  }

  throw Error(`unsupported tags: '${JSON.stringify(tags)}'`);
}
