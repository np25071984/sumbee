import SwiftUI

/// Key height on a tall screen; `minKeyHeight` is FR-3.2's floor, used when height is short.
let maxKeyHeight: CGFloat = 76
let minKeyHeight: CGFloat = 64

/// The on-screen keypad (SPEC.md FR-3.2): 0–9, delete and check. The system keyboard never shows.
struct Keypad: View {
    let onDigit: (Int) -> Void
    let onDelete: () -> Void
    let onSubmit: () -> Void
    let submitEnabled: Bool
    var keyHeight: CGFloat = maxKeyHeight
    @Environment(\.uiScale) private var s

    var body: some View {
        VStack(spacing: 10 * s) {
            ForEach(0..<3) { row in
                HStack(spacing: 10 * s) {
                    ForEach(1...3, id: \.self) { col in digitKey(row * 3 + col) }
                }
            }
            HStack(spacing: 10 * s) {
                Button(action: onDelete) { IconView(icon: .backspace, size: 32) }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.soft, base: Palette.softShadow))
                    .frame(height: keyHeight)
                    .accessibilityLabel("Delete")
                    .accessibilityIdentifier("key.delete")
                digitKey(0)
                Button(action: onSubmit) { IconView(icon: .check, size: 34, color: Palette.white) }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.ink, base: Palette.inkShadow))
                    .frame(height: keyHeight)
                    .disabled(!submitEnabled)
                    .accessibilityLabel("Check answer")
                    .accessibilityIdentifier("key.submit")
            }
        }
    }

    private func digitKey(_ digit: Int) -> some View {
        Button { onDigit(digit) } label: {
            Text("\(digit)").font(Fonts.baloo(38 * s, .bold)).foregroundStyle(Palette.ink)
        }
        .buttonStyle(ChunkyButtonStyle(color: Palette.white, base: Palette.keyShadow))
        .frame(height: keyHeight)
        .accessibilityIdentifier("key.\(digit)")
    }
}
