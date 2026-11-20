// DeploymentStepViews.swift
//
// The deployment step's rotating side message and its status sort order; used by Preset 5's
// deployment step and card carousel.

import SwiftUI

// MARK: - Rotating message line

/// The root `sideMessage` line in a seat as tall as its longest message, so rotating to a longer one
/// never moves what follows. Every message is laid out hidden underneath; only `current` shows.
struct RotatingMessageLine: View {
    let messages: [String]
    let current: String
    /// Changes with each rotation, so the new line fades in rather than morphing the old one.
    let index: Int
    var font: Font = .system(size: 13)
    var alignment: TextAlignment = .leading

    var body: some View {
        ZStack(alignment: alignment == .center ? .top : .topLeading) {
            ForEach(messages.indices, id: \.self) { i in
                line(messages[i]).hidden()
            }
            line(current)
                .foregroundStyle(.secondary)
                .id(index)
                .transition(.opacity)
                .animation(.easeInOut(duration: InspectConstants.standardAnimationDuration), value: index)
        }
    }

    private func line(_ text: String) -> some View {
        Text(text).font(font).lineLimit(2).multilineTextAlignment(alignment)
    }
}

// MARK: - Side Message View

/// Rotating messages; the timer starts and stops with the view lifecycle.
struct DeploymentSideMessageView: View {
    let messages: [String]
    let interval: Int

    @State private var currentIndex: Int = 0
    @State private var rotation: Poll?

    var body: some View {
        if !messages.isEmpty {
            let safeIndex = min(currentIndex, messages.count - 1)
            Text(messages[safeIndex])
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(minHeight: 40, alignment: .leading)
                .animation(.easeInOut(duration: 0.5), value: currentIndex)
                .onAppear {
                    startRotation()
                }
                .onDisappear {
                    rotation?.cancel()
                    rotation = nil
                }
        }
    }

    /// Cancels any running poll first so a return to the step never stacks a second ticker.
    private func startRotation() {
        guard messages.count > 1, interval > 0 else { return }
        rotation?.cancel()
        let poll = Poll(every: TimeInterval(interval))
        rotation = poll
        poll.start { currentIndex = (currentIndex + 1) % messages.count }
    }
}

// MARK: - Helpers

/// Sorts items completed → active → pending → failed → skipped; the list has no section headers,
/// so this order is the grouping.
func deploymentSortedItems(_ items: [InstallationItemData]) -> [InstallationItemData] {
    items.sorted { a, b in
        statusSortOrder(a.status) < statusSortOrder(b.status)
    }
}

private func statusSortOrder(_ status: StepStatus) -> Int {
    switch status {
    case .completed: return 0
    case .active: return 1
    case .pending: return 2
    case .failed: return 3
    case .skipped: return 4
    }
}
