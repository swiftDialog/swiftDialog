//
//  Validation.swift
//  dialog
//
//  Models and the main-actor `Validation` service for file and plist checks; the Validation+*.swift
//  extensions hold the checks, caching and async evaluation.
//

import Foundation

// MARK: - Validation Models

struct ValidationRequest {
    let item: InspectConfig.ItemConfig
    let plistSources: [InspectConfig.PlistSourceConfig]?
    let basePath: String?  // Config directory; relative paths resolve against it

    init(item: InspectConfig.ItemConfig, plistSources: [InspectConfig.PlistSourceConfig]? = nil, basePath: String? = nil) {
        self.item = item
        self.plistSources = plistSources
        self.basePath = basePath
    }
}

/// Crosses a task group in `withTimeout`, so it must stay `Sendable`.
struct ValidationResult: Sendable {
    let itemId: String
    let isValid: Bool
    let validationType: ValidationType
    let details: ValidationDetails?
}

enum ValidationType: Sendable {
    case fileExistence
    case plistValidation
    case complexPlistValidation
}

struct ValidationDetails: Sendable {
    let path: String
    let key: String?
    let expectedValue: String?
    let actualValue: String?
    let evaluationType: String?
}

// MARK: - Validation Service

@MainActor
class Validation: ObservableObject {

    // MARK: - Singleton
    static let shared = Validation()

    // MARK: - Caching
    struct CachedPlist {
        let data: [String: Any]
        let lastModified: Date
        let fileSize: Int64
    }

    var plistCache = [String: CachedPlist]()
    let cacheQueue = DispatchQueue(label: "validation.cache", qos: .userInitiated, attributes: .concurrent)
    let maxCacheSize = 100 // plists

    // MARK: - Publishers
    @Published var validationProgress: Double = 0.0
    @Published var isValidating: Bool = false
    
}
