import Foundation
import AVFoundation
import Combine
import UIKit

/// Records a single voice memo to a temporary `.m4a` (AAC) file.
///
/// Implements the F3 rules from the PRD:
///  • one recording at a time, ≤ 10 minutes (auto-stops at the cap);
///  • a phone call / backgrounding interrupts → we auto-save the recorded part.
@MainActor
final class AudioRecorder: NSObject, ObservableObject {
    /// Live elapsed seconds while recording.
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRecording = false
    /// Rolling, normalized (0…1) mic levels — feeds the live waveform.
    @Published private(set) var levels: [CGFloat] = []

    /// Called when a recording finishes (manual stop, cap, or interruption).
    /// Hands back the temp file URL and its duration.
    var onFinish: ((URL, TimeInterval) -> Void)?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var tempURL: URL?
    private let maxLevelBars = 40

    // MARK: Permission

    /// Request mic permission. `granted == false` should trigger the "去设置" alert.
    func requestPermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { granted in
                cont.resume(returning: granted)
            }
        }
    }

    var permissionDenied: Bool {
        AVAudioApplication.shared.recordPermission == .denied
    }

    // MARK: Recording

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.duckOthers])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("rec-\(UUID().uuidString).m4a")
        tempURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        let rec = try AVAudioRecorder(url: url, settings: settings)
        rec.delegate = self
        rec.isMeteringEnabled = true
        rec.record()
        recorder = rec

        elapsed = 0
        levels = []
        isRecording = true
        observeInterruptions()

        let t = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Manual stop. Fires `onFinish`.
    func stop() {
        finish()
    }

    /// Discard without saving (e.g. user tapped ✕ / 取消).
    func cancel() {
        timer?.invalidate(); timer = nil
        recorder?.stop()
        if let url = tempURL { try? FileManager.default.removeItem(at: url) }
        teardown()
    }

    // MARK: Internals

    private func tick() {
        guard let rec = recorder, rec.isRecording else { return }
        elapsed = rec.currentTime
        rec.updateMeters()
        // dBFS (~ -60…0) → 0…1
        let power = rec.averagePower(forChannel: 0)
        let norm = CGFloat(max(0, (power + 60) / 60))
        levels.append(norm)
        if levels.count > maxLevelBars { levels.removeFirst(levels.count - maxLevelBars) }

        if elapsed >= Layout.maxRecordSeconds { finish() } // 10-minute cap
    }

    private func finish() {
        timer?.invalidate(); timer = nil
        let duration = recorder?.currentTime ?? elapsed
        recorder?.stop()
        let url = tempURL
        teardown()
        if let url { onFinish?(url, duration) }
    }

    private func teardown() {
        isRecording = false
        recorder = nil
        tempURL = nil
        NotificationCenter.default.removeObserver(self)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: Interruptions (call) + backgrounding → auto-save (PRD §3.2 F3, §9)

    private func observeInterruptions() {
        let center = NotificationCenter.default
        // A phone call / Siri / another app posts an audio-session interruption…
        center.addObserver(
            self, selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification, object: nil)
        // …but plain backgrounding does NOT (no background-audio mode), so also
        // finalize on resign-active / entering background to avoid "白录" loss.
        center.addObserver(
            self, selector: #selector(handleBackgrounding),
            name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(handleBackgrounding),
            name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    @objc private func handleInterruption(_ note: Notification) {
        guard
            let info = note.userInfo,
            let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
            AVAudioSession.InterruptionType(rawValue: raw) == .began
        else { return }
        Task { @MainActor in if isRecording { finish() } }
    }

    @objc private func handleBackgrounding() {
        Task { @MainActor in if isRecording { finish() } }
    }
}

extension AudioRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.cancel() }
    }
}
