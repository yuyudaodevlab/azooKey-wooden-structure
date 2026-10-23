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
    #expect(CandidateTreeScoreBand(percentage: 90) == .high)
    #expect(CandidateTreeScoreBand(percentage: 30) == .medium)
    #expect(CandidateTreeScoreBand(percentage: 29) == .low)
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
