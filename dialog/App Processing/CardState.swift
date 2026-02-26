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
            return false
        }
        
        let cardsArray = json["cards"].arrayValue
        
        // If no cards or empty array, operate normally
        guard !cardsArray.isEmpty else {
            isCardsMode = false
            cards = []
            return false
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
    
    /// Reset the card state
    func reset() {
        cards = []
        currentCardIndex = 0
        isCardsMode = false
        accumulatedInput = [:]
    }
}

// MARK: - Global card state instance
var cardState = CardState()
