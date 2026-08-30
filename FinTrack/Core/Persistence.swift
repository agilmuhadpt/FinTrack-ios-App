//  Persistence.swift
//  FinTrack — the local snapshot store.
//
//  The prototype persists `{ data, dark }` under the localStorage key 'fintrack-v1'.
//  Here the same object is written as JSON to fintrack-v1.json in Application Support.
//  Nothing here ever throws to the caller: a missing, unreadable or corrupt file simply
//  loads as nil, and a failed write is dropped silently.

import Foundation

struct Persistence {
    /// The instance the app uses; `Persistence()` is also fine (there is no stored state).
    static let shared = Persistence()

    /// Same identity as the prototype's localStorage key.
    static let fileName = "fintrack-v1.json"

    /// The persisted document: the whole ledger plus the theme flag.
    struct Snapshot: Codable, Hashable {
        var data: AppData
        var dark: Bool

        fileprivate enum CodingKeys: String, CodingKey { case data, dark }

        init(data: AppData, dark: Bool) {
            self.data = data
            self.dark = dark
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let fallback = (decoder.userInfo[.appDataFallback] as? AppData) ?? .demo()
            self.data = (try? c.decodeIfPresent(AppData.self, forKey: .data)) ?? fallback
            // `typeof p.dark === 'boolean' ? p.dark : this.state.dark`
            self.dark = (try? c.decodeIfPresent(Bool.self, forKey: .dark)) ?? false
        }
    }

    init() {}

    // MARK: - Location

    /// .../Application Support/fintrack-v1.json, creating the directory on first use.
    var fileURL: URL? {
        let fm = FileManager.default
        guard let dir = try? fm.url(for: .applicationSupportDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: true) else { return nil }
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(Persistence.fileName)
    }

    // MARK: - Coding

    /// Deterministic key order so two identical snapshots produce byte-identical JSON —
    /// that is what makes the de-duplicated save in `AppStore.persist()` reliable.
    private var encoder: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        // Fields absent from the saved file fall back to the demo ledger, reproducing
        // the prototype's `{ ...this.demoData(), ...p.data }` merge.
        d.userInfo[.appDataFallback] = AppData.demo()
        return d
    }

    func encode(_ snapshot: Snapshot) -> Data? {
        try? encoder.encode(snapshot)
    }

    // MARK: - I/O

    /// Returns nil for an absent, unreadable or corrupt file. Never throws, never crashes.
    func load() -> Snapshot? {
        guard let url = fileURL, let raw = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(Snapshot.self, from: raw)
    }

    func save(_ snapshot: Snapshot) {
        guard let json = encode(snapshot) else { return }
        write(json)
    }

    /// Writes pre-encoded JSON atomically. Used by `AppStore` so a snapshot is only
    /// encoded once per change.
    func write(_ json: Data) {
        guard let url = fileURL else { return }
        try? json.write(to: url, options: [.atomic])
    }

    /// Deletes the saved file (used by "Start fresh" if a hard reset is ever wanted).
    func clear() {
        guard let url = fileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
