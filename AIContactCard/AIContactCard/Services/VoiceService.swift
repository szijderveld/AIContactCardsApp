//
//  VoiceService.swift
//  AIContactCard
//

import Speech
import AVFoundation

@MainActor
@Observable
class VoiceService {
    var isRecording = false
    var transcript = ""
    var errorMessage: String?

    private var audioEngine = AVAudioEngine()
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            errorMessage = "Speech recognition permission denied. Please enable it in Settings > Privacy > Speech Recognition."
            return false
        }

        // Request microphone permission
        let micGranted: Bool
        if AVAudioApplication.shared.recordPermission == .granted {
            micGranted = true
        } else {
            micGranted = await AVAudioApplication.requestRecordPermission()
        }

        guard micGranted else {
            errorMessage = "Microphone permission denied. Please enable it in Settings > Privacy > Microphone."
            return false
        }

        return true
    }

    func startRecording() throws {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is not available on this device."
            return
        }

        // Reset state
        transcript = ""
        errorMessage = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }

                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }

                if let error {
                    // Ignore cancellation errors from stopRecording
                    if (error as NSError).code != 216 && (error as NSError).domain != "kAFAssistantErrorDomain" {
                        self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    }
                    self.stopRecordingInternal()
                }
            }
        }

        // Install audio tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
    }

    @discardableResult
    func stopRecording() -> String {
        stopRecordingInternal()
        return transcript
    }

    private func stopRecordingInternal() {
        guard isRecording else { return }

        recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        isRecording = false
    }
}
