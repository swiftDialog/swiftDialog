//
//  ChromeCopy.swift
//  dialog
//
//  Default English chrome strings used when neither the config nor its language pack sets one.
//  IPC event labels (`DialogNotifications.postButtonClick`) stay literal where sent: consumers match on them.
//

enum ChromeCopy {
    static let `continue` = "Continue"
    static let continueAnyway = "Continue Anyway"
    static let done = "Done"
    static let skip = "Skip"
    static let getHelp = "Get Help"
    static let tryAgain = "Try again"
    static let inProgress = "In progress"
    static let failed = "Failed"
    static let installing = "Installing\u{2026}"
    static let loading = "Loading\u{2026}"
    static let stepFailed = "Step Failed"
    static let stepSkipped = "Step Skipped"
    static let stepCompleted = "Step Completed"
}
