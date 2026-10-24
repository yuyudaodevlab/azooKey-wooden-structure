import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

public struct CandidateTreeReadingSpan: Sendable, Hashable {
    public var start: Int
    public var end: Int

    public init(start: Int, end: Int) {
        self.start = start
        self.end = end
    }
}

public enum CandidateTreeScoreBand: Sendable, Equatable {
    case high
    case medium
    case low

    public init(percentage: Int) {
        switch percentage {
        case 90...:
            self = .high
        case 30..<90:
            self = .medium
        default:
            self = .low
        }
    }
}

public enum CandidateTreeAnalysis {
    public static func partOfSpeechLabel(leftID: Int, rightID: Int) -> String {
        func label(for id: Int) -> String? {
            return switch id {
            case 1: "その他"
            case 2: "フィラー"
            case 3: "感動詞"
            case 4...10: "記号"
            case 11...146: "形容詞"
            case 147...368: "助詞"
            case 369...554: "助動詞"
            case 555...556: "接続詞"
            case 557...560: "接頭辞"
            case 561...1280: "動詞"
            case 1281...1282: "副詞"
            case 1283...1314: "名詞"
            case 1315: "連体詞"
            default: nil
            }
        }
        return label(for: leftID) ?? label(for: rightID) ?? "語"
    }

    public static func readingSpans(for candidate: Candidate) -> [CandidateTreeReadingSpan] {
        var offset = 0
        return candidate.data.map { element in
            let start = offset
            offset += element.ruby.count
            return CandidateTreeReadingSpan(start: start, end: offset)
        }
    }

    public static func zenzaiAdjustedElementIndices(candidate: Candidate, standardCandidate: Candidate) -> Set<Int> {
        guard !candidate.data.isEmpty,
              !standardCandidate.data.isEmpty,
              candidate.data.map(\.word).joined() == candidate.text,
              standardCandidate.data.map(\.word).joined() == standardCandidate.text else {
            return []
        }
        return Self.changedElementIndices(
            candidateSpans: Self.readingSpans(for: candidate),
            candidateWords: candidate.data.map(\.word),
            standardSpans: Self.readingSpans(for: standardCandidate),
            standardWords: standardCandidate.data.map(\.word)
        )
    }

    public static func changedElementIndices(
        candidateSpans: [CandidateTreeReadingSpan],
        candidateWords: [String],
        standardSpans: [CandidateTreeReadingSpan],
        standardWords: [String]
    ) -> Set<Int> {
        let standard = Dictionary(
            standardSpans.indices.compactMap { index -> (CandidateTreeReadingSpan, String)? in
                guard standardWords.indices.contains(index) else { return nil }
                return (standardSpans[index], standardWords[index])
            },
            uniquingKeysWith: { first, _ in first }
        )
        return Set(candidateSpans.indices.compactMap { index in
            guard candidateWords.indices.contains(index),
                  let standardWord = standard[candidateSpans[index]],
                  standardWord != candidateWords[index] else {
                return nil
            }
            return index
        })
    }

    /// Converts engine ranking scores into a relative estimate over the supplied candidates.
    /// These values are not calibrated probabilities and only describe the supplied set.
    public static func estimatedPercentages(scores: [Double]) -> [Int] {
        guard !scores.isEmpty else {
            return []
        }
        let finiteScores = scores.map { $0.isFinite ? $0 : -.infinity }
        guard let maxScore = finiteScores.max(), maxScore.isFinite else {
            return Array(repeating: 0, count: scores.count)
        }

        let weights = finiteScores.map { score in
            score.isFinite ? exp(score - maxScore) : 0
        }
        let total = weights.reduce(0, +)
        guard total.isFinite, total > 0 else {
            return Array(repeating: 0, count: scores.count)
        }

        let exactPercentages = weights.map { $0 / total * 100 }
        var percentages = exactPercentages.map { Int($0.rounded(.down)) }
        let remainder = 100 - percentages.reduce(0, +)
        let remainderOrder = exactPercentages.indices.sorted {
            let left = exactPercentages[$0].truncatingRemainder(dividingBy: 1)
            let right = exactPercentages[$1].truncatingRemainder(dividingBy: 1)
            return left == right ? $0 < $1 : left > right
        }
        for index in remainderOrder.prefix(max(0, remainder)) {
            percentages[index] += 1
        }
        return percentages
    }

    /// Formats relative estimates for comparable dictionary entries. A nil or non-finite
    /// score is unavailable; finite entries are normalized only against the supplied set.
    public static func estimatedPercentageLabels(scores: [Double?]) -> [String] {
        guard !scores.isEmpty else { return [] }
        let finiteScores = scores.compactMap { score in
            score.flatMap { $0.isFinite ? $0 : nil }
        }
        guard let maxScore = finiteScores.max() else {
            return Array(repeating: "—", count: scores.count)
        }
        let weights = scores.map { score -> Double in
            guard let score, score.isFinite else { return 0 }
            return exp(score - maxScore)
        }
        let total = weights.reduce(0, +)
        guard total.isFinite, total > 0 else {
            return Array(repeating: "—", count: scores.count)
        }
        return scores.indices.map { index in
            guard scores[index]?.isFinite == true else { return "—" }
            let percentage = weights[index] / total * 100
            guard percentage > 0 else { return "<1%" }
            guard percentage < 1 else { return "\(Int(percentage.rounded()))%" }
            return "<1%"
        }
    }
}
