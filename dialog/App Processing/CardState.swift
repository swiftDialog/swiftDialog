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
    
    /// Returns the current card, if any
    var currentCard: DialogCard? {
        guard isCardsMode, currentCardIndex >= 0, currentCardIndex < cards.count else {
            return nil
        }
        return cards[currentCardIndex]
    }
    
    /// Returns true if there are more cards after the current one
    var hasNextCard: Bool {
        return isCardsMode && currentCardIndex < cards.count - 1
    }
    
    /// Returns true if there are cards before the current one
    var hasPreviousCard: Bool {
        return isCardsMode && currentCardIndex > 0
    }
    
    /// Returns true if on the last card
    var isLastCard: Bool {
        return isCardsMode && currentCardIndex == cards.count - 1
    }
    
    /// Returns true if on the first card
    var isFirstCard: Bool {
        return currentCardIndex == 0
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
        guard json["cards"].exists(), json["cards"].type == .array else {
            isCardsMode = false
            cards = []
            globalConfiguration = JSON()
            return false
        }
        
        let cardsArray = json["cards"].arrayValue
        
        // If no cards or empty array, operate normally
        guard !cardsArray.isEmpty else {
            isCardsMode = false
            cards = []
            globalConfiguration = JSON()
            return false
        }
        
        // Extract global configuration (everything except the "cards" array)
        // These properties serve as defaults for all cards
        var globalJSON = json
        globalJSON.dictionaryObject?.removeValue(forKey: "cards")
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
        
        writeLog("Cards mode activated: loaded \(cards.count) cards")
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
    
    /// Move to the next card
    /// - Returns: True if moved to next card, false if already at last card
    func nextCard() -> Bool {
        guard hasNextCard else {
            return false
        }
        currentCardIndex += 1
        writeLog("Advanced to card \(currentCardIndex + 1) of \(totalCards)")
        return true
    }
    
    /// Move to the previous card
    /// - Returns: True if moved to previous card, false if already at first card
    func previousCard() -> Bool {
        guard hasPreviousCard else {
            return false
        }
        currentCardIndex -= 1
        writeLog("Moved back to card \(currentCardIndex + 1) of \(totalCards)")
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
    
    /// Get all accumulated input as string values for variable substitution
    /// This flattens complex values (like dropdown selections) to their string representation
    /// - Returns: Dictionary suitable for use with processTextString tags
    func getInputAsVariables() -> [String: String] {
        var result: [String: String] = [:]
        
        // Iterate through all cards up to (but not including) current card
        // This ensures we only substitute values from previous cards
        for cardIndex in 0..<currentCardIndex {
            if let cardInput = accumulatedInput[cardIndex] {
                for (key, value) in cardInput {
                    // Convert value to string for variable substitution
                    if let stringValue = value as? String {
                        result[key] = stringValue
                    } else if let boolValue = value as? Bool {
                        result[key] = boolValue ? "true" : "false"
                    } else if let dictValue = value as? [String: Any] {
                        // For dropdowns, use the selectedValue
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
    }
}

// MARK: - Global card state instance
var cardState = CardState()
