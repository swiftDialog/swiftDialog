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
}

/// Manages the state of a multi-card dialog workflow
class CardState: ObservableObject {

    /// All cards loaded from JSON configuration
    @Published var cards: [DialogCard] = []

    /// Current card index (0-based)
    @Published var currentCardIndex: Int = 0

    /// Whether cards mode is active
    @Published var isCardsMode: Bool = false

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

        // Parse cards with explicit id or inferred order
        var loadedCards: [DialogCard] = []

        for (index, cardJSON) in cardsArray.enumerated() {
            // Use explicit "id" if provided, otherwise use array position
            let cardId = cardJSON["id"].int ?? index
            loadedCards.append(DialogCard(id: cardId, configuration: cardJSON))
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

        writeLog("Block mode activated using keyword '\(blocktype)': loaded \(cards.count) cards")
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
            var resolvedKey: String? = nil
            var resolvedBool: Bool? = nil
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
    /// Only substitutes values from cards actually visited before the current one.
    /// - Returns: Dictionary suitable for use with processTextString tags
    func getInputAsVariables() -> [String: String] {
        var result: [String: String] = [:]

        for cardIndex in navigationHistory {
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
    }
}

// MARK: - Global card state instance
var cardState = CardState()
