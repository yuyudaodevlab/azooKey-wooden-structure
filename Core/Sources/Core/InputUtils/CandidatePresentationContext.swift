import KanaKanjiConverterModuleWithDefaultDictionary

public struct CandidatePresentationContext: Sendable {
    public var annotationText: String?
    public var extraValues: [String: String]
    public var zenzaiAdjustedElementIndices: Set<Int>

    public init(
        annotationText: String? = nil,
        extraValues: [String: String] = [:],
        zenzaiAdjustedElementIndices: Set<Int> = []
    ) {
        self.annotationText = annotationText
        self.extraValues = extraValues
        self.zenzaiAdjustedElementIndices = zenzaiAdjustedElementIndices
    }
}

public struct CandidatePresentation: Sendable {
    public var candidate: Candidate
    public var displayContext: CandidatePresentationContext

    public init(candidate: Candidate, displayContext: CandidatePresentationContext = .init()) {
        self.candidate = candidate
        self.displayContext = displayContext
    }
}
