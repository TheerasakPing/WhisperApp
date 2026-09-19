#if os(macOS)
import Foundation
import AVFoundation
import ScreenCaptureKit
import CoreMedia
import AudioToolbox

enum SystemAudioRecorderError: LocalizedError {
    case noDisplay
    case writerSetupFailed(String)
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .noDisplay:
            return "No display is available for system audio capture."
        case .writerSetupFailed(let detail):
            return "Could not prepare system audio recording: \(detail)"
        case .startFailed(let detail):
            return "Could not start system audio capture: \(detail)"
        }
    }
}

/// Captures macOS system audio into a 16 kHz mono WAV using ScreenCaptureKit.
/// Screen Recording permission is required by macOS for system-audio capture.
final class SystemAudioRecorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let captureQueue = DispatchQueue(label: "WhisperApp.SystemAudioCapture")
    private var stream: SCStream?
    private var writer: AVAssetWriter?
    private var writerInput: AVAssetWriterInput?
    private var outputURL: URL?
    private var didStartSession = false
    private var stopping = false

    var isRecording: Bool { stream != nil && !stopping }

    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        guard stream == nil else {
            completion(.success(()))
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_system_\(UUID().uuidString)")
            .appendingPathExtension("wav")
        outputURL = url
        stopping = false
        didStartSession = false

        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(
                    false,
                    onScreenWindowsOnly: true
                )
                guard let display = content.displays.first else {
                    throw SystemAudioRecorderError.noDisplay
                }

                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: [],
                    exceptingWindows: []
                )
                let config = SCStreamConfiguration()
                config.width = 2
                config.height = 2
                config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
                config.showsCursor = false
                config.capturesAudio = true
                config.excludesCurrentProcessAudio = true
                config.sampleRate = 16_000
                config.channelCount = 1

                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(
                    self,
                    type: .audio,
                    sampleHandlerQueue: captureQueue
                )
                self.stream = stream
                try await stream.startCapture()
                await MainActor.run { completion(.success(())) }
            } catch {
                cleanupWriter(deleteOutput: true)
                stream = nil
                await MainActor.run {
                    completion(.failure(SystemAudioRecorderError.startFailed(error.localizedDescription)))
                }
            }
        }
    }

    func stop(completion: @escaping (URL?) -> Void) {
        guard let stream else {
            completion(nil)
            return
        }
        stopping = true

        Task {
            try? await stream.stopCapture()
            self.stream = nil

            captureQueue.async { [weak self] in
                guard let self else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                guard let writer = self.writer,
                      let input = self.writerInput,
                      self.didStartSession else {
                    let url = self.outputURL
                    self.cleanupWriter(deleteOutput: true)
                    DispatchQueue.main.async {
                        _ = url
                        completion(nil)
                    }
                    return
                }

                input.markAsFinished()
                writer.finishWriting { [weak self] in
                    guard let self else {
                        DispatchQueue.main.async { completion(nil) }
                        return
                    }
                    let url = writer.status == .completed ? self.outputURL : nil
                    if writer.status != .completed {
                        print("❌ System audio writer failed: \(writer.error?.localizedDescription ?? "unknown")")
                    }
                    self.cleanupWriter(deleteOutput: writer.status != .completed)
                    DispatchQueue.main.async { completion(url) }
                }
            }
        }
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .audio,
              sampleBuffer.isValid,
              CMSampleBufferDataIsReady(sampleBuffer),
              !stopping else { return }

        do {
            try ensureWriter(for: sampleBuffer)
        } catch {
            print("❌ System audio writer setup: \(error.localizedDescription)")
            return
        }

        guard let writer, let input = writerInput, input.isReadyForMoreMediaData else { return }

        if !didStartSession {
            writer.startWriting()
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            writer.startSession(atSourceTime: time)
            didStartSession = true
        }
        if !input.append(sampleBuffer) {
            print("❌ System audio append failed: \(writer.error?.localizedDescription ?? "unknown")")
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("❌ System audio capture stopped: \(error.localizedDescription)")
    }

    private func ensureWriter(for sampleBuffer: CMSampleBuffer) throws {
        guard writer == nil else { return }
        guard let outputURL else {
            throw SystemAudioRecorderError.writerSetupFailed("Missing output URL")
        }

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .wav)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]

        let input = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: settings,
            sourceFormatHint: CMSampleBufferGetFormatDescription(sampleBuffer)
        )
        input.expectsMediaDataInRealTime = true

        guard writer.canAdd(input) else {
            throw SystemAudioRecorderError.writerSetupFailed("AVAssetWriter rejected the audio input")
        }
        writer.add(input)
        self.writer = writer
        self.writerInput = input
    }

    private func cleanupWriter(deleteOutput: Bool) {
        let url = outputURL
        writer = nil
        writerInput = nil
        didStartSession = false
        stopping = false
        outputURL = nil
        if deleteOutput, let url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
#endif
