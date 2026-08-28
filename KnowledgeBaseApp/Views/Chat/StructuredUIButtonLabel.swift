import SwiftUI

/// Multiline-friendly label for Structured UI buttons (avoids single-line truncation).
struct StructuredUIButtonLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.body)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}
