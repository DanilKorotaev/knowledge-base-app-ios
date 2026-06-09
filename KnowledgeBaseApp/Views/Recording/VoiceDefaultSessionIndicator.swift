import SwiftUI

struct VoiceDefaultSessionIndicator: View {
    let label: String?

    var body: some View {
        if let label {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)
        }
    }
}
