/**
 * Tests for the CardCollection class.
 */
module CardCollectionTest {
    package cardGame import cardGame;

    import cardGame.Card;
    import cardGame.CardCollection;

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
        Card card = new Card(0, 5);
        collection.addCard(card);
        assert collection.size() == 1 as "Size should be 1 after adding one card";
    }

    @Test
    void testAddMultipleCards() {
        CardCollection collection = new CardCollection("Test");
        for (Int i : 0..<5) {
            collection.addCard(new Card(i % 4, (i % 13) + 1));
        }
        assert collection.size() == 5 as "Collection should have 5 cards";
    }

    @Test
    void testPopCardRemovesCard() {
        CardCollection collection = new CardCollection("Test");
        Card card = new Card(1, 7);
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
        Card card1 = new Card(0, 1);
        Card card2 = new Card(1, 2);
        Card card3 = new Card(2, 3);
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
        collection.addCard(new Card(0, 1));
        assert !(collection.removeCard(5)) as "Remove with invalid index should return False";
    }

    @Test
    void testGetCard() {
        CardCollection collection = new CardCollection("Test");
        Card card = new Card(3, 10);
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
        collection.addCard(new Card(0, 1));
        assert !(collection.getCard(10)) as "GetCard with invalid index should return False";
    }

    @Test
    void testClear() {
        CardCollection collection = new CardCollection("Test");
        for (Int i : 0..<10) {
            collection.addCard(new Card(0, 1));
        }
        collection.clear();
        assert collection.isEmpty() as "Collection should be empty after clear";
        assert collection.size() == 0 as "Size should be 0 after clear";
    }

    @Test
    void testSwapCards() {
        CardCollection collection = new CardCollection("Test");
        Card card1 = new Card(0, 1);
        Card card2 = new Card(1, 2);
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
            source.addCard(new Card(0, 1));
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
            source.addCard(new Card(0, 1));
        }
        
        source.dealAll(destination);
        assert source.isEmpty() as "Source should be empty after dealing all";
        assert destination.size() == 5 as "Destination should have all 5 cards";
    }

    @Test
    void testShuffle() {
        CardCollection collection = new CardCollection("Test");
        for (Int i : 0..<52) {
            collection.addCard(new Card(i / 13, (i % 13) + 1));
        }
        
        // Store original order
        Int[] originalOrder = new Int[];
        for (Int i : 0..<52) {
            if (Card card := collection.getCard(i)) {
                originalOrder.add(card.suit * 13 + card.rank);
            }
        }
        
        // Shuffle
        collection.shuffle();
        
        // Verify all cards are still present
        assert collection.size() == 52 as "Collection should still have 52 cards after shuffle";
    }
}
