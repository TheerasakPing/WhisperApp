import Foundation

protocol DictationTranscribing: AnyObject {
    func transcribe(fileURL: URL, language: String, completion: @escaping (String?) -> Void)
    func transcribe(fileURL: URL, language: String, profile: AppProfile?, completion: @escaping (String?) -> Void)
}

extension DictationTranscribing {
    func transcribe(fileURL: URL, language: String, profile: AppProfile?, completion: @escaping (String?) -> Void) {
        transcribe(fileURL: fileURL, language: language, completion: completion)
    }
}

protocol DictationCorrecting: AnyObject {
    func correct(text: String, language: String, completion: @escaping (String?) -> Void)
    func correct(text: String, language: String, profile: AppProfile?, completion: @escaping (String?) -> Void)
}

extension DictationCorrecting {
    func correct(text: String, language: String, profile: AppProfile?, completion: @escaping (String?) -> Void) {
        correct(text: text, language: language, completion: completion)
    }
}

protocol DictationDictionaryApplying: AnyObject {
    func apply(to text: String) -> String
    func apply(to text: String, bundleIdentifier: String?) -> String
}

extension DictationDictionaryApplying {
    func apply(to text: String, bundleIdentifier: String?) -> String {
        apply(to: text)
    }
}

final class DictationPipeline {
    private let cloudTranscriber: DictationTranscribing
    private let localTranscriber: DictationTranscribing
    private let corrector: DictationCorrecting
    private let dictionary: DictationDictionaryApplying
    private let removeFile: (URL) -> Void

    init(
        cloudTranscriber: DictationTranscribing,
        localTranscriber: DictationTranscribing,
        corrector: DictationCorrecting,
        dictionary: DictationDictionaryApplying,
        removeFile: @escaping (URL) -> Void = { url in try? FileManager.default.removeItem(at: url) }
    ) {
        self.cloudTranscriber = cloudTranscriber
        self.localTranscriber = localTranscriber
        self.corrector = corrector
        self.dictionary = dictionary
        self.removeFile = removeFile
    }

    func process(
        _ request: DictationRequest,
        onEvent: @escaping (DictationPipelineEvent) -> Void,
        completion: @escaping (Result<DictationOutcome, DictationPipelineError>) -> Void
    ) {
        let terminalLock = NSLock()
        var finished = false

        func finish(_ result: Result<DictationOutcome, DictationPipelineError>) {
            terminalLock.lock()
            guard !finished else {
                terminalLock.unlock()
                return
            }
            finished = true
            terminalLock.unlock()

            removeFile(request.audioURL)
            switch result {
            case .success(let outcome): onEvent(.completed(outcome))
            case .failure(let error): onEvent(.failed(error))
            }
            completion(result)
        }

        func processTranscript(_ raw: String?) {
            guard let raw else {
                finish(.failure(.transcriptionFailed))
                return
            }

            let cleaned = DictationTextProcessor.stripSoundAnnotations(raw)
            let commandProcessed = VoiceCommandProcessor.apply(to: cleaned)
            guard !commandProcessed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                finish(.failure(.emptyTranscript))
                return
            }

            let completeText: (String?, String) -> Void = { corrected, candidate in
                do {
                    let finalText = try DictationTextProcessor.finalize(candidate) {
                        self.dictionary.apply(to: $0, bundleIdentifier: request.bundleIdentifier)
                    }
                    finish(.success(DictationOutcome(
                        rawTranscript: raw,
                        correctedText: corrected,
                        finalText: finalText
                    )))
                } catch let error as DictationPipelineError {
                    finish(.failure(error))
                } catch {
                    finish(.failure(.emptyTranscript))
                }
            }

            guard request.correctionEnabled else {
                completeText(nil, commandProcessed)
                return
            }

            onEvent(.correcting)
            self.corrector.correct(text: commandProcessed, language: request.language, profile: request.profile) { corrected in
                completeText(corrected, corrected ?? commandProcessed)
            }
        }

        onEvent(.transcribing)
        if request.source == .local {
            localTranscriber.transcribe(fileURL: request.audioURL, language: request.language,
                                        profile: request.profile, completion: processTranscript)
            return
        }

        cloudTranscriber.transcribe(fileURL: request.audioURL, language: request.language,
                                    profile: request.profile) { raw in
            guard raw == nil, request.fallbackToLocalSTT else {
                processTranscript(raw)
                return
            }
            self.localTranscriber.transcribe(fileURL: request.audioURL,
                                             language: request.language,
                                             profile: request.profile,
                                             completion: processTranscript)
        }
    }
}

#if os(macOS)
extension CloudTranscriptionService: DictationTranscribing {}
extension TextCorrectionService: DictationCorrecting {}
extension CorrectionDictionary: DictationDictionaryApplying {}

private final class WhisperDictationTranscriber: DictationTranscribing {
    private let service = WhisperService()

    func transcribe(fileURL: URL, language: String, completion: @escaping (String?) -> Void) {
        service.language = language
        service.transcribe(fileURL: fileURL, completion: completion)
    }
}

extension DictationPipeline {
    convenience init() {
        self.init(
            cloudTranscriber: CloudTranscriptionService(),
            localTranscriber: WhisperDictationTranscriber(),
            corrector: TextCorrectionService(),
            dictionary: CorrectionDictionary.shared
        )
    }
}
#endif
