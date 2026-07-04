import SwiftUI

/// The saved-recording bar shown in the editor (UI Brief §4 ②, "录音条").
/// Capsule, height 44: ▶ play + waveform + duration + ✕ delete. Max 1 per entry.
struct RecordingBar: View {
    let audio: DraftAudio
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Play affordance (playback itself happens on the detail page; here it
            // is a visual placeholder consistent with the mock).
            Circle()
                .fill(Color.brand)
                .frame(width: 28, height: 28)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.white)
                }

            WaveformView(progress: 1)
                .frame(height: 24)

            Text(DiaryDateFormat.duration(audio.duration, padMinutes: true))
                .font(.aux13)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.cardBackground, in: Capsule())
    }
}

/// The recording-in-progress capsule (UI Brief §5, "录音中").
/// Red breathing dot + live timer + live waveform + stop button. The user must
/// know at a glance they are recording.
struct RecordingCapsule: View {
    let elapsed: TimeInterval
    let levels: [CGFloat]
    var onStop: () -> Void

    @State private var breathing = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.red)
                .frame(width: 9, height: 9)
                .opacity(breathing ? 0.35 : 1)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: breathing)

            Text(DiaryDateFormat.duration(elapsed, padMinutes: true))
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(.red)

            WaveformView(samples: levels, progress: 1)
                .frame(height: 26)

            Button(action: onStop) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(.white)
                    .frame(width: 10, height: 10)
                    .frame(width: 30, height: 30)
                    .background(Color.red, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5))
        .onAppear { breathing = true }
    }
}
