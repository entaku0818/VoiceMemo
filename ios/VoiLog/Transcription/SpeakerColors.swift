import SwiftUI

/// Returns a deterministic Color for a given speaker label.
/// Shared across TranscriptionFeature and TranscriptionTabsView.
func speakerColor(_ speaker: String) -> Color {
    let palette: [Color] = [.blue, .orange, .green, .purple, .red, .teal, .indigo, .pink]
    let index = Int(speaker.unicodeScalars.first?.value ?? 65) % palette.count
    return palette[index]
}
