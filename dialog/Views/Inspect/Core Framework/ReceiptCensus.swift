//
//  ReceiptCensus.swift
//  dialog
//
//  Counts installs finished since launch from `/var/db/receipts` without an authored pkgId table.
//  Receipts written within `clusterWindow` of each other are one install (a distribution writes
//  several component receipts at once). It cannot say which row finished, only how many.
//

import Foundation

enum ReceiptCensus {

    /// Seconds. Receipts written closer together than this are one install; sequential installs
    /// are at least ~30 s apart, component receipts within a second or two.
    static let clusterWindow: TimeInterval = 10

    /// One receipt on disk: the package identifier and when installd wrote it.
    struct Receipt: Hashable {
        let id: String
        let writtenAt: Date
    }

    /// The receipts in `directory` by package identifier (`.plist` and `.bom` are one receipt), each
    /// with the earliest write time of its files. A missing directory is an empty set.
    static func receipts(in directory: String) -> Set<Receipt> {
        let base = (directory as NSString).expandingTildeInPath
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: base) else { return [] }
        var earliest: [String: Date] = [:]
        for name in names {
            let ns = name as NSString
            guard ["plist", "bom"].contains(ns.pathExtension.lowercased()) else { continue }
            let id = ns.deletingPathExtension
            let attrs = try? FileManager.default.attributesOfItem(atPath: base + "/" + name)
            let when = (attrs?[.modificationDate] as? Date) ?? .distantPast
            earliest[id] = min(earliest[id] ?? .distantFuture, when)
        }
        return Set(earliest.map { Receipt(id: $0.key, writtenAt: $0.value) })
    }

    /// The identifiers alone; a baseline of ids keeps an in-place upgrade from counting as new.
    static func identifiers(in directory: String) -> Set<String> {
        Set(receipts(in: directory).map(\.id))
    }

    /// Installs finished since `baseline`, clamped to `total`: new receipts sorted by write time and
    /// split into clusters wherever the gap exceeds `window`.
    static func newInstalls(now: Set<Receipt>, baseline: Set<String>, total: Int,
                            window: TimeInterval = clusterWindow) -> Int {
        let fresh = now.filter { !baseline.contains($0.id) }.map(\.writtenAt).sorted()
        guard !fresh.isEmpty else { return 0 }
        var clusters = 1
        for (previous, current) in zip(fresh, fresh.dropFirst()) where current.timeIntervalSince(previous) > window {
            clusters += 1
        }
        return min(clusters, max(total, 0))
    }

}
