import Core
import Testing

@Test func candidateTreeEstimatedPercentagesSumToOneHundred() {
    let percentages = CandidateTreeAnalysis.estimatedPercentages(scores: [0, -1, -2])

    #expect(percentages.reduce(0, +) == 100)
    #expect(percentages[0] > percentages[1])
    #expect(percentages[1] > percentages[2])
}

@Test func candidateTreeEstimatedPercentagesHandleEqualScoresDeterministically() {
    #expect(CandidateTreeAnalysis.estimatedPercentages(scores: [4, 4, 4]) == [34, 33, 33])
}

@Test func candidateTreeEstimatedPercentagesIgnoreNonFiniteScores() {
    let percentages = CandidateTreeAnalysis.estimatedPercentages(scores: [0, .nan, -.infinity])

    #expect(percentages == [100, 0, 0])
}

@Test func candidateTreeScoreBandsUseRequestedBoundaries() {
    #expect(CandidateTreeScoreBand(percentage: 89) == .medium)
    #expect(CandidateTreeScoreBand(percentage: 90) == .high)
    #expect(CandidateTreeScoreBand(percentage: 30) == .medium)
    #expect(CandidateTreeScoreBand(percentage: 29) == .low)
}

@Test func candidateTreePartsOfSpeechUseDictionaryIDs() {
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: 1285, rightID: 1285) == "名詞")
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: 561, rightID: 561) == "動詞")
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: 11, rightID: 11) == "形容詞")
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: 261, rightID: 261) == "助詞")
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: 460, rightID: 460) == "助動詞")
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: -1, rightID: 1285) == "名詞")
    #expect(CandidateTreeAnalysis.partOfSpeechLabel(leftID: 9999, rightID: -1) == "語")
}

@Test func candidateTreeScoresHandleEmptyAndExtremeInputs() {
    #expect(CandidateTreeAnalysis.estimatedPercentages(scores: []).isEmpty)
    #expect(CandidateTreeAnalysis.estimatedPercentages(scores: [.nan, -.infinity]) == [0, 0])
    #expect(CandidateTreeAnalysis.estimatedPercentages(scores: [10000, -10000]) == [100, 0])
}

@Test func candidateTreeEstimatesNormalizeComparableWordsAndIgnoreUnavailableFallbacks() {
    #expect(CandidateTreeAnalysis.estimatedPercentageLabels(scores: [-7.0, -8.0, nil]) == ["73%", "27%", "—"])
    #expect(CandidateTreeAnalysis.estimatedPercentageLabels(scores: [-50.0, -60.0]) == ["100%", "<1%"])
    #expect(CandidateTreeAnalysis.estimatedPercentageLabels(scores: [nil, .nan]) == ["—", "—"])
}

@Test func zenzaiComparisonMarksOnlyChangedTokensWithMatchingReadingSpans() {
    let spans = [CandidateTreeReadingSpan(start: 0, end: 2), CandidateTreeReadingSpan(start: 2, end: 4)]
    let changed = CandidateTreeAnalysis.changedElementIndices(
        candidateSpans: spans,
        candidateWords: ["今日", "は"],
        standardSpans: spans,
        standardWords: ["きょう", "は"]
    )

    #expect(changed == [0])
}

@Test func zenzaiComparisonDoesNotAttributeDifferentSegmentation() {
    let candidateSpans = [CandidateTreeReadingSpan(start: 0, end: 2), CandidateTreeReadingSpan(start: 2, end: 4)]
    let standardSpans = [CandidateTreeReadingSpan(start: 0, end: 1), CandidateTreeReadingSpan(start: 1, end: 4)]
    let changed = CandidateTreeAnalysis.changedElementIndices(
        candidateSpans: candidateSpans,
        candidateWords: ["今日", "は"],
        standardSpans: standardSpans,
        standardWords: ["きょ", "うは"]
    )

    #expect(changed.isEmpty)
}
