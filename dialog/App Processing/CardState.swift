//
//  CardState.swift
//  dialog
//
//  Created for swiftDialog cards workflow
//

import Foundation
import SwiftyJSON

/// Represents a single card configuration in a multi-card dialog workflow
struct DialogCard: Identifiable {
    var id: Int  // Explicit order of precedence
    var configuration: JSON  // The card's dialog configuration

    init(id: Int, configuration: JSON) {
        self.id = id
        self.configuration = configuration
    }

    /// Page terminates the workflow regardless of remaining pages.
    var isFinal: Bool {
        return configuration["finalpage"].boolValue
    }

    /// Static next-page id override (precedence below `branch`, above array order).
    var nextPageOverride: Int? {
        return configuration["nextpage"].int
    }

    /// Branch configuration for field-driven routing, or nil if none set.
    var branch: JSON? {
        let b = configuration["branch"]
        return b.exists() ? b : nil
    }

    /// Author-supplied stable identifier for the card.
    var cardId: String? {
        return configuration["cardId"].string
    }

    /// Navigation style: sidebar section header this card belongs to.
    var section: String? {
        guard let value = configuration["section"].string, !value.isEmpty else { return nil }
        return value
    }

    /// Navigation style: sidebar label. `sidebartitle` wins, then the card's own `title`.
    /// Inherited (global) titles are deliberately ignored so every row doesn't repeat them.
    var sidebarTitle: String? {
        if let value = configuration["sidebartitle"].string, !value.isEmpty { return value }
        if let value = configuration["title"].string, !value.isEmpty, value != "none" { return value }
        return nil
    }

    /// Navigation style: sidebar icon. `sidebaricon` wins, then the card's own `icon`.
    var sidebarIcon: String? {
        for key in ["sidebaricon", "icon"] {
            if let value = configuration[key].string, !value.isEmpty {
                return value == "none" ? nil : value
            }
        }
        return nil
    }
}

/// How a multi-card workflow is presented.
enum CardStyle: String {
    /// Linear Next / Back pages (the original cards behaviour).
    case wizard
    /// Sidebar of pages, any of which can be opened at any time.
    case navigation
}

/// A run of consecutive cards sharing the same `section` value, for the navigation sidebar.
struct CardSection: Identifiable {
    /// String rather than Int: List uses ForEach ids as implicit selection tags, and an Int
    /// id would collide with the card-index tags, highlighting a section header alongside a row.
    let id: String
    let title: String?
    let cardIndices: [Int]
}

/// Manages the state of a multi-card dialog workflow
class CardState: ObservableObject {

    /// All cards loaded from JSON configuration
    @Published var cards: [DialogCard] = []

    /// Current card index (0-based)
    @Published var currentCardIndex: Int = 0

    /// Whether cards mode is active
    @Published var isCardsMode: Bool = false

    /// Presentation style for the cards (`cardstyle` top-level key)
    @Published var style: CardStyle = .wizard

    /// Navigation style: cards that failed validation or onAdvance when last left.
    /// Key: card index, Value: message describing what needs attention.
    @Published var pageIssues: [Int: String] = [:]

    /// Navigation style: cards the user has left at least once (or that were revealed by a
    /// blocked Done). Issues are only shown in the sidebar for these, so unvisited pages
    /// don't start out covered in warnings.
    @Published var visitedPages: Set<Int> = []

    /// Navigation style: the issue to display for a card, or nil if it is complete or not yet visited.
    func visibleIssue(for index: Int) -> String? {
        guard visitedPages.contains(index) else { return nil }
        return pageIssues[index]
    }

    /// Keys that only make sense once for the whole window in navigation style.
    /// They are stripped from individual cards so page switches never resize or restyle the window.
    static let navigationTopLevelOnlyKeys: [String] = [
        "width", "height", "big", "small", "resizable",
        "position", "positionoffset", "blurscreen", "ontop", "moveable",
        "button1text", "button1symbol", "button2", "button2text", "button2symbol",
        "timer", "hidetimerbar"
    ]

    /// Wizard-only routing keys that have no meaning when any page can be opened at any time.
    /// The infobox is also unavailable - the sidebar replaces the icon / infobox column.
    static let navigationIgnoredKeys: [String] = ["branch", "nextpage", "finalpage", "infobox", "infoboxwidth"]

    /// True when cards are shown as linear Next / Back pages
    var isWizardMode: Bool {
        return isCardsMode && style == .wizard
    }

    /// True when cards are shown as a sidebar navigation view
    var isNavigationStyle: Bool {
        return isCardsMode && style == .navigation
    }

    /// Accumulated user input from all cards
    /// Key: card index, Value: dictionary of field name to value
    @Published var accumulatedInput: [Int: [String: Any]] = [:]

    /// Global configuration from JSON (properties outside the cards array)
    /// These serve as defaults that can be overridden by individual cards
    var globalConfiguration: JSON = JSON()

    /// Lookup from card id to array index for branch/nextpage resolution.
    private var idToIndex: [Int: Int] = [:]

    /// Indices of cards visited in the order they were entered. Back navigation pops this.
    private var navigationHistory: [Int] = []

    /// Returns the current card, if any
    var currentCard: DialogCard? {
        guard isCardsMode, currentCardIndex >= 0, currentCardIndex < cards.count else {
            return nil
        }
        return cards[currentCardIndex]
    }

    /// Returns true if there are more cards after the current one
    var hasNextCard: Bool {
        guard isCardsMode else { return false }
        if let current = currentCard, current.isFinal { return false }
        return currentCardIndex < cards.count - 1
    }

    /// Returns true if there are cards before the current one
    var hasPreviousCard: Bool {
        return isCardsMode && !navigationHistory.isEmpty
    }

    /// Returns true if on the last card
    var isLastCard: Bool {
        guard isCardsMode else { return false }
        if let current = currentCard, current.isFinal { return true }
        return currentCardIndex == cards.count - 1
    }

    /// Returns true if on the first card (no back history)
    var isFirstCard: Bool {
        return navigationHistory.isEmpty
    }

    /// Total number of cards
    var totalCards: Int {
        return cards.count
    }

    /// Load cards from JSON
    /// - Parameter json: The JSON object that may contain a "cards" array
    /// - Returns: True if cards were loaded, false if no cards found (normal mode)
    func loadCards(from json: JSON) -> Bool {
        // Check if "cards" key exists and is an array
        var blocktype: String = ""

        for cardBlock in appDefaults.cardTypes {
            if json[cardBlock].exists() && json[cardBlock].type == .array {
                blocktype = cardBlock
                break
            }
        }

        guard json[blocktype].exists(), json[blocktype].type == .array else {
            isCardsMode = false
            cards = []
            globalConfiguration = JSON()
            idToIndex = [:]
            navigationHistory = []
            style = .wizard
            pageIssues = [:]
            visitedPages = []
            return false
        }

        let cardsArray = json[blocktype].arrayValue

        // If no cards or empty array, operate normally
        guard !cardsArray.isEmpty else {
            isCardsMode = false
            cards = []
            globalConfiguration = JSON()
            idToIndex = [:]
            navigationHistory = []
            style = .wizard
            pageIssues = [:]
            visitedPages = []
            return false
        }

        // Extract global configuration (everything except the "cards" array)
        // These properties serve as defaults for all cards
        var globalJSON = json
        globalJSON.dictionaryObject?.removeValue(forKey: blocktype)
        globalConfiguration = globalJSON

        if !globalConfiguration.isEmpty {
            writeLog("Cards mode: loaded global configuration with \(globalConfiguration.dictionaryObject?.count ?? 0) properties")
        }

        // Presentation style - defaults to the linear wizard
        let styleValue = json["cardstyle"].stringValue.lowercased()
        style = CardStyle(rawValue: styleValue) ?? .wizard
        if !styleValue.isEmpty && CardStyle(rawValue: styleValue) == nil {
            writeLog("Unknown cardstyle '\(styleValue)' - using wizard", logLevel: .error)
        }

        // A sidebar needs more room than the standard dialog default
        if style == .navigation {
            if !globalConfiguration["width"].exists() { globalConfiguration["width"] = JSON(900) }
            if !globalConfiguration["height"].exists() { globalConfiguration["height"] = JSON(600) }
            for key in ["infobox", "infoboxwidth"] where globalConfiguration[key].exists() {
                globalConfiguration.dictionaryObject?.removeValue(forKey: key)
                writeLog("Navigation style: ignoring '\(key)' - not available with a navigation sidebar", logLevel: .error)
            }
        }

        // Parse cards with explicit id or inferred order
        var loadedCards: [DialogCard] = []

        for (index, cardJSON) in cardsArray.enumerated() {
            // Use explicit "id" if provided, otherwise use array position
            let cardId = cardJSON["id"].int ?? index
            var configuration = cardJSON
            if style == .navigation {
                configuration = stripNavigationKeys(from: cardJSON, cardIndex: index)
            }
            loadedCards.append(DialogCard(id: cardId, configuration: configuration))
        }

        // Sort cards by id for explicit ordering
        loadedCards.sort { $0.id < $1.id }

        cards = loadedCards
        currentCardIndex = 0
        isCardsMode = true
        accumulatedInput = [:]
        navigationHistory = []

        // Build id → index lookup and report duplicates.
        idToIndex = [:]
        for (index, card) in cards.enumerated() {
            if idToIndex[card.id] != nil {
                writeLog("Workflow validation: duplicate card id \(card.id) - only the first occurrence is reachable by id")
            } else {
                idToIndex[card.id] = index
            }
        }

        // Report references to ids that do not exist so authors can spot typos in their logs.
        for card in cards {
            if let target = card.nextPageOverride, idToIndex[target] == nil {
                writeLog("Workflow validation: card id \(card.id) nextpage references missing id \(target)")
            }
            if let branchJSON = card.branch {
                if let map = branchJSON["map"].dictionary {
                    for (_, value) in map {
                        if let target = value.int, idToIndex[target] == nil {
                            writeLog("Workflow validation: card id \(card.id) branch.map references missing id \(target)")
                        }
                    }
                }
                if let target = branchJSON["default"].int, idToIndex[target] == nil {
                    writeLog("Workflow validation: card id \(card.id) branch.default references missing id \(target)")
                }
                if let target = branchJSON["ifTrue"].int, idToIndex[target] == nil {
                    writeLog("Workflow validation: card id \(card.id) branch.ifTrue references missing id \(target)")
                }
                if let target = branchJSON["ifFalse"].int, idToIndex[target] == nil {
                    writeLog("Workflow validation: card id \(card.id) branch.ifFalse references missing id \(target)")
                }
            }
        }

        // Pages with required fields start incomplete so Done can't succeed without visiting them
        pageIssues = [:]
        visitedPages = []
        if style == .navigation {
            for (index, card) in cards.enumerated() where Self.hasRequiredFields(getMergedConfiguration(for: card)) {
                pageIssues[index] = "Required fields have not been completed".localized
            }
        }

        writeLog("Block mode activated using keyword '\(blocktype)' (\(style.rawValue) style): loaded \(cards.count) cards")
        return true
    }

    /// Remove keys a navigation page is not allowed to set, logging each one so authors can see why.
    private func stripNavigationKeys(from cardJSON: JSON, cardIndex: Int) -> JSON {
        var configuration = cardJSON
        for key in Self.navigationTopLevelOnlyKeys where configuration[key].exists() {
            configuration.dictionaryObject?.removeValue(forKey: key)
            writeLog("Navigation style: ignoring '\(key)' on card \(cardIndex) - set it at the top level instead", logLevel: .error)
        }
        for key in Self.navigationIgnoredKeys where configuration[key].exists() {
            configuration.dictionaryObject?.removeValue(forKey: key)
            writeLog("Navigation style: ignoring '\(key)' on card \(cardIndex) - not available with a navigation sidebar", logLevel: .error)
        }
        return configuration
    }

    /// True if the configuration contains any text field or select item marked as required.
    static func hasRequiredFields(_ configuration: JSON) -> Bool {
        for key in ["textfield", "selectitems"] {
            // A field that can be disabled or hidden might not be required in the end, so it doesn't count
            for field in configuration[key].arrayValue where field["required"].boolValue
                && field["enabledif"].stringValue.isEmpty && field["visibleif"].stringValue.isEmpty {
                return true
            }
        }
        return false
    }

    /// Navigation style: sidebar sections built from runs of consecutive cards sharing a `section` value.
    var sections: [CardSection] {
        var result: [CardSection] = []
        var currentTitle: String?
        var currentIndices: [Int] = []

        for (index, card) in cards.enumerated() {
            if index > 0 && card.section != currentTitle {
                result.append(CardSection(id: "section-\(result.count)", title: currentTitle, cardIndices: currentIndices))
                currentIndices = []
            }
            currentTitle = card.section
            currentIndices.append(index)
        }
        if !currentIndices.isEmpty {
            result.append(CardSection(id: "section-\(result.count)", title: currentTitle, cardIndices: currentIndices))
        }
        return result
    }

    /// Navigation style: open any card directly. No history is kept - the sidebar replaces Back.
    /// - Returns: True if the selection changed.
    func select(index: Int) -> Bool {
        guard isNavigationStyle, cards.indices.contains(index), index != currentCardIndex else { return false }
        currentCardIndex = index
        writeLog("Selected card id \(cards[index].id) (index \(index + 1) of \(totalCards))")
        return true
    }

    /// Get the merged configuration for a card (global defaults + card overrides)
    /// - Parameter card: The card to get merged configuration for
    /// - Returns: JSON with global properties merged with card-specific properties
    func getMergedConfiguration(for card: DialogCard) -> JSON {
        var merged = globalConfiguration

        // Card properties override global properties
        if let cardDict = card.configuration.dictionaryObject {
            for (key, value) in cardDict {
                merged[key] = JSON(value)
            }
        }

        return merged
    }

    /// Resolve the index of the next card given the current card's user input.
    /// Resolution precedence: branch → nextpage → sequential. Returns nil to end the workflow.
    private func resolveNextIndex(using input: [String: Any]) -> Int? {
        guard let card = currentCard else { return nil }
        if card.isFinal { return nil }

        // 1. Branch (field-driven routing)
        if let branchJSON = card.branch, let fieldName = branchJSON["field"].string {
            let rawValue = input[fieldName]

            // Normalise the input to comparable forms.
            var resolvedKey: String?
            var resolvedBool: Bool?
            if let boolValue = rawValue as? Bool {
                resolvedBool = boolValue
                resolvedKey = boolValue ? "true" : "false"
            } else if let stringValue = rawValue as? String {
                resolvedKey = stringValue
            } else if let dictValue = rawValue as? [String: Any],
                      let selectedValue = dictValue["selectedValue"] as? String {
                resolvedKey = selectedValue
            }

            // Checkbox shorthand
            if let boolValue = resolvedBool {
                if boolValue, let target = branchJSON["ifTrue"].int, let index = idToIndex[target] {
                    return index
                }
                if !boolValue, let target = branchJSON["ifFalse"].int, let index = idToIndex[target] {
                    return index
                }
            }

            // Map lookup
            if let key = resolvedKey, let target = branchJSON["map"][key].int, let index = idToIndex[target] {
                return index
            }

            // Branch-local fallback
            if let target = branchJSON["default"].int, let index = idToIndex[target] {
                return index
            }
        }

        // 2. Static nextpage override
        if let target = card.nextPageOverride, let index = idToIndex[target] {
            return index
        }

        // 3. Sequential next in array
        let nextIndex = currentCardIndex + 1
        return nextIndex < cards.count ? nextIndex : nil
    }

    /// Advance to the next card, resolving any branch or nextpage logic against the current input.
    /// - Parameter input: The current card's collected input (used for branching).
    /// - Returns: True if advanced, false if no next card (workflow should terminate).
    func advance(using input: [String: Any]) -> Bool {
        guard isCardsMode else { return false }
        guard let nextIndex = resolveNextIndex(using: input) else { return false }
        navigationHistory.append(currentCardIndex)
        currentCardIndex = nextIndex
        writeLog("Advanced to card id \(cards[currentCardIndex].id) (index \(currentCardIndex + 1) of \(totalCards))")
        return true
    }

    /// Move back to the previously visited card by popping the navigation history.
    /// - Returns: True if moved, false if there is no history.
    func back() -> Bool {
        guard let previousIndex = navigationHistory.popLast() else { return false }
        currentCardIndex = previousIndex
        writeLog("Returned to card id \(cards[currentCardIndex].id) (index \(currentCardIndex + 1) of \(totalCards))")
        return true
    }

    /// Store the current card's user input before transitioning
    /// - Parameter input: Dictionary of field names to values
    func storeCurrentCardInput(_ input: [String: Any]) {
        accumulatedInput[currentCardIndex] = input
        writeLog("Stored input for card \(currentCardIndex + 1)")
    }

    /// Get all accumulated input as a flat dictionary
    /// Later cards override earlier cards if same key exists
    func getAllAccumulatedInput() -> [String: Any] {
        var result: [String: Any] = [:]

        // Iterate through cards in order
        for cardIndex in 0..<totalCards {
            if let cardInput = accumulatedInput[cardIndex] {
                for (key, value) in cardInput {
                    result[key] = value
                }
            }
        }

        return result
    }

    /// Get accumulated input organized by card
    func getAccumulatedInputByCard() -> [[String: Any]] {
        var result: [[String: Any]] = []

        for cardIndex in 0..<totalCards {
            result.append(accumulatedInput[cardIndex] ?? [:])
        }

        return result
    }

    /// Get stored input for a specific card (for restoration when navigating back)
    /// - Parameter cardIndex: The card index to get input for
    /// - Returns: Dictionary of field names to values, or nil if no input stored
    func getStoredInput(for cardIndex: Int) -> [String: Any]? {
        return accumulatedInput[cardIndex]
    }

    /// Get accumulated input as string values for variable substitution.
    /// Wizard style only substitutes values from cards visited before the current one;
    /// navigation style has no ordering, so every other card with stored input is used.
    /// - Returns: Dictionary suitable for use with processTextString tags
    func getInputAsVariables() -> [String: String] {
        var result: [String: String] = [:]

        let sourceIndices = style == .navigation
            ? accumulatedInput.keys.sorted().filter { $0 != currentCardIndex }
            : navigationHistory

        for cardIndex in sourceIndices {
            if let cardInput = accumulatedInput[cardIndex] {
                for (key, value) in cardInput {
                    if let stringValue = value as? String {
                        result[key] = stringValue
                    } else if let boolValue = value as? Bool {
                        result[key] = boolValue ? "true" : "false"
                    } else if let dictValue = value as? [String: Any] {
                        if let selectedValue = dictValue["selectedValue"] as? String {
                            result[key] = selectedValue
                        }
                    } else {
                        result[key] = String(describing: value)
                    }
                }
            }
        }

        return result
    }

    /// Check if we have stored input for the current card (user navigated back)
    var hasStoredInputForCurrentCard: Bool {
        return accumulatedInput[currentCardIndex] != nil
    }

    /// Reset the card state
    func reset() {
        cards = []
        currentCardIndex = 0
        isCardsMode = false
        accumulatedInput = [:]
        globalConfiguration = JSON()
        idToIndex = [:]
        navigationHistory = []
        style = .wizard
        pageIssues = [:]
        visitedPages = []
    }
}

// MARK: - Global card state instance
var cardState = CardState()
