module.exports = async ({github, context, core}) => {
  const reviewer = 'yuyudaodevlab';
  const head = `build/${context.sha}`;
  const manifest = require(`../installer/${context.sha}.json`);
  const body = [
    `ビルド元: \`${context.sha}\``,
    `ビルド結果: ${manifest.runUrl}`,
    '',
    'macOS / Windows のビルドが両方成功しました。開発用の未署名インストーラーです。',
    'installer/ のバイナリは通常の Git ファイルです。リポジトリまたは Actions の artifacts から取得してください。',
    '',
    ...manifest.files.map(f => `- \`${f.path}\` (${f.size} bytes)\n  SHA-256: \`${f.sha256}\``),
    '',
    `@${reviewer} レビューと承認をお願いします。最新コミットへの承認後に自動マージします。`,
  ].join('\n');
  const {data: existing} = await github.rest.pulls.list({
    ...context.repo, head: `${context.repo.owner}:${head}`, base: 'main', state: 'open',
  });
  const pr = existing[0] ?? (await github.rest.pulls.create({
    ...context.repo, head, base: 'main', title: `build: macOS / Windows ${context.sha}`, body,
  })).data;
  await github.rest.issues.addAssignees({...context.repo, issue_number: pr.number, assignees: [reviewer]});
  await github.rest.pulls.requestReviewers({...context.repo, pull_number: pr.number, reviewers: [reviewer]});
  const comments = await github.paginate(github.rest.issues.listComments, {...context.repo, issue_number: pr.number});
  if (!comments.some(c => c.user.login === 'github-actions[bot]' && c.body.includes('<!-- installer-build -->'))) {
    await github.rest.issues.createComment({...context.repo, issue_number: pr.number, body: `<!-- installer-build -->\n${body}`});
  }
  await core.summary.addLink(`Build PR #${pr.number}`, pr.html_url).write();
};
