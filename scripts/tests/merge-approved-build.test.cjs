const {test} = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
// Use the frontend's locked YAML parser to execute the actual workflow script in mocks.
const YAML = require('../../windows/frontend/node_modules/yaml');
const workflow = YAML.parse(fs.readFileSync('.github/workflows/merge-approved-build.yml', 'utf8'));
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
const run = new AsyncFunction('github', 'context', 'core', workflow.jobs.merge.steps[0].with.script);
function fixture() {
    const sha = 'a'.repeat(40), head = 'b'.repeat(40);
    const state = {
        pr: {head: {sha: head, ref: `build/${sha}`}, state: 'open', draft: false, user: {login: 'github-actions[bot]'}, node_id: 'PR_1'},
        commit: {parents: [{sha}]},
        files: ['pkg', 'exe'].map(ext => ({filename: `installer/azooKey-wooden-structure-${sha}.${ext}`, status: 'added'})).concat({filename: `installer/${sha}.json`, status: 'added'}),
        reviews: [{user: {login: 'yuyudaodevlab'}, state: 'APPROVED', commit_id: head}],
        calls: [],
    };
    const github = {
        rest: {pulls: {get: async () => ({data: state.pr}), listFiles: 'files', listReviews: 'reviews'}, repos: {getCommit: async () => ({data: state.commit})}},
        paginate: async key => state[key],
        graphql: async (query, variables) => state.calls.push({query, variables}),
    };
    const context = {repo: {owner: 'owner', repo: 'repo'}, payload: {pull_request: {number: 1}, review: {commit_id: head}}};
    return {state, github, context, core: {notice() {}}};
}
test('only enables auto-merge with the exact approved head', async () => {
    const f = fixture(); await run(f.github, f.context, f.core);
    assert.equal(f.state.calls.length, 1);
    assert.equal(f.state.calls[0].variables.sha, f.state.pr.head.sha);
    assert.match(f.state.calls[0].query, /expectedHeadOid/);
});
test('merges an already-ready PR with the exact head instead of enabling auto-merge', async () => {
    const f = fixture();
    f.state.pr.mergeable = true;
    f.state.pr.mergeable_state = 'clean';
    f.github.rest.pulls.merge = async options => {
        assert.equal(options.sha, f.state.pr.head.sha);
        assert.equal(options.merge_method, 'squash');
        f.state.calls.push(options);
        return {data: {merged: true}};
    };
    await run(f.github, f.context, f.core);
    assert.equal(f.state.calls.length, 1);
});
for (const [name, change] of [
    ['old approval', f => f.context.payload.review.commit_id = 'old'],
    ['different reviewer', f => f.state.reviews[0].user.login = 'someone-else'],
    ['dismissed approval', f => f.state.reviews[0].state = 'DISMISSED'],
    ['changes requested after approval', f => f.state.reviews.push({user: {login: 'yuyudaodevlab'}, state: 'CHANGES_REQUESTED', commit_id: f.state.pr.head.sha})],
    ['source modification', f => f.state.files[0].filename = 'scripts/build-windows.ps1'],
    ['non-bot PR', f => f.state.pr.user.login = 'someone-else'],
    ['extra commit', f => f.state.commit.parents[0].sha = 'old'],
    ['missing installer', f => f.state.files.pop()],
]) test(`refuses ${name}`, async () => {
    const f = fixture(); change(f);
    await assert.rejects(run(f.github, f.context, f.core));
    assert.equal(f.state.calls.length, 0);
});
