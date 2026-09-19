#if os(macOS)
import Foundation

enum MeetingTranscriptionError: LocalizedError {
    case noAudio
    case transcriptionFailed
    case chunkingFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAudio: return "No meeting audio was recorded."
        case .transcriptionFailed: return "Meeting transcription failed."
        case .chunkingFailed(let detail): return "Could not split long meeting audio: \(detail)"
        }
    }
}

final class MeetingTranscriptionService {
    private let cloud = CloudTranscriptionService()

    func transcribe(
        fileURL: URL,
        transcriptSource: MeetingTranscriptSource,
        language: String,
        source: MeetingTranscriptionSource,
        completion: @escaping (Result<[MeetingTranscriptSegment], Error>) -> Void
    ) {
        let chunks: [URL]
        do {
            // 4-minute WAV chunks keep 16 kHz mono PCM safely below providers with ~10 MB limits.
            chunks = try AudioChunker.split(fileURL: fileURL, maxChunkSeconds: 240)
        } catch {
            completion(.failure(MeetingTranscriptionError.chunkingFailed(error.localizedDescription)))
            return
        }

        guard !chunks.isEmpty else {
            completion(.failure(MeetingTranscriptionError.noAudio))
            return
        }

        transcribeChunks(
            chunks,
            index: 0,
            language: language,
            source: source,
            texts: []
        ) { result in
            for url in chunks { try? FileManager.default.removeItem(at: url) }
            switch result {
            case .success(let texts):
                let joined = texts
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")
                guard !joined.isEmpty else {
                    completion(.failure(MeetingTranscriptionError.transcriptionFailed))
                    return
                }
                completion(.success([
                    MeetingTranscriptSegment(source: transcriptSource, text: joined)
                ]))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    private func transcribeChunks(
        _ chunks: [URL],
        index: Int,
        language: String,
        source: MeetingTranscriptionSource,
        texts: [String],
        completion: @escaping (Result<[String], Error>) -> Void
    ) {
        guard index < chunks.count else {
            completion(.success(texts))
            return
        }

        let chunk = chunks[index]
        let done: (String?) -> Void = { [weak self] text in
            guard let self else {
                completion(.failure(MeetingTranscriptionError.transcriptionFailed))
                return
            }
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                // If cloud failed and the user enabled local fallback, try the same chunk locally.
                if source == .cloud && STTSettings.fallbackToLocalWhisper {
                    self.localTranscribe(fileURL: chunk, language: language) { localText in
                        guard let localText,
                              !localText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                            completion(.failure(MeetingTranscriptionError.transcriptionFailed))
                            return
                        }
                        self.transcribeChunks(
                            chunks,
                            index: index + 1,
                            language: language,
                            source: source,
                            texts: texts + [localText],
                            completion: completion
                        )
                    }
                    return
                }
                completion(.failure(MeetingTranscriptionError.transcriptionFailed))
                return
            }

            self.transcribeChunks(
                chunks,
                index: index + 1,
                language: language,
                source: source,
                texts: texts + [text],
                completion: completion
            )
        }

        switch source {
        case .cloud:
            cloud.transcribe(fileURL: chunk, language: language, completion: done)
        case .local:
            localTranscribe(fileURL: chunk, language: language, completion: done)
        }
    }

    private func localTranscribe(
        fileURL: URL,
        language: String,
        completion: @escaping (String?) -> Void
    ) {
        let whisper = WhisperService()
        whisper.language = language
        whisper.transcribe(fileURL: fileURL, completion: completion)
    }
}
#endif
