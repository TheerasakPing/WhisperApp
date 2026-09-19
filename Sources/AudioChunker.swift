#if os(macOS)
import Foundation
import AVFoundation

enum AudioChunkerError: Error {
    case invalidFormat
    case couldNotCreateBuffer
}

enum AudioChunker {
    static func split(
        fileURL: URL,
        maxChunkSeconds: Double = 240
    ) throws -> [URL] {
        let input = try AVAudioFile(forReading: fileURL)
        let format = input.processingFormat
        guard format.sampleRate > 0 else { throw AudioChunkerError.invalidFormat }

        let ranges = MeetingChunkPolicy.ranges(
            totalFrames: input.length,
            sampleRate: format.sampleRate,
            maxChunkSeconds: maxChunkSeconds
        )
        guard !ranges.isEmpty else { return [] }

        var outputURLs: [URL] = []
        do {
            for (index, range) in ranges.enumerated() {
                input.framePosition = range.startFrame
                let outputURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("meeting_chunk_\(UUID().uuidString)_\(index)")
                    .appendingPathExtension("wav")

                let output = try AVAudioFile(
                    forWriting: outputURL,
                    settings: format.settings,
                    commonFormat: format.commonFormat,
                    interleaved: format.isInterleaved
                )

                var remaining = range.length
                let blockFrames: AVAudioFrameCount = 131_072
                while remaining > 0 {
                    let count = AVAudioFrameCount(min(Int64(blockFrames), remaining))
                    guard let buffer = AVAudioPCMBuffer(
                        pcmFormat: format,
                        frameCapacity: count
                    ) else {
                        throw AudioChunkerError.couldNotCreateBuffer
                    }
                    try input.read(into: buffer, frameCount: count)
                    guard buffer.frameLength > 0 else { break }
                    try output.write(from: buffer)
                    remaining -= Int64(buffer.frameLength)
                }
                outputURLs.append(outputURL)
            }
            return outputURLs
        } catch {
            for url in outputURLs { try? FileManager.default.removeItem(at: url) }
            throw error
        }
    }
}
#endif
