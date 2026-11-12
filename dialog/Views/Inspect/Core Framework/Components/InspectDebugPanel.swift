//
//  InspectDebugPanel.swift
//
//  An on-screen debug panel for enrollment, where nobody can reach the logs: loaded config, rows,
//  per-source event counts, IPC lines and preference domains. Opt-in via `DIALOG_INSPECT_DEBUG`.
//  Polls `InspectDebugMeter` on a timer so it never invalidates the view it measures.

import Combine
import SwiftUI

struct InspectDebugPanel: View {
    @State private var snapshot = InspectDebugMeter.shared.snapshot()
    @State private var showing = false
    @State private var showRecent = true
    @State private var paused = false
    /// 0 is "All"; 1…n select one source. Steps and wraps, since there can be many sources.
    @State private var selected = 0
    @State private var dumpedPath: String?
    /// The popover tab: live sources or preference domains.
    @State private var tab = 0
    @State private var domainIndex = 0
    @Environment(\.palette) private var palette

    private let tick = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        Button {
            showing.toggle()
        } label: {
            // Small but legible: findable without competing with the branded screen.
            HStack(spacing: 5) {
                Image(systemName: "waveform.path.ecg")
                Text("\(liveSourceCount)/\(snapshot.sources.count)")
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.black.opacity(0.55)))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .help("Detection sources — \(liveSourceCount) of \(snapshot.sources.count) reporting")
        .popover(isPresented: $showing, arrowEdge: .bottom) { panel }
        .onReceive(tick) { _ in
            guard !paused else { return }
            let fresh = InspectDebugMeter.shared.snapshot()
            if fresh != snapshot { snapshot = fresh }
        }
    }

    /// A source is live when anything arrived for it, matched or not.
    private var liveSourceCount: Int { snapshot.sources.filter { $0.meter.attempts > 0 }.count }

    private func step(_ delta: Int) {
        let total = snapshot.sources.count + 1        // +1 for "All"
        selected = ((selected + delta) % total + total) % total
    }

    private var selectedName: String {
        selected == 0 ? "All sources" : snapshot.sources[selected - 1].name
    }

    /// The rotator's one-line diagnosis for the selected source.
    private var selectedDetail: String {
        if selected == 0 {
            return "\(liveSourceCount) of \(snapshot.sources.count) reporting"
        }
        let meter = snapshot.sources[selected - 1].meter
        guard meter.attempts > 0 else { return "nothing arrived — this source is silent on this host" }
        let ago = meter.lastAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        if meter.count == 0 {
            return "\(meter.attempts) arrived, NONE matched a row · last \(ago)s ago"
        }
        return "\(meter.count) of \(meter.attempts) matched · last \(ago)s ago · \(meter.lastItem)"
    }

    private var visibleLines: [RecentLine] {
        guard selected > 0 else { return snapshot.recent }
        let name = snapshot.sources[selected - 1].name
        return snapshot.recent.filter { $0.source == name }
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("", selection: $tab) {
                    Text("Detection").tag(0)
                    Text("Preferences").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)
                Spacer()
                Toggle("Pause", isOn: $paused).toggleStyle(.switch).controlSize(.mini)
            }

            if tab == 1 { plistTab } else { detectionTab }

            // The dump path is shown and selectable, so it can be written down and collected later.
            HStack(spacing: 8) {
                Button("Dump to /private/tmp") {
                    dumpedPath = InspectDebugMeter.shared.dump() ?? "dump failed"
                }
                .controlSize(.small)
                if let dumpedPath {
                    Text(dumpedPath)
                        .font(.system(size: 10.5).monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .textSelection(.enabled)
                }
            }
        }
        .padding(14)
        .frame(width: 460)
    }

    // MARK: - Preferences

    private var domains: [InspectPlistInspector.Domain] { InspectPlistInspector.domains() }

    private var plistTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Same rotator shape as the sources: one control, current name always visible.
            HStack(spacing: 8) {
                Button { rotateDomain(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 1) {
                    Text(domains[domainIndex].name)
                        .font(.system(size: 12.5, weight: .semibold).monospaced())
                    Text(domains[domainIndex].note)
                        .font(.system(size: 10.5)).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { rotateDomain(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary.opacity(0.5)))

            Text(domains[domainIndex].path)
                .font(.system(size: 10.5).monospaced())
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let keys = InspectPlistInspector.read(domains[domainIndex]) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(keys, id: \.0) { key, value in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.system(size: 10.5, weight: .medium).monospaced())
                                    .frame(width: 150, alignment: .leading)
                                Text(value)
                                    .font(.system(size: 10.5).monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            } else {
                // An absent domain is the finding, not an empty state.
                Text("NOT PRESENT — this domain has not arrived on this Mac")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.orange)
                    .frame(height: 220, alignment: .top)
            }
        }
    }

    private func rotateDomain(_ delta: Int) {
        let total = domains.count
        domainIndex = ((domainIndex + delta) % total + total) % total
    }

    private var detectionTab: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Steps through every source and back to All; a count of 0 means that source is not reporting.
            HStack(spacing: 8) {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.borderless)
                VStack(alignment: .leading, spacing: 1) {
                    Text(selectedName)
                        .font(.system(size: 12.5, weight: .semibold).monospaced())
                    Text(selectedDetail)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.borderless)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 7).fill(.quaternary.opacity(0.5)))

            // Every source that can move a row, listed even at zero.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(snapshot.sources, id: \.name) { entry in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(entry.meter.attempts == 0 ? Color.secondary.opacity(0.35)
                                  : entry.meter.count > 0 ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(entry.name)
                            .font(.system(size: 11.5, weight: .medium).monospaced())
                            .frame(width: 118, alignment: .leading)
                        // matched / arrived. Amber: arriving but matching nothing; grey: not arriving.
                        Text("\(entry.meter.count)/\(entry.meter.attempts)")
                            .font(.system(size: 11.5).monospacedDigit())
                            .frame(width: 56, alignment: .trailing)
                        Text(entry.meter.lastItem.isEmpty ? "—" : entry.meter.lastItem)
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Divider()

            // Loaded deck, current step, row count, and whatever arrived over IPC.
            VStack(alignment: .leading, spacing: 3) {
                ForEach(snapshot.facts, id: \.0) { key, value in
                    HStack(alignment: .top, spacing: 8) {
                        Text(key)
                            .font(.system(size: 11, weight: .medium).monospaced())
                            .frame(width: 118, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Text(value).font(.system(size: 11)).textSelection(.enabled)
                    }
                }
            }

            Divider()

            DisclosureGroup(isExpanded: $showRecent) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        // Newest first.
                        ForEach(Array(visibleLines.suffix(60).reversed().enumerated()),
                                id: \.offset) { _, line in
                            Text(line.text)
                                .font(.system(size: 10.5).monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 150)
            } label: {
                Text(selected == 0 ? "Recent (\(visibleLines.count))"
                                   : "Recent · \(selectedName) (\(visibleLines.count))")
                    .font(.system(size: 11.5, weight: .medium))
            }
        }
    }
}
