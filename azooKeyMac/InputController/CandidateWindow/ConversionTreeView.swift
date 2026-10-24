import AppKit
import Core
import KanaKanjiConverterModule
import SwiftUI

private struct ConversionTreeToken: Identifiable {
    var id: String { "\(candidateIndex ?? -1)-\(readingStart)-\(readingEnd)-\(text)" }
    let candidateIndex: Int?
    let readingStart: Int
    let readingEnd: Int
    let text: String
    let percentage: String
    let partOfSpeech: String?
    let isZenzaiCorrection: Bool
}

private struct ConversionTreeColumn: Identifiable {
    var id: Int { readingStart }
    let readingStart: Int
    let selected: ConversionTreeToken
    let alternatives: [ConversionTreeToken]
}

private struct ConversionTreePiece {
    let span: CandidateTreeReadingSpan
    let text: String
    let elementIndex: Int?
    let alignmentAvailable: Bool
    let score: Double?
}

struct ConversionTreeView: View {
    let presentations: [CandidatePresentation]
    let treePresentations: [CandidatePresentation]?
    let selectedIndex: Int
    let numberedCandidateRange: ClosedRange<Int>?
    let showLinguisticAnalysis: Bool
    let onSelect: (Int) -> Void

    private var sourcePresentations: [CandidatePresentation] {
        self.treePresentations ?? self.presentations
    }

    private var columns: [ConversionTreeColumn] {
        let sources = self.sourcePresentations
        guard !sources.isEmpty else { return [] }
        let activeIndex = self.presentations.indices.contains(self.selectedIndex) ? self.selectedIndex : 0
        let sourceCandidates = sources.map(\.candidate)
        let piecesByCandidate = sourceCandidates.map(Self.pieces(for:))
        let linguisticLabels = self.showLinguisticAnalysis ? sourceCandidates.map(Self.linguisticLabels(for:)) : []
        let activeCandidate = self.presentations.indices.contains(activeIndex) ? self.presentations[activeIndex].candidate : nil
        let selectedSourceIndex: Int
        if self.treePresentations == nil, let activeCandidate,
           let mappedIndex = sources.firstIndex(where: {
               $0.candidate.text == activeCandidate.text && $0.candidate.composingCount == activeCandidate.composingCount
           }) {
            selectedSourceIndex = mappedIndex
        } else {
            selectedSourceIndex = 0
        }
        let selectedPieces = piecesByCandidate[selectedSourceIndex]

        return selectedPieces.indices.map { pieceIndex in
            let selectedPiece = selectedPieces[pieceIndex]
            let span = selectedPiece.span
            var scoreByText: [String: Double] = [:]
            var candidateByText: [String: Int] = [:]
            for candidateIndex in sourceCandidates.indices {
                guard selectedPiece.alignmentAvailable,
                      let alignedIndex = piecesByCandidate[candidateIndex].firstIndex(where: { $0.span == span }) else { continue }
                let piece = piecesByCandidate[candidateIndex][alignedIndex]
                guard piece.alignmentAvailable, let score = piece.score else { continue }
                scoreByText[piece.text] = max(scoreByText[piece.text] ?? -.infinity, score)
                candidateByText[piece.text] = candidateByText[piece.text] ?? candidateIndex
            }
            let orderedTexts = scoreByText.keys.sorted { left, right in
                let leftSelected = left == selectedPiece.text
                let rightSelected = right == selectedPiece.text
                if leftSelected != rightSelected { return leftSelected }
                if scoreByText[left] != scoreByText[right] {
                    return (scoreByText[left] ?? -.infinity) > (scoreByText[right] ?? -.infinity)
                }
                return left < right
            }
            let labels = CandidateTreeAnalysis.estimatedPercentageLabels(
                scores: orderedTexts.map { scoreByText[$0] }
            )
            let labelByText = Dictionary(uniqueKeysWithValues: zip(orderedTexts, labels))
            let sourceIndex = candidateByText[selectedPiece.text] ?? selectedSourceIndex
            let selectedElementIndex = selectedPiece.elementIndex
            let selected = ConversionTreeToken(
                candidateIndex: Self.selectableIndex(
                    in: self.presentations,
                    candidate: sourceCandidates[sourceIndex]
                ),
                readingStart: span.start,
                readingEnd: span.end,
                text: selectedPiece.text,
                percentage: labelByText[selectedPiece.text] ?? "—",
                partOfSpeech: linguisticLabels.isEmpty ? nil : linguisticLabels[selectedSourceIndex][pieceIndex],
                isZenzaiCorrection: selectedElementIndex.map(sources[selectedSourceIndex].displayContext.zenzaiAdjustedElementIndices.contains) ?? false
            )
            let alternatives = orderedTexts
                .filter { $0 != selectedPiece.text }
                .prefix(2)
                .compactMap { text -> ConversionTreeToken? in
                    guard let candidateIndex = candidateByText[text] else { return nil }
                    let elementIndex = piecesByCandidate[candidateIndex].firstIndex(where: { $0.span == span })
                    return ConversionTreeToken(
                        candidateIndex: Self.selectableIndex(in: self.presentations, candidate: sourceCandidates[candidateIndex]),
                        readingStart: span.start,
                        readingEnd: span.end,
                        text: text,
                        percentage: labelByText[text] ?? "—",
                        partOfSpeech: linguisticLabels.isEmpty || elementIndex == nil ? nil : linguisticLabels[candidateIndex][elementIndex!],
                        isZenzaiCorrection: elementIndex.map(sources[candidateIndex].displayContext.zenzaiAdjustedElementIndices.contains) ?? false
                    )
                }
            return ConversionTreeColumn(readingStart: span.start, selected: selected, alternatives: alternatives)
        }
    }

    var body: some View {
        let columns = self.columns
        VStack(alignment: .leading, spacing: 0) {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns.indices, id: \.self) { index in
                    if index > 0 {
                        Rectangle()
                            .fill(Color.secondary.opacity(0.45))
                            .frame(width: 14, height: 1)
                            .padding(.top, 12)
                    }
                    ConversionTreeColumnView(
                        column: columns[index],
                        showLinguisticAnalysis: self.showLinguisticAnalysis,
                        onSelect: self.onSelect
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        HStack(spacing: 8) {
            Text("語ごとの推定比率")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .help("同じ読み範囲の候補を辞書スコアで比較した値です。正解率やZenzaiの確率ではありません。候補が1つなら100%になります。")
            Spacer(minLength: 0)
            Menu("候補…") {
                ForEach(self.presentations.indices, id: \.self) { index in
                    let number = self.numberedCandidateRange.flatMap { range in
                        range.contains(index) ? "\(index - range.lowerBound + 1). " : nil
                    } ?? ""
                    Button(number + self.presentations[index].candidate.text) { self.onSelect(index) }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(.system(size: 10))
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 5)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("変換候補ツリー。語ごとの推定比率は辞書スコアに基づき、文全体の確率ではありません")
    }

    static func preferredSize(
        presentations: [CandidatePresentation],
        selectedIndex: Int,
        alternativeCount: Int,
        showLinguisticAnalysis: Bool
    ) -> CGSize {
        guard presentations.indices.contains(selectedIndex) else {
            return CGSize(width: 340, height: 96)
        }
        let candidate = presentations[selectedIndex].candidate
        let font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let pathWidth = candidate.data.reduce(CGFloat(0)) { partial, element in
            partial + min(140, max(36, (element.word as NSString).size(withAttributes: [.font: font]).width + 16)) + 15
        }
        let maxAlternatives = min(2, max(0, alternativeCount))
        let rowHeight: CGFloat = showLinguisticAnalysis ? 55 : 42
        return CGSize(width: min(960, max(220, pathWidth + 24)), height: CGFloat(maxAlternatives + 1) * rowHeight + 35)
    }

    private static func selectableIndex(in presentations: [CandidatePresentation], candidate: Candidate) -> Int? {
        presentations.firstIndex {
            $0.candidate.text == candidate.text && $0.candidate.composingCount == candidate.composingCount
        }
    }

    private static func pieces(for candidate: Candidate) -> [ConversionTreePiece] {
        let surface = candidate.data.map(\.word).joined()
        guard !candidate.data.isEmpty, surface == candidate.text else {
            let readingLength = candidate.data.reduce(0) { $0 + $1.ruby.count }
            return [ConversionTreePiece(
                span: CandidateTreeReadingSpan(start: 0, end: readingLength),
                text: candidate.text,
                elementIndex: nil,
                alignmentAvailable: false,
                score: nil
            )]
        }
        let spans = CandidateTreeAnalysis.readingSpans(for: candidate)
        return candidate.data.indices.map { index in
            ConversionTreePiece(
                span: spans[index],
                text: candidate.data[index].word,
                elementIndex: index,
                alignmentAvailable: true,
                score: Double(candidate.data[index].value())
            )
        }
    }

    private static func linguisticLabels(for candidate: Candidate) -> [String?] {
        guard !candidate.data.isEmpty, candidate.data.map(\.word).joined() == candidate.text else {
            return [nil]
        }
        let baseLabels = candidate.data.map { CandidateTreeAnalysis.partOfSpeechLabel(leftID: $0.lcid, rightID: $0.rcid) }
        return candidate.data.indices.map { index in
            var label = baseLabels[index]
            if label == "名詞", candidate.data.indices.contains(index + 1),
               ["は", "が"].contains(candidate.data[index + 1].word), baseLabels[index + 1] == "助詞" {
                label += " · 主語候補"
            }
            let isLastWord = index == baseLabels.lastIndex(where: { $0 != "記号" })
            if isLastWord, ["動詞", "形容詞", "助動詞"].contains(baseLabels[index]) {
                label += " · 述語候補"
            }
            return label
        }
    }
}

private struct ConversionTreeColumnView: View {
    let column: ConversionTreeColumn
    let showLinguisticAnalysis: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        let rowHeight: CGFloat = self.showLinguisticAnalysis ? 55 : 42
        VStack(alignment: .leading, spacing: 0) {
            ConversionTreeTokenView(token: self.column.selected, selected: true, showLinguisticAnalysis: self.showLinguisticAnalysis)
                .frame(height: rowHeight, alignment: .top)
            if !self.column.alternatives.isEmpty {
                HStack(alignment: .top, spacing: 3) {
                    ConversionTreeBranch(count: self.column.alternatives.count)
                        .stroke(Color.secondary.opacity(0.48), lineWidth: 1)
                        .frame(width: 8, height: CGFloat(self.column.alternatives.count) * rowHeight)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(self.column.alternatives) { token in
                            Group {
                                if let candidateIndex = token.candidateIndex {
                                    Button { self.onSelect(candidateIndex) } label: {
                                        ConversionTreeTokenView(token: token, selected: false, showLinguisticAnalysis: self.showLinguisticAnalysis)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    ConversionTreeTokenView(token: token, selected: false, showLinguisticAnalysis: self.showLinguisticAnalysis)
                                }
                            }
                            .frame(height: rowHeight, alignment: .top)
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct ConversionTreeTokenView: View {
    let token: ConversionTreeToken
    let selected: Bool
    let showLinguisticAnalysis: Bool

    private var tileColor: Color {
        if self.token.isZenzaiCorrection { return .purple }
        if self.token.percentage == "—" { return .gray }
        let value = Int(self.token.percentage.replacingOccurrences(of: "%", with: "")) ?? 0
        switch CandidateTreeScoreBand(percentage: value) {
        case .high: return .blue
        case .medium: return .orange
        case .low: return .red
        }
    }

    var body: some View {
        VStack(spacing: 1) {
            Text(self.token.text)
                .font(.system(size: self.selected ? 15 : 13, weight: self.selected ? .semibold : .regular))
                .foregroundStyle(self.selected ? Color.white : (self.token.isZenzaiCorrection ? Color.purple : Color.primary))
                .fixedSize(horizontal: true, vertical: false)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .frame(maxWidth: .infinity)
                .background(self.selected ? self.tileColor : self.tileColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            Text(self.token.percentage)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Color.secondary)
            if self.showLinguisticAnalysis, let label = self.token.partOfSpeech {
                Text(label)
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondary)
            }
        }
        .overlay(alignment: .topTrailing) {
            if self.token.isZenzaiCorrection {
                Text("Z").font(.system(size: 7, weight: .bold)).foregroundStyle(.white)
                    .padding(2).background(Color.purple, in: Circle()).offset(x: 3, y: -4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(self.token.text)、語ごとの推定比率 \(self.token.percentage)")
    }
}

private struct ConversionTreeBranch: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else { return path }
        for index in 0..<count {
            let y = CGFloat(index) * rect.height / CGFloat(count) + 11
            path.move(to: CGPoint(x: rect.minX, y: -16))
            path.addCurve(to: CGPoint(x: rect.maxX, y: y),
                          control1: CGPoint(x: rect.minX, y: y),
                          control2: CGPoint(x: rect.midX, y: y))
        }
        return path
    }
}
