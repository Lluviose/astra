import SwiftUI

/// 快捷短语按完整分号片段切换，保留其余自由备注。
struct SuggestedNotesField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    let suggestions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold))
            FlowLayout(spacing: 7, lineSpacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    RecordChoice(title: suggestion, isOn: text.components(separatedBy: "；").contains(suggestion), tint: Palette.accent, compact: true) {
                        let current = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        var parts = current.isEmpty ? [] : current.components(separatedBy: "；")
                        if parts.contains(suggestion) {
                            parts.removeAll { $0 == suggestion }
                        } else {
                            parts.append(suggestion)
                        }
                        text = parts.joined(separator: "；")
                    }
                }
            }
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...5)
        }
        .padding(.vertical, 4)
    }
}
