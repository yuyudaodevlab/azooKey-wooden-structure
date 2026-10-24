@testable import Core
import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary
import Testing

@MainActor
@Test func composingTreeUsesWholeInputWithoutSelectingPrefix() throws {
    let previousLive = Config.LiveConversion().value
    let previousAnalysis = Config.CandidateLinguisticAnalysis().value
    Config.LiveConversion().value = true
    Config.CandidateLinguisticAnalysis().value = false
    defer {
        Config.LiveConversion().value = previousLive
        Config.CandidateLinguisticAnalysis().value = previousAnalysis
    }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let manager = SegmentsManager(kanaKanjiConverter: .withDefaultDictionary(), applicationDirectoryURL: directory,
                                  containerURL: nil, context: .init(useZenzai: false))
    var input = ""
    for piece in ["きょうは", "こうこうせいに", "いんたびゅーを", "おこなった"] {
        input += piece
        manager.insertAtCursorPosition(piece, inputStyle: .direct)
        let selectionBefore = manager.selectedCandidate?.text
        guard case let .composing(_, _, treeCandidates) = manager.getCurrentCandidateWindow(inputState: .composing) else {
            Issue.record("Live conversion must show its tree even with linguistic analysis disabled")
            return
        }
        let first = try #require(treeCandidates.first)
        #expect(first.data.map(\.ruby).joined().count == input.count)
        #expect(first.text == manager.getCurrentMarkedText(inputState: .composing).map(\.content).joined())
        #expect(manager.selectedCandidate?.text == selectionBefore)
    }
}

@Test func localScoreLabelsDoNotRoundSmallCandidatesToZero() {
    #expect(CandidateTreeAnalysis.estimatedPercentageLabels(scores: [-7.4969, -12.29, -12.3507]) == ["98%", "<1%", "<1%"])
    #expect(CandidateTreeAnalysis.estimatedPercentageLabels(scores: [nil, .nan, -.infinity]) == ["—", "—", "—"])
    #expect(CandidateTreeAnalysis.estimatedPercentageLabels(scores: [-50, -50]) == ["50%", "50%"])
}
