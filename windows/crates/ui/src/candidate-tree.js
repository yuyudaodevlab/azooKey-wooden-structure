/* The converter supplies reading spans. Never infer word boundaries from characters. */
function normalizeCandidate(value) {
    let item;
    try { item = typeof value === 'string' ? JSON.parse(value) : value; } catch { item = null; }
    if (!item || typeof item.text !== 'string') return {text: String(value), tokens: []};
    const tokens = Array.isArray(item.tokens) ? item.tokens : [];
    let end = 0;
    const valid = tokens.every(t => {
        const ok = typeof t.text === 'string' && Number.isInteger(t.start) && Number.isInteger(t.end)
            && t.start === end && t.end > t.start;
        end = t.end;
        return ok;
    });
    return {text: item.text, tokens: valid && tokens.map(t => t.text).join('') === item.text ? tokens : []};
}

function buildColumns(candidates, selectedIndex) {
    const selected = candidates[selectedIndex];
    if (!selected) return [];
    return selected.tokens.map(token => {
        const alternatives = new Map();
        candidates.forEach((candidate, index) => {
            const match = candidate.tokens.find(t => t.start === token.start && t.end === token.end);
            if (match && match.text !== token.text && !alternatives.has(match.text)) {
                alternatives.set(match.text, {text: match.text, index});
            }
        });
        return {text: token.text, alternatives: [...alternatives.values()].slice(0, 3)};
    });
}

if (typeof module !== 'undefined') module.exports = {normalizeCandidate, buildColumns};
if (typeof window !== 'undefined') {
    let candidates = [];
    let selection = 0;
    function render() {
        const tree = document.getElementById('tree');
        const list = document.getElementById('candidates');
        tree.replaceChildren();
        list.replaceChildren();
        for (const column of buildColumns(candidates, selection)) {
            const node = document.createElement('div');
            node.className = 'column';
            const active = document.createElement('strong');
            active.textContent = column.text;
            node.append(active);
            for (const alternative of column.alternatives) {
                const leaf = document.createElement('span');
                leaf.className = 'alternative';
                leaf.textContent = `↳ ${alternative.text}（候補${alternative.index + 1}）`;
                node.append(leaf);
            }
            tree.append(node);
        }
        candidates.forEach((candidate, index) => {
            const item = document.createElement('li');
            item.textContent = candidate.text;
            item.setAttribute('aria-selected', String(index === selection));
            list.append(item);
        });
        list.children[selection]?.scrollIntoView({block: 'nearest'});
        window.ipc?.postMessage(JSON.stringify({type: 'resize', height: 360}));
    }
    window.updateCandidates = values => {
        candidates = values.map(normalizeCandidate);
        selection = 0;
        render();
    };
    window.updateSelection = index => {
        selection = Number.isInteger(index) && index >= 0 && index < candidates.length ? index : 0;
        render();
    };
}
