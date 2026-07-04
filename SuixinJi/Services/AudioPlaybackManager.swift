import Foundation
import AVFoundation
import Combine

/// Plays back a saved recording and publishes progress for the detail-page
/// playback bar (▶/⏸ + progress + time).
@MainActor
final class AudioPlaybackManager: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    /// Progress in 0…1, for coloring the waveform up to the play head.
    var progress: CGFloat {
        guard duration > 0 else { return 0 }
        return CGFloat(min(1, currentTime / duration))
    }

    func load(url: URL) {
        stop()
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            player = p
            duration = p.duration
            currentTime = 0
        } catch {
            player = nil
        }
    }

    func toggle() {
        guard let p = player else { return }
        if p.isPlaying { pause() } else { play() }
    }

    private func play() {
        guard let p = player else { return }
        p.play()
        isPlaying = true
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sync() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate(); timer = nil
    }

    /// Stop and release — also call this before deleting an entry that is playing
    /// (PRD §9: "正在播放录音时用户删除了这篇日记 → 先停止播放，再删除").
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        timer?.invalidate(); timer = nil
    }

    private func sync() {
        guard let p = player else { return }
        currentTime = p.currentTime
    }
}

extension AudioPlaybackManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = self.duration
            self.timer?.invalidate(); self.timer = nil
        }
    }
}
