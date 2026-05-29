import SwiftUI

enum AqualumeAnimationBudget {
    static let waterFrameInterval: TimeInterval = 1.0 / 24.0
    static let confettiFrameInterval: TimeInterval = 1.0 / 30.0

    static let ambientBubbleCount = 6
    static let burstBubbleCount = 16
    static let goalBubbleCount = 24
}

struct HydrationGlassView: View {
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let reachedGoal: Bool
    let design: HydrationGlassDesign
    let rippleID: UUID
    let floatingAmount: String?
    let reduceMotion: Bool
    let action: () -> Void

    @State private var animatedProgress = 0.0
    @State private var rippleScale = 0.35
    @State private var rippleOpacity = 0.0
    @State private var bubbleStartedAt = Date.distantPast
    @State private var bubbles: [WaterBubbleParticle] = []

    var body: some View {
        Button(action: action) {
            ZStack {
                goalGlow

                TimelineView(.animation(minimumInterval: AqualumeAnimationBudget.waterFrameInterval, paused: waterTimelinePaused)) { timeline in
                    Canvas { context, size in
                        drawGlass(in: &context, size: size, date: timeline.date)
                    }
                    .aspectRatio(0.72, contentMode: .fit)
                }

                if !reduceMotion {
                    Circle()
                        .stroke(Color.cyan.opacity(rippleOpacity), lineWidth: 2)
                        .scaleEffect(rippleScale)
                        .frame(width: 210, height: 210)
                        .allowsHitTesting(false)
                }

                if let floatingAmount {
                    Text(floatingAmount)
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.cyan : Color(red: 0.02, green: 0.41, blue: 0.50))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(colorScheme == .dark ? Color.white.opacity(0.18) : Color.white.opacity(0.76), in: Capsule())
                        .offset(y: reduceMotion ? -142 : -168)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onAppear {
            animatedProgress = progress
            bubbles = WaterBubbleParticle.make(count: AqualumeAnimationBudget.ambientBubbleCount)
        }
        .onChange(of: progress) { newValue in
            withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.86, dampingFraction: 0.84)) {
                animatedProgress = newValue
            }
        }
        .onChange(of: rippleID) { _ in
            guard !reduceMotion else { return }
            rippleScale = 0.35
            rippleOpacity = 0.55
            bubbleStartedAt = Date()
            bubbles = WaterBubbleParticle.make(count: reachedGoal ? AqualumeAnimationBudget.goalBubbleCount : AqualumeAnimationBudget.burstBubbleCount)
            withAnimation(.easeOut(duration: 0.85)) {
                rippleScale = 1.18
                rippleOpacity = 0
            }
        }
    }

    private var waterTimelinePaused: Bool {
        reduceMotion || animatedProgress <= 0.02
    }

    private var goalGlow: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.49, green: 1.0, blue: 0.83).opacity(reachedGoal ? 0.42 : 0.16),
                        Color.clear
                    ],
                    center: .center,
                    startRadius: 18,
                    endRadius: 180
                )
            )
            .blur(radius: reachedGoal ? 14 : 22)
            .opacity(colorScheme == .dark ? 1 : 0.72)
            .animation(.easeInOut(duration: 1.4), value: reachedGoal)
    }

    private func drawGlass(in context: inout GraphicsContext, size: CGSize, date: Date) {
        let isDark = colorScheme == .dark
        let geometry = GlassGeometry(design: design, size: size)
        let glassRect = geometry.rect
        let topLeft = CGPoint(x: glassRect.minX + glassRect.width * geometry.topInset, y: glassRect.minY)
        let topRight = CGPoint(x: glassRect.maxX - glassRect.width * geometry.topInset, y: glassRect.minY)
        let bottomLeft = CGPoint(x: glassRect.minX + glassRect.width * geometry.bottomInset, y: glassRect.maxY)
        let bottomRight = CGPoint(x: glassRect.maxX - glassRect.width * geometry.bottomInset, y: glassRect.maxY)

        let glassPath = Path { path in
            path.move(to: topLeft)
            path.addQuadCurve(
                to: topRight,
                control: CGPoint(x: glassRect.midX, y: glassRect.minY - geometry.rimLift)
            )
            path.addLine(to: bottomRight)
            path.addLine(to: bottomLeft)
            path.closeSubpath()
        }

        let glassBodyColors = isDark
            ? [Color.white.opacity(0.12), Color(red: 0.42, green: 0.90, blue: 1.0).opacity(0.08)]
            : [Color.white.opacity(0.50), Color(red: 0.60, green: 0.88, blue: 0.92).opacity(0.18)]
        let rimColor = isDark
            ? Color.white.opacity(0.68)
            : Color(red: 0.08, green: 0.42, blue: 0.48).opacity(0.46)
        let outerShadowColor = isDark
            ? Color(red: 0.42, green: 0.96, blue: 1.0).opacity(0.30)
            : Color(red: 0.03, green: 0.38, blue: 0.44).opacity(0.22)

        context.stroke(glassPath, with: .color(outerShadowColor), lineWidth: 6.2)
        context.fill(
            glassPath,
            with: .linearGradient(
                Gradient(colors: glassBodyColors),
                startPoint: CGPoint(x: glassRect.midX, y: glassRect.minY),
                endPoint: CGPoint(x: glassRect.midX, y: glassRect.maxY)
            )
        )
        context.stroke(glassPath, with: .color(rimColor), lineWidth: 2.8)

        let usableHeight = glassRect.height - geometry.rimDepth - 6
        let fillHeight = usableHeight * animatedProgress
        guard fillHeight > 1 else {
            return
        }

        let waterBottom = glassRect.maxY - 3
        let fillRect = CGRect(
            x: glassRect.minX + 6,
            y: waterBottom - fillHeight,
            width: glassRect.width - 12,
            height: fillHeight
        )

        let waveAmplitude = reduceMotion ? 0 : min(10, max(3, fillRect.height * 0.035))
        let phase = date.timeIntervalSinceReferenceDate
        let waveSpeed = reduceMotion ? 0 : phase * 2.6
        func surfaceY(_ normalizedX: CGFloat) -> CGFloat {
            let primary = sin((Double(normalizedX) * .pi * 2.0) + waveSpeed)
            let secondary = sin((Double(normalizedX) * .pi * 4.0) + phase * 1.45) * 0.38
            return fillRect.minY + 9 + CGFloat(primary + secondary) * waveAmplitude
        }

        let waterPath = Path { path in
            let sampleCount = 12
            path.move(to: CGPoint(x: fillRect.minX, y: surfaceY(0)))
            for sample in 1...sampleCount {
                let normalizedX = CGFloat(sample) / CGFloat(sampleCount)
                path.addLine(to: CGPoint(
                    x: fillRect.minX + fillRect.width * normalizedX,
                    y: surfaceY(normalizedX)
                ))
            }
            path.addLine(to: CGPoint(x: fillRect.maxX, y: waterBottom))
            path.addLine(to: CGPoint(x: fillRect.minX, y: waterBottom))
            path.closeSubpath()
        }
        context.clip(to: glassPath)
        context.fill(
            waterPath,
            with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.72, green: 0.96, blue: 1.0).opacity(0.88),
                    Color(red: 0.10, green: 0.65, blue: 0.72).opacity(0.92)
                ]),
                startPoint: CGPoint(x: fillRect.midX, y: fillRect.minY),
                endPoint: CGPoint(x: fillRect.midX, y: fillRect.maxY)
            )
        )

        if !reduceMotion {
            drawBubbles(
                in: &context,
                geometry: geometry,
                fillHeight: fillHeight,
                waterBottom: waterBottom,
                date: date
            )
        }

        if reachedGoal {
            for index in 0..<7 {
                let x = glassRect.minX + 30 + CGFloat(index) * glassRect.width / 8
                let y = glassRect.maxY - 42 - CGFloat(index % 3) * 30
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 6, height: 6)), with: .color(Color.white.opacity(0.48)))
            }
        }
    }
    private func drawBubbles(
        in context: inout GraphicsContext,
        geometry: GlassGeometry,
        fillHeight: CGFloat,
        waterBottom: CGFloat,
        date: Date
    ) {
        let glassRect = geometry.rect
        let waterTop = waterBottom - fillHeight
        let elapsed = date.timeIntervalSince(bubbleStartedAt)

        for bubble in bubbles {
            let isAmbient = bubbleStartedAt == Date.distantPast || elapsed > 1.8
            let localTime = isAmbient
                ? date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: bubble.duration) / bubble.duration
                : max(0, min(1, (elapsed - bubble.delay) / bubble.duration))

            guard isAmbient || (elapsed >= bubble.delay && localTime <= 1) else { continue }

            let rise = CGFloat(localTime) * fillHeight * bubble.rise
            let drift = CGFloat(sin(localTime * .pi * 2 + bubble.phase)) * bubble.drift
            let x = glassRect.minX + glassRect.width * bubble.x + drift
            let y = waterBottom - 12 - rise
            guard y >= waterTop - 6, y <= waterBottom else { continue }

            let opacityBase = isAmbient ? 0.16 : 0.42
            let opacity = opacityBase * (1 - CGFloat(localTime) * 0.72)
            let diameter = bubble.size * (isAmbient ? 0.72 : 1.0 + CGFloat(localTime) * 0.25)
            context.fill(
                Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                with: .color(Color.white.opacity(opacity))
            )
        }
    }
}

private struct GlassGeometry {
    let rect: CGRect
    let topInset: CGFloat
    let bottomInset: CGFloat
    let rimLift: CGFloat
    let rimDepth: CGFloat

    init(design: HydrationGlassDesign, size: CGSize) {
        switch design {
        case .classic:
            rect = CGRect(x: size.width * 0.18, y: size.height * 0.06, width: size.width * 0.64, height: size.height * 0.86)
            topInset = 0.12
            bottomInset = 0.08
            rimLift = 12
            rimDepth = 18
        case .prism:
            rect = CGRect(x: size.width * 0.20, y: size.height * 0.06, width: size.width * 0.60, height: size.height * 0.86)
            topInset = 0.10
            bottomInset = 0.10
            rimLift = 8
            rimDepth = 15
        case .tumbler:
            rect = CGRect(x: size.width * 0.14, y: size.height * 0.07, width: size.width * 0.72, height: size.height * 0.84)
            topInset = 0.05
            bottomInset = 0.18
            rimLift = 11
            rimDepth = 18
        case .flute:
            rect = CGRect(x: size.width * 0.24, y: size.height * 0.04, width: size.width * 0.52, height: size.height * 0.89)
            topInset = 0.17
            bottomInset = 0.06
            rimLift = 13
            rimDepth = 20
        }
    }
}

private struct WaterBubbleParticle: Identifiable {
    let id = UUID()
    let x: CGFloat
    let size: CGFloat
    let delay: TimeInterval
    let duration: TimeInterval
    let drift: CGFloat
    let rise: CGFloat
    let phase: Double

    static func make(count: Int) -> [WaterBubbleParticle] {
        (0..<count).map { index in
            WaterBubbleParticle(
                x: CGFloat.random(in: 0.18...0.78),
                size: CGFloat.random(in: 3.5...9.5),
                delay: TimeInterval(index) * 0.035,
                duration: TimeInterval.random(in: 0.9...1.7),
                drift: CGFloat.random(in: -12...12),
                rise: CGFloat.random(in: 0.38...0.92),
                phase: Double.random(in: 0...(Double.pi * 2))
            )
        }
    }
}
