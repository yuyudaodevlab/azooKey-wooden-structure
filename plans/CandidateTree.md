# Conversion candidate tree

The macOS candidate window presents each selected candidate as a horizontal token path. Other candidates branch under a token when they contain a token with the same reading span. Clicking a branch selects the original full candidate row, so keyboard navigation and candidate submission continue to use the converter's existing selection flow. When token data is absent or does not reconstruct the candidate text, the tree shows the full candidate and leaves it out of span alignment; the scrollable candidate list remains available for selection.

The percentage under each token is a softmax conversion of the converter's candidate evaluation scores across the candidates currently shown. It is a relative estimate for that set, not a calibrated probability. Blue means 90% or higher, orange means 30% through 89%, and red means below 30%.

When the bundled Zenzai model loads, the manager also requests a comparison result from a second converter with Zenzai turned off. It receives the same active dictionary entries, input, context, and completion updates. A token is purple only when the top Zenzai result differs from the standard result over the same reading span. Tokens with different segmentation are left unmarked because there is no exact span to compare. The comparison adds another conversion request while the tree is active.

The optional language information setting uses macOS Natural Language tagging for broad part-of-speech labels and the converter's connection IDs for particles, auxiliaries, prefixes, and suffix nouns. 主語候補 is a shallow hint for a noun immediately before は or が, and 述語候補 is a hint for a sentence-final verb, adjective, or auxiliary. These are local heuristics, not grammatical analysis or a dependency parse. Unclassified words are shown as 語.

The Zenzai comparison is available only when the bundled model file loads successfully. The repository checkout may not include model resources, so the purple comparison is unavailable in builds without that model. Score percentages remain relative estimates even when Zenzai is enabled; the converter does not expose calibrated probabilities or per-token Zenzai provenance.
