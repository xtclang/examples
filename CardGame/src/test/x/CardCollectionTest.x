/**
 * Tests for the CardCollection class.
 */
module CardCollectionTest {
    package cardGame import cardGame;

    import cardGame.Card;
    import cardGame.CardCollection;
    import cardGame.Suit;
    import cardGame.Rank;
    import cardGame.GameConstants;

    @Test
    void testEmptyCollectionHasZeroSize() {
        CardCollection collection = new CardCollection("Test");
        assert collection.size() == 0 as "New collection should have size 0";
    }

    @Test
    void testEmptyCollectionIsEmpty() {
        CardCollection collection = new CardCollection("Test");
        assert collection.isEmpty() as "New collection should be empty";
    }

    @Test
    void testAddCardIncreasesSize() {
        CardCollection collection = new CardCollection("Test");
        Card card = new Card(Suit.Hearts, Rank.Five);
        collection.addCard(card);
        assert collection.size() == 1 as "Size should be 1 after adding one card";
    }

    @Test
    void testAddMultipleCards() {
        CardCollection collection = new CardCollection("Test");
        Suit[] suits = Suit.values;
        Rank[] ranks = Rank.values;
        for (Int i : 0..<5) {
            collection.addCard(new Card(suits[i % 4], ranks[i % 13]));
        }
        assert collection.size() == 5 as "Collection should have 5 cards";
    }

    @Test
    void testPopCardRemovesCard() {
        CardCollection collection = new CardCollection("Test");
        Card card = new Card(Suit.Diamonds, Rank.Seven);
        collection.addCard(card);
        
        if (Card popped := collection.popCard()) {
            assert popped == card as "Popped card should match added card";
            assert collection.size() == 0 as "Size should be 0 after pop";
        } else {
            assert False as "Pop should succeed on non-empty collection";
        }
    }

    @Test
    void testPopCardFromEmptyReturnsFalse() {
        CardCollection collection = new CardCollection("Test");
        assert !(collection.popCard()) as "Pop on empty collection should return False";
    }

    @Test
    void testRemoveCardByIndex() {
        CardCollection collection = new CardCollection("Test");
        Card card1 = new Card(Suit.Hearts, Rank.Ace);
        Card card2 = new Card(Suit.Diamonds, Rank.Two);
        Card card3 = new Card(Suit.Clubs, Rank.Three);
        collection.addCard(card1);
        collection.addCard(card2);
        collection.addCard(card3);
        
        if (Card removed := collection.removeCard(1)) {
            assert removed == card2 as "Removed card should be the middle card";
            assert collection.size() == 2 as "Size should be 2 after removal";
        } else {
            assert False as "Remove should succeed with valid index";
        }
    }

    @Test
    void testRemoveCardInvalidIndexReturnsFalse() {
        CardCollection collection = new CardCollection("Test");
        collection.addCard(new Card(Suit.Hearts, Rank.Ace));
        assert !(collection.removeCard(5)) as "Remove with invalid index should return False";
    }

    @Test
    void testGetCard() {
        CardCollection collection = new CardCollection("Test");
        Card card = new Card(Suit.Spades, Rank.Ten);
        collection.addCard(card);
        
        if (Card retrieved := collection.getCard(0)) {
            assert retrieved == card as "Retrieved card should match";
        } else {
            assert False as "GetCard should succeed with valid index";
        }
    }

    @Test
    void testGetCardInvalidIndexReturnsFalse() {
        CardCollection collection = new CardCollection("Test");
        collection.addCard(new Card(Suit.Hearts, Rank.Ace));
        assert !(collection.getCard(10)) as "GetCard with invalid index should return False";
    }

    @Test
    void testClear() {
        CardCollection collection = new CardCollection("Test");
        for (Int i : 0..<10) {
            collection.addCard(new Card(Suit.Hearts, Rank.Ace));
        }
        collection.clear();
        assert collection.isEmpty() as "Collection should be empty after clear";
        assert collection.size() == 0 as "Size should be 0 after clear";
    }

    @Test
    void testSwapCards() {
        CardCollection collection = new CardCollection("Test");
        Card card1 = new Card(Suit.Hearts, Rank.Ace);
        Card card2 = new Card(Suit.Diamonds, Rank.Two);
        collection.addCard(card1);
        collection.addCard(card2);
        
        collection.swapCards(0, 1);
        if (Card first := collection.getCard(0)) {
            assert first == card2 as "First card should be card2 after swap";
        } else {
            assert False as "Should be able to get card at index 0";
        }
    }

    @Test
    void testDealCards() {
        CardCollection source = new CardCollection("Source");
        CardCollection destination = new CardCollection("Destination");
        
        for (Int i : 0..<5) {
            source.addCard(new Card(Suit.Hearts, Rank.Ace));
        }
        
        source.deal(destination, 3);
        assert source.size() == 2 as "Source should have 2 cards after dealing 3";
        assert destination.size() == 3 as "Destination should have 3 cards";
    }

    @Test
    void testDealAllCards() {
        CardCollection source = new CardCollection("Source");
        CardCollection destination = new CardCollection("Destination");
        
        for (Int i : 0..<5) {
            source.addCard(new Card(Suit.Hearts, Rank.Ace));
        }
        
        source.dealAll(destination);
        assert source.isEmpty() as "Source should be empty after dealing all";
        assert destination.size() == 5 as "Destination should have all 5 cards";
    }

    @Test
    void testShuffle() {
        CardCollection collection = new CardCollection("Test");
        Suit[] suits = Suit.values;
        Rank[] ranks = Rank.values;
        Int suitCount = suits.size;
        Int rankCount = ranks.size;
        Int expectedTotal = suitCount * rankCount;
        
        for (Int i : 0..<expectedTotal) {
            collection.addCard(new Card(suits[i / rankCount], ranks[i % rankCount]));
        }
        
        // Store original order
        Int[] originalOrder = new Int[];
        for (Int i : 0..<expectedTotal) {
            if (Card card := collection.getCard(i)) {
                originalOrder.add(card.suit.ordinal * rankCount + card.rank.ordinal);
            }
        }
        
        // Shuffle
        collection.shuffle();
        
        // Verify all cards are still present
        assert collection.size() == expectedTotal as "Collection should still have " + expectedTotal + " cards after shuffle";
    }
}
