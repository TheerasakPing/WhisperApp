import Foundation

enum HistoryRetention: String, Codable, CaseIterable, Identifiable {
    case off
    case oneDay
    case sevenDays
    case thirtyDays
    case forever

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: return "Off"
        case .oneDay: return "1 day"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        case .forever: return "Forever"
        }
    }

    var maximumAge: TimeInterval? {
        switch self {
        case .off, .forever: return nil
        case .oneDay: return 86_400
        case .sevenDays: return 7 * 86_400
        case .thirtyDays: return 30 * 86_400
        }
    }
}

enum HistorySource: String, Codable, Equatable {
    case cloud
    case local
}

struct HistoryRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var createdAt: Date
    var rawTranscript: String
    var correctedText: String?
    var finalText: String
    var language: String
    var source: HistorySource
    var correctionEnabled: Bool

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        rawTranscript: String,
        correctedText: String?,
        finalText: String,
        language: String,
        source: HistorySource,
        correctionEnabled: Bool
    ) {
        self.id = id
        self.createdAt = createdAt
        self.rawTranscript = rawTranscript
        self.correctedText = correctedText
        self.finalText = finalText
        self.language = language
        self.source = source
        self.correctionEnabled = correctionEnabled
    }
}

struct HistoryDocument: Codable, Equatable {
    var schemaVersion: Int
    var retention: HistoryRetention
    var records: [HistoryRecord]

    init(
        schemaVersion: Int = 1,
        retention: HistoryRetention = .sevenDays,
        records: [HistoryRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.retention = retention
        self.records = records
    }
}

enum HistoryPolicy {
    static func pruned(
        _ document: HistoryDocument,
        now: Date = Date(),
        maxRecords: Int = 1_000
    ) -> HistoryDocument {
        var copy = document
        var records = copy.records

        if let maximumAge = copy.retention.maximumAge {
            let cutoff = now.addingTimeInterval(-maximumAge)
            records.removeAll { $0.createdAt < cutoff }
        }

        records.sort { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString > rhs.id.uuidString
            }
            return lhs.createdAt > rhs.createdAt
        }

        if maxRecords >= 0, records.count > maxRecords {
            records = Array(records.prefix(maxRecords))
        }
        copy.records = records
        return copy
    }
}
