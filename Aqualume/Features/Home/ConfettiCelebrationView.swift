import SwiftUI

struct ConfettiCelebrationView: View {
    let trigger: UUID
    let isActive: Bool
    let reduceMotion: Bool

    @State private var startedAt = Date.distantPast
    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: AqualumeAnimationBudget.confettiFrameInterval, paused: timelinePaused)) { timeline in
            Canvas { context, size in
                drawConfetti(in: &context, size: size, date: timeline.date)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            startedAt = Date()
            pieces = ConfettiPiece.make(count: reduceMotion ? 32 : 120)
        }
        .onChange(of: isActive) { _, newValue in
            if !newValue {
                pieces = []
            }
        }
    }

    private var timelinePaused: Bool {
        !isActive
    }

    private func drawConfetti(in context: inout GraphicsContext, size: CGSize, date: Date) {
        guard isActive || date.timeIntervalSince(startedAt) < 4.6 else { return }

        let elapsed = date.timeIntervalSince(startedAt)
        let palette = [
            Color(red: 0.46, green: 0.93, blue: 1.0),
            Color(red: 0.78, green: 1.0, blue: 0.92),
            Color(red: 1.0, green: 0.95, blue: 0.55),
            Color(red: 0.66, green: 0.72, blue: 1.0),
            Color.white
        ]

        for piece in pieces {
            let localElapsed = elapsed - piece.delay
            guard localElapsed >= 0 else { continue }

            let progress = min(1, localElapsed / piece.duration)
            guard progress < 1 else { continue }

            let eased = 1 - pow(1 - progress, 2.2)
            let fallDistance = reduceMotion ? size.height * 0.24 : size.height + 170
            let sway = CGFloat(sin(progress * .pi * 2.0 + piece.phase)) * piece.sway
            let x = piece.x * size.width + sway + piece.drift * CGFloat(eased)
            let y = -34 + CGFloat(eased) * fallDistance
            let opacity = max(0, 1 - CGFloat(progress) * 0.9)
            let rotation = piece.spin * CGFloat(progress)
            let color = palette[piece.colorIndex % palette.count].opacity(opacity)

            var localContext = context
            localContext.translateBy(x: x, y: y)
            localContext.rotate(by: .radians(Double(rotation)))

            let rect = CGRect(
                x: -piece.width / 2,
                y: -piece.height / 2,
                width: piece.width,
                height: piece.height
            )
            let path: Path
            switch piece.shape {
            case 0:
                path = Path(ellipseIn: rect)
            case 1:
                path = Path(roundedRect: rect, cornerRadius: 1.5)
            default:
                path = Path { path in
                    path.move(to: CGPoint(x: 0, y: -piece.height / 2))
                    path.addLine(to: CGPoint(x: piece.width / 2, y: piece.height / 2))
                    path.addLine(to: CGPoint(x: -piece.width / 2, y: piece.height / 2))
                    path.closeSubpath()
                }
            }
            localContext.fill(path, with: .color(color))
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id = UUID()
    let x: CGFloat
    let width: CGFloat
    let height: CGFloat
    let delay: TimeInterval
    let duration: TimeInterval
    let drift: CGFloat
    let sway: CGFloat
    let spin: CGFloat
    let phase: Double
    let shape: Int
    let colorIndex: Int

    static func make(count: Int) -> [ConfettiPiece] {
        (0..<count).map { index in
            ConfettiPiece(
                x: CGFloat.random(in: -0.05...1.05),
                width: CGFloat.random(in: 5...12),
                height: CGFloat.random(in: 7...17),
                delay: TimeInterval.random(in: 0...0.75) + TimeInterval(index % 9) * 0.012,
                duration: TimeInterval.random(in: 2.6...4.4),
                drift: CGFloat.random(in: -150...150),
                sway: CGFloat.random(in: 22...88),
                spin: CGFloat.random(in: -8...8),
                phase: Double.random(in: 0...(Double.pi * 2)),
                shape: Int.random(in: 0...2),
                colorIndex: index
            )
        }
    }
}
