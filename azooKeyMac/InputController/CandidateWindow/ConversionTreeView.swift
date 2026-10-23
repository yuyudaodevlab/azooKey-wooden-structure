import Core
import KanaKanjiConverterModule
import SwiftUI

private struct ConversionTreeToken: Identifiable {
    var id: String { "\(candidateIndex)-\(readingStart)-\(readingEnd)-\(text)" }
    let candidateIndex: Int
    let readingStart: Int
    let readingEnd: Int
    let text: String
    let percentage: Int
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
}

struct ConversionTreeView: View {
    let presentations: [CandidatePresentation]
    let selectedIndex: Int
    let numberedCandidateRange: ClosedRange<Int>
    let showLinguisticAnalysis: Bool
    let onSelect: (Int) -> Void

    private var candidatePercentages: [Int] {
        CandidateTreeAnalysis.estimatedPercentages(scores: self.presentations.map { Double($0.candidate.value) })
    }

    private var columns: [ConversionTreeColumn] {
        guard !self.presentations.isEmpty else {
            return []
        }
        let selectedIndex = self.presentations.indices.contains(self.selectedIndex) ? self.selectedIndex : 0
        let candidates = self.presentations.map(\.candidate)
        let candidatePercentages = self.candidatePercentages
        let piecesByCandidate = candidates.map(Self.pieces(for:))
        let linguisticLabels = self.showLinguisticAnalysis ? candidates.map(Self.linguisticLabels(for:)) : []
        let selectedCandidate = candidates[selectedIndex]
        let selectedPieces = piecesByCandidate[selectedIndex]

        return selectedPieces.indices.map { pieceIndex in
            let selectedPiece = selectedPieces[pieceIndex]
            let span = selectedPiece.span
            var grouped: [String: (token: ConversionTreeToken, weight: Int)] = [:]
            for candidateIndex in candidates.indices {
                guard selectedPiece.alignmentAvailable else { continue }
                guard let alignedIndex = piecesByCandidate[candidateIndex].firstIndex(where: { $0.span == span }) else {
                    continue
                }
                let piece = piecesByCandidate[candidateIndex][alignedIndex]
                guard piece.alignmentAvailable else { continue }
                let key = "\(span.start):\(span.end):\(piece.text)"
                if var value = grouped[key] {
                    value.weight += candidatePercentages[candidateIndex]
                    grouped[key] = value
                } else {
                    grouped[key] = (
                        token: ConversionTreeToken(
                            candidateIndex: candidateIndex,
                            readingStart: span.start,
                            readingEnd: span.end,
                            text: piece.text,
                            percentage: candidatePercentages[candidateIndex],
                            partOfSpeech: linguisticLabels.isEmpty ? nil : linguisticLabels[candidateIndex][alignedIndex],
                            isZenzaiCorrection: piece.elementIndex.map(presentations[candidateIndex].displayContext.zenzaiAdjustedElementIndices.contains) ?? !presentations[candidateIndex].displayContext.zenzaiAdjustedElementIndices.isEmpty
                        ),
                        weight: candidatePercentages[candidateIndex]
                    )
                }
            }

            let orderedGroups = grouped.values.sorted { left, right in
                let leftIsSelected = left.token.text == selectedPiece.text
                let rightIsSelected = right.token.text == selectedPiece.text
                if leftIsSelected != rightIsSelected {
                    return true
                }
                if left.weight != right.weight {
                    return left.weight > right.weight
                }
                return left.token.candidateIndex < right.token.candidateIndex
            }
            let selectedGroup = orderedGroups.first { $0.token.text == selectedPiece.text }
            let selectedToken = ConversionTreeToken(
                candidateIndex: selectedIndex,
                readingStart: span.start,
                readingEnd: span.end,
                text: selectedPiece.text,
                percentage: selectedGroup?.weight ?? candidatePercentages[selectedIndex],
                partOfSpeech: linguisticLabels.isEmpty ? nil : linguisticLabels[selectedIndex][pieceIndex],
                isZenzaiCorrection: selectedPiece.elementIndex.map(presentations[selectedIndex].displayContext.zenzaiAdjustedElementIndices.contains) ?? !presentations[selectedIndex].displayContext.zenzaiAdjustedElementIndices.isEmpty
            )
            let alternatives = orderedGroups
                .filter { $0.token.text != selectedToken.text }
                .map { group in
                    ConversionTreeToken(
                        candidateIndex: group.token.candidateIndex,
                        readingStart: span.start,
                        readingEnd: span.end,
                        text: group.token.text,
                        percentage: group.weight,
                        partOfSpeech: group.token.partOfSpeech,
                        isZenzaiCorrection: group.token.isZenzaiCorrection
                    )
                }
            return ConversionTreeColumn(readingStart: span.start, selected: selectedToken, alternatives: alternatives)
        }
    }

    var body: some View {
        ScrollViewReader { proxy in
          let columns = self.columns
          let candidatePercentages = self.candidatePercentages
          let hasZenzaiCorrection = columns.contains { $0.selected.isZenzaiCorrection }
          ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("変換候補のつながり")
                        .font(.system(size: 13, weight: .semibold))
                    Text("スコア比の推定値 · 表示中の候補内")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 4) {
                  HStack(spacing: 8) {
                    ScoreLegend(color: .blue, label: "90%以上")
                    ScoreLegend(color: .orange, label: "30–89%")
                    ScoreLegend(color: .red, label: "30%未満")
                  }
                  if hasZenzaiCorrection {
                      Label("Zenzaiによる変更", systemImage: "sparkles")
                          .font(.system(size: 10, weight: .medium))
                          .foregroundStyle(Color.purple)
                  }
                }
            }
            HStack(alignment: .top, spacing: 0) {
                ForEach(columns.indices, id: \.self) { index in
                    if index > 0 {
                        ConversionTreePathConnector()
                            .stroke(Color.secondary.opacity(0.36), lineWidth: 1.2)
                            .frame(width: 16, height: 68)
                    }
                    ConversionTreeColumnView(
                        column: columns[index],
                        showLinguisticAnalysis: self.showLinguisticAnalysis,
                        onSelect: self.onSelect
                    )
                }
            }
            .padding(.vertical, 4)
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("候補一覧")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                ScrollViewReader { candidateProxy in
                  ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 2) {
                      ForEach(self.presentations.indices, id: \.self) { row in
                    Button {
                        self.onSelect(row)
                    } label: {
                        HStack(spacing: 8) {
                            Text(self.numberedCandidateRange.contains(row) ? "\(row - self.numberedCandidateRange.lowerBound + 1)." : "\(row + 1).")
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 24, alignment: .trailing)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(self.presentations[row].candidate.text)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                if let annotation = self.presentations[row].displayContext.annotationText {
                                    Text(annotation)
                                        .font(.system(size: 10))
                                        .foregroundStyle(self.selectedIndex == row ? Color.white.opacity(0.82) : Color.secondary)
                                        .lineLimit(1)
                                }
                            }
                            Spacer(minLength: 8)
                            Text("\(candidatePercentages[row])%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(self.selectedIndex == row ? Color.white : Self.color(for: candidatePercentages[row]))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(self.selectedIndex == row ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 5))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("候補 \(row + 1): \(self.presentations[row].candidate.text)")
                    .id("candidate-row-\(row)")
                      }
                    }
                  }
                  .frame(maxHeight: 200)
                  .onAppear {
                      candidateProxy.scrollTo("candidate-row-\(self.selectedIndex)", anchor: .center)
                  }
                  .onChange(of: self.selectedIndex) { newValue in
                      candidateProxy.scrollTo("candidate-row-\(newValue)", anchor: .center)
                  }
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            }
            .padding(12)
            .id("conversion-tree-top")
            .background(.regularMaterial)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("変換候補ツリー")
          }
          .onAppear { proxy.scrollTo("conversion-tree-top", anchor: .top) }
          .onChange(of: self.selectedIndex) { _ in proxy.scrollTo("conversion-tree-top", anchor: .top) }
        }
    }

    static func preferredSize(tokenCount: Int, alternativeCount: Int, candidateCount: Int) -> CGSize {
        CGSize(
            width: max(560, CGFloat(tokenCount) * 138 + 40),
            height: max(220, CGFloat(alternativeCount) * 42 + CGFloat(candidateCount) * 32 + 200)
        )
    }

    private static func color(for percentage: Int) -> Color {
        switch CandidateTreeScoreBand(percentage: percentage) {
        case .high: .blue
        case .medium: .orange
        case .low: .red
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
                alignmentAvailable: false
            )]
        }

        let spans = CandidateTreeAnalysis.readingSpans(for: candidate)
        return candidate.data.indices.map { index in
            ConversionTreePiece(span: spans[index], text: candidate.data[index].word, elementIndex: index, alignmentAvailable: true)
        }
    }

    private static func linguisticLabels(for candidate: Candidate) -> [String?] {
        let pieces = Self.pieces(for: candidate)
        guard pieces.allSatisfy({ $0.elementIndex != nil }) else {
            return pieces.map { _ in "語" }
        }

        let baseLabels = candidate.data.map { element in
            CandidateTreeAnalysis.partOfSpeechLabel(leftID: element.lcid, rightID: element.rcid)
        }
        return candidate.data.indices.map { index in
            var label = baseLabels[index]
            if label == "名詞", candidate.data.indices.contains(index + 1),
               ["は", "が"].contains(candidate.data[index + 1].word),
               baseLabels[index + 1] == "助詞" {
                label += " · 主語候補"
            }
            let isLastWord = index == candidate.data.count - 1
            if isLastWord, ["動詞", "形容詞", "助動詞"].contains(baseLabels[index]) {
                label += " · 述語候補"
            }
            return label
        }
    }

}

private struct ScoreLegend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 3) {
            Circle().fill(self.color).frame(width: 6, height: 6)
            Text(self.label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }
}

private struct ConversionTreeColumnView: View {
    let column: ConversionTreeColumn
    let showLinguisticAnalysis: Bool
    let onSelect: (Int) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ConversionTreeTokenView(token: self.column.selected, selected: true, showLinguisticAnalysis: self.showLinguisticAnalysis)
                .frame(minHeight: 68)
            if !self.column.alternatives.isEmpty {
                VStack(spacing: 7) {
                    ForEach(self.column.alternatives) { token in
                        Button {
                            self.onSelect(token.candidateIndex)
                        } label: {
                            ConversionTreeTokenView(token: token, selected: false, showLinguisticAnalysis: self.showLinguisticAnalysis)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(token.text)、推定スコア比 \(token.percentage)%")
                    }
                }
                .background {
                    ConversionTreeBranches(count: self.column.alternatives.count)
                        .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                        .padding(.top, -8)
                }
            }
        }
        .frame(width: 124, alignment: .top)
    }
}

private struct ConversionTreeTokenView: View {
    let token: ConversionTreeToken
    let selected: Bool
    let showLinguisticAnalysis: Bool

    private var scoreColor: Color {
        switch CandidateTreeScoreBand(percentage: self.token.percentage) {
        case .high:
            return .blue
        case .medium:
            return .orange
        case .low:
            return .red
        }
    }

    private var primaryColor: Color {
        self.selected ? .white : (self.token.isZenzaiCorrection ? .purple : self.scoreColor)
    }

    private var tileColor: Color {
        self.token.isZenzaiCorrection ? .purple : self.scoreColor
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(self.token.text)
                .font(.system(size: self.selected ? 17 : 14, weight: self.selected ? .semibold : .regular))
                .foregroundStyle(self.primaryColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Text("\(self.token.percentage)%")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(self.primaryColor)
            if self.showLinguisticAnalysis, let partOfSpeech = self.token.partOfSpeech {
                Text(partOfSpeech)
                    .font(.system(size: 9))
                    .foregroundStyle(self.selected ? Color.white.opacity(0.84) : Color.secondary)
            }
            if self.token.isZenzaiCorrection {
                Text("Zenzai")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(self.selected ? Color.white.opacity(0.86) : Color.purple)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(minHeight: 56)
        .background(
            self.selected ? self.tileColor : self.tileColor.opacity(0.12),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(self.tileColor.opacity(self.selected ? 1 : 0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ConversionTreePathConnector: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY + 6))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY - 6),
            control1: CGPoint(x: rect.width * 0.35, y: rect.minY),
            control2: CGPoint(x: rect.width * 0.65, y: rect.maxY)
        )
        return path
    }
}

private struct ConversionTreeBranches: Shape {
    let count: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard count > 0 else {
            return path
        }
        let center = rect.midX
        let targetSpacing = rect.height / CGFloat(count)
        for index in 0..<count {
            let targetY = targetSpacing * (CGFloat(index) + 0.5)
            path.move(to: CGPoint(x: center, y: 0))
            path.addCurve(
                to: CGPoint(x: center, y: targetY),
                control1: CGPoint(x: center - 12, y: targetY * 0.4),
                control2: CGPoint(x: center + 12, y: targetY * 0.6)
            )
        }
        return path
    }
}
