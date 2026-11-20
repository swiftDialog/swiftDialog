//
//  InspectBlurScope.swift
//  dialog
//
//  Inspect mode's `--blurscreen` covers the dialog's display only. Classic blur opens one window
//  per NSScreen and stays unchanged; this hides the ones off the dialog's display once they exist.
//  Blur and inspect view start in no guaranteed order, so it polls briefly rather than assuming.
//

import AppKit

enum InspectBlurScope {

    /// Which blur windows to hide, by index: every one whose frame is not the dialog's display.
    /// Pure, so a test can hand it two displays.
    static func framesToHide(blurFrames: [CGRect], dialogScreenFrame: CGRect) -> [Int] {
        blurFrames.indices.filter { blurFrames[$0] != dialogScreenFrame }
    }

    /// Inspect mode with `--blurscreen` on more than one display only. Checks every 0.1s for 3s from
    /// the first call and hides blur windows off the dialog's display as they appear.
    @MainActor
    static func confineToDialogScreen() {
        guard appArguments.inspectMode.present, appArguments.blurScreen.present,
              NSScreen.screens.count > 1 else { return }
        let poll = Poll(every: 0.1)
        var runs = 0
        poll.start {
            runs += 1
            confineOnce()
            if runs >= 30 { poll.cancel() }
        }
    }

    @MainActor
    private static func confineOnce() {
        let candidates = [NSApp.keyWindow, NSApp.mainWindow].compactMap { $0 }
            + NSApp.windows.filter { $0.isVisible }
        let dialogScreen = candidates.first { !($0 is BlurWindow) && $0.screen != nil }?.screen ?? NSScreen.main
        guard let dialogScreen else { return }
        let blurs = NSApp.windows.compactMap { $0 as? BlurWindow }.filter(\.isVisible)
        for index in framesToHide(blurFrames: blurs.map(\.frame), dialogScreenFrame: dialogScreen.frame) {
            blurs[index].orderOut(nil)
            writeLog("InspectBlurScope: hid the blur at \(blurs[index].frame) — not the dialog's display", logLevel: .info)
        }
    }
}
