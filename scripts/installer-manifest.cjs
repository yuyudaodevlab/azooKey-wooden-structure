const fs = require('node:fs');
const crypto = require('node:crypto');
const {createReadStream} = require('node:fs');

async function main() {
  const sha = process.argv[2];
  if (!/^[0-9a-f]{40}$/.test(sha)) throw new Error('Expected full source commit SHA');
  const files = [];
  for (const extension of ['pkg', 'exe']) {
    const path = `installer/azooKey-wooden-structure-${sha}.${extension}`;
    const size = fs.statSync(path).size;
    if (size < 1024) throw new Error(`Installer is unexpectedly small: ${path}`);
    if (size > 100 * 1024 * 1024) {
      throw new Error(`Installer exceeds GitHub's 100 MiB Git file limit: ${path} (${size} bytes). No PR will be created. Download the installer from this run's Actions artifacts; reduce its size or use GitHub Releases for distribution.`);
    }
    const hash = crypto.createHash('sha256');
    for await (const chunk of createReadStream(path)) hash.update(chunk);
    files.push({path, size, sha256: hash.digest('hex')});
  }
  fs.writeFileSync(`installer/${sha}.json`, JSON.stringify({
    sourceCommit: sha,
    runUrl: `${process.env.GITHUB_SERVER_URL}/${process.env.GITHUB_REPOSITORY}/actions/runs/${process.env.GITHUB_RUN_ID}`,
    signed: false,
    files,
  }, null, 2) + '\n');
}
main().catch(error => { console.error(error); process.exitCode = 1; });
