import Foundation
import Speech
import AVFoundation

/// Live speech-to-text (F2). Prefers on-device recognition (offline, private,
/// no data usage) per the PRD; falls back to server recognition only if the
/// device can't do it offline.
@MainActor
final class SpeechTranscriber: NSObject, ObservableObject {
    @Published private(set) var isTranscribing = false
    /// Text recognized during the *current* session (resets on each start).
    @Published private(set) var partialText = ""

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    enum TranscribeError: LocalizedError {
        case unavailable
        case notAuthorized
        case offlineUnsupported
        var errorDescription: String? {
            switch self {
            case .unavailable: return "语音识别暂不可用。"
            case .notAuthorized: return "需要麦克风与语音识别权限。"
            case .offlineUnsupported: return "需要联网使用语音转文字。"
            }
        }
    }

    // MARK: Permissions

    func requestAuthorization() async -> Bool {
        let speech = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard speech == .authorized else { return false }
        return await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    var authorizationDenied: Bool {
        SFSpeechRecognizer.authorizationStatus() == .denied
            || AVAudioApplication.shared.recordPermission == .denied
    }

    // MARK: Session

    /// Starts recognizing. `onUpdate` receives the best transcript so far so the
    /// caller can append it. `onError` reports a user-facing failure message
    /// (e.g. the offline-unsupported case from PRD §9).
    func start(
        onUpdate: @escaping (String) -> Void,
        onError: @escaping (String) -> Void = { _ in }
    ) throws {
        guard let recognizer, recognizer.isAvailable else { throw TranscribeError.unavailable }

        task?.cancel(); task = nil

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }
        request = req

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak req] buffer, _ in
            req?.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            // Undo the tap so a retry doesn't double-install (which would raise an
            // uncatchable AVAudioEngine exception and crash).
            input.removeTap(onBus: 0)
            req.endAudio()
            request = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }

        partialText = ""
        isTranscribing = true

        let onDevice = recognizer.supportsOnDeviceRecognition
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let result {
                    let text = result.bestTranscription.formattedString
                    self.partialText = text
                    onUpdate(text)
                    if result.isFinal { self.stop() }
                }
                if error != nil {
                    // A failure with no partial result and no on-device support is
                    // almost always "offline, can't reach the server" (PRD §9).
                    if !onDevice && self.partialText.isEmpty {
                        onError(TranscribeError.offlineUnsupported.errorDescription ?? "语音识别失败。")
                    }
                    self.stop()
                }
            }
        }
    }

    func stop() {
        guard isTranscribing else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil
        task = nil
        isTranscribing = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
