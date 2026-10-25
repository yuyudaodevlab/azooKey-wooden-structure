const {test} = require('node:test');
const assert = require('node:assert/strict');
const {normalizeCandidate, buildColumns} = require('../../windows/crates/ui/src/candidate-tree.js');

test('uses matching reading spans, not shared text prefixes', () => {
    const candidates = [
        {text: '橋を', tokens: [{text: '橋', start: 0, end: 2}, {text: 'を', start: 2, end: 3}]},
        {text: '箸を', tokens: [{text: '箸', start: 0, end: 2}, {text: 'を', start: 2, end: 3}]},
        {text: '端を', tokens: [{text: '端', start: 0, end: 1}, {text: 'を', start: 1, end: 3}]},
    ].map(normalizeCandidate);
    assert.deepEqual(buildColumns(candidates, 0), [
        {text: '橋', alternatives: [{text: '箸', index: 1}]},
        {text: 'を', alternatives: []},
    ]);
});
test('does not invent segmentation for mismatched or malformed candidates', () => {
    assert.deepEqual(normalizeCandidate({text: '予測結果', tokens: [{text: '別', start: 0, end: 1}]}).tokens, []);
    assert.deepEqual(normalizeCandidate({text: 'あ', tokens: [{text: 'あ', start: 1, end: 2}]}).tokens, []);
    assert.deepEqual(normalizeCandidate('not JSON'), {text: 'not JSON', tokens: []});
    assert.deepEqual(buildColumns([], 0), []);
});
test('deduplicates alternatives and retains the candidate index', () => {
    const values = ['橋', '箸', '箸'].map(text => normalizeCandidate(JSON.stringify({text, tokens: [{text, start: 0, end: 2}]})));
    assert.deepEqual(buildColumns(values, 0)[0].alternatives, [{text: '箸', index: 1}]);
});
