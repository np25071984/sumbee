import SwiftUI

/// A button with a darker base under it that sinks onto the base while pressed: immediate feedback on
/// every tap (FR-3.2) without a highlight.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color
    var base: Color
    var radius: CGFloat = 20
    var depth: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        ChunkyBody(configuration: configuration, style: self)
    }
}

private struct ChunkyBody: View {
    let configuration: ButtonStyleConfiguration
    let style: ChunkyButtonStyle
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.uiScale) private var s

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.radius * s, style: .continuous)
        ZStack {
            shape.fill(style.base).padding(.top, style.depth * s)
            configuration.label
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(shape.fill(style.color))
                .padding(.bottom, style.depth * s)
                .offset(y: configuration.isPressed ? style.depth * 0.8 * s : 0)
        }
        .opacity(isEnabled ? 1 : 0.45)
        .contentShape(shape)
    }
}

extension View {
    /// Lays out a line of Baloo 2 digits at the height of the digits alone. Baloo's line box is 1.602 em
    /// (ascent 1.078, descent 0.524) for digits 0.602 em tall standing on the baseline, so a big number
    /// would otherwise cost almost three times its visible height. Keeps the baseline for alignment.
    func digitsOnly(_ size: CGFloat) -> some View {
        padding(.top, -(1.078 - 0.602) * size).padding(.bottom, -0.524 * size)
    }

    /// `digitsOnly` for a word in `Fonts.words`: the trim fits Baloo's line box, not Nunito's.
    @ViewBuilder func wordsTrim(_ size: CGFloat) -> some View {
        if Fonts.wordsInBaloo { digitsOnly(size) } else { self }
    }
}

/// The handful of stroke icons the screens use, drawn on a 24-unit grid as on Android.
enum Icon {
    case arrowRight, check, backspace, clock, question, playAgain, close

    fileprivate var stroke: CGFloat {
        switch self {
        case .arrowRight, .check, .playAgain, .close: 3
        case .backspace, .clock, .question: 2.5
        }
    }

    fileprivate func draw(_ p: inout Path) {
        func line(_ points: CGPoint...) { p.addLines(points) }
        func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
            p.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
        switch self {
        case .arrowRight:
            line(.init(x: 5, y: 12), .init(x: 19, y: 12))
            line(.init(x: 13, y: 6), .init(x: 19, y: 12), .init(x: 13, y: 18))
        case .check:
            line(.init(x: 5, y: 12.5), .init(x: 9.5, y: 17), .init(x: 19, y: 7.5))
        case .backspace:
            p.move(to: .init(x: 21, y: 5))
            p.addLine(to: .init(x: 9, y: 5))
            p.addLine(to: .init(x: 3, y: 12))
            p.addLine(to: .init(x: 9, y: 19))
            p.addLine(to: .init(x: 21, y: 19))
            p.addQuadCurve(to: .init(x: 22, y: 18), control: .init(x: 22, y: 19))
            p.addLine(to: .init(x: 22, y: 6))
            p.addQuadCurve(to: .init(x: 21, y: 5), control: .init(x: 22, y: 5))
            p.closeSubpath()
            line(.init(x: 17, y: 9), .init(x: 11, y: 15))
            line(.init(x: 11, y: 9), .init(x: 17, y: 15))
        case .clock:
            circle(12, 13, 8)
            line(.init(x: 12, y: 9), .init(x: 12, y: 13), .init(x: 14, y: 15))
            line(.init(x: 10, y: 2), .init(x: 14, y: 2))
        case .question:
            circle(12, 12, 10)
            // The hook of the "?": the SVG's 3-unit arc from (9.1, 9) to (14.9, 10), then its curl down.
            p.move(to: .init(x: 9.1, y: 9))
            p.addArc(center: .init(x: 11.9, y: 10.07), radius: 3, startAngle: .degrees(-159), endAngle: .degrees(-1.3), clockwise: false)
            p.addCurve(to: .init(x: 11.9, y: 13), control1: .init(x: 14.9, y: 12), control2: .init(x: 11.9, y: 13))
            line(.init(x: 12, y: 17), .init(x: 12.01, y: 17))
        case .playAgain:
            p.addArc(center: .init(x: 12, y: 12), radius: 9, startAngle: .degrees(180), endAngle: .degrees(228.2), clockwise: true)
            line(.init(x: 3, y: 4), .init(x: 3, y: 9), .init(x: 8, y: 9))
        case .close:
            line(.init(x: 6, y: 6), .init(x: 18, y: 18))
            line(.init(x: 18, y: 6), .init(x: 6, y: 18))
        }
    }
}

private struct IconShape: Shape {
    let icon: Icon

    func path(in rect: CGRect) -> Path {
        var p = Path()
        icon.draw(&p)
        return p.applying(CGAffineTransform(scaleX: rect.width / 24, y: rect.height / 24))
    }
}

struct IconView: View {
    let icon: Icon
    var size: CGFloat = 24
    var color: Color = Palette.ink
    @Environment(\.uiScale) private var s

    var body: some View {
        IconShape(icon: icon)
            .stroke(color, style: StrokeStyle(lineWidth: icon.stroke * size * s / 24, lineCap: .round, lineJoin: .round))
            .frame(width: size * s, height: size * s)
            .accessibilityHidden(true)
    }
}

func formatTime(_ seconds: Int) -> String {
    String(format: "%d:%02d", seconds / 60, seconds % 60)
}
