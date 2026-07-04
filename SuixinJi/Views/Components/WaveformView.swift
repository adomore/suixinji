import SwiftUI

/// The app's single "signature" element (UI Brief §7): the voice waveform.
/// Used in the recording bar, the live recording state, and the playback bar.
///
/// Renders rounded vertical bars. Bars up to `progress` are painted in the
/// accent color (played portion); the rest use `inactiveColor`.
struct WaveformView: View {
    /// Normalized bar heights, 0…1. If empty a neutral resting pattern is drawn.
    var samples: [CGFloat] = []
    var progress: CGFloat = 1              // 0…1 — fraction painted "active"
    var barWidth: CGFloat = 2.5
    var spacing: CGFloat = 2.5
    var minHeight: CGFloat = 6
    var maxHeight: CGFloat = 24
    var activeColor: Color = .brand
    var inactiveColor: Color = Color(uiColor: .tertiaryLabel)

    private var bars: [CGFloat] {
        samples.isEmpty ? WaveformView.restingPattern : samples
    }

    var body: some View {
        GeometryReader { geo in
            let count = bars.count
            let activeCount = Int((CGFloat(count) * progress).rounded())
            HStack(alignment: .center, spacing: spacing) {
                ForEach(bars.indices, id: \.self) { i in
                    Capsule()
                        .fill(i < activeCount ? activeColor : inactiveColor)
                        .frame(
                            width: barWidth,
                            height: minHeight + (maxHeight - minHeight) * bars[i]
                        )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }

    /// A calm, symmetric default so an empty/idle waveform still reads as "voice".
    static let restingPattern: [CGFloat] = [
        0.15, 0.5, 0.25, 0.8, 0.35, 0.95, 0.15, 0.45, 0.2, 0.75,
        0.3, 0.6, 0.15, 0.45, 0.15, 0.35, 0.55, 0.2, 0.7, 0.3,
    ]
}

/// Small, fixed 5-bar mark used as the "🎙️ 0:35" badge on timeline cards and
/// in the empty state (a scaled-down echo of the signature waveform).
struct WaveformBadgeMark: View {
    var color: Color = Color(uiColor: .secondaryLabel)
    var heights: [CGFloat] = [5, 8, 11, 8, 5]

    var body: some View {
        HStack(alignment: .center, spacing: 1.4) {
            ForEach(heights.indices, id: \.self) { i in
                Capsule().fill(color).frame(width: 1.4, height: heights[i])
            }
        }
    }
}
