/**
 * Tests for the Deck class.
 */
module DeckTest {
    package cardGame import cardGame;

    import cardGame.Card;
    import cardGame.Deck;
    import cardGame.Suit;
    import cardGame.Rank;

    @Test
    void testDeckHas52Cards() {
        Deck deck = new Deck("Standard Deck");
        assert deck.size() == 52 as "Deck should have 52 cards";
    }

    @Test
    void testDeckCanPopCard() {
        Deck deck = new Deck("Standard Deck");
        if (Card card := deck.popCard()) {
            assert deck.size() == 51 as "Deck should have 51 cards after pop";
        } else {
            assert False as "Pop should succeed on full deck";
        }
    }

    @Test
    void testDeckCanBeShuffled() {
        Deck deck = new Deck("Standard Deck");
        deck.shuffle();
        assert deck.size() == 52 as "Deck should still have 52 cards after shuffle";
    }

    @Test
    void testDeckCanDealCards() {
        Deck deck = new Deck("Standard Deck");
        cardGame.Hand hand = new cardGame.Hand("Player Hand");
        
        deck.deal(hand, 5);
        assert deck.size() == 47 as "Deck should have 47 cards after dealing 5";
        assert hand.size() == 5 as "Hand should have 5 cards";
    }

    @Test
    void testDeckCanClear() {
        Deck deck = new Deck("Standard Deck");
        deck.clear();
        assert deck.isEmpty() as "Deck should be empty after clear";
    }

    @Test
    void testDeckHasAllSuits() {
        Deck deck = new Deck("Standard Deck");
        Boolean[] suitFound = new Boolean[4];
        for (Int i : 0..<4) {
            suitFound[i] = False;
        }
        
        for (Int i : 0..<52) {
            if (Card card := deck.getCard(i)) {
                suitFound[card.suit.ordinal] = True;
            }
        }
        
        assert suitFound[0] && suitFound[1] && suitFound[2] && suitFound[3] as
            "Deck should have cards from all 4 suits";
    }

    @Test
    void testDeckHasAllRanks() {
        Deck deck = new Deck("Standard Deck");
        Boolean[] rankFound = new Boolean[13];
        for (Int i : 0..<13) {
            rankFound[i] = False;
        }
        
        for (Int i : 0..<52) {
            if (Card card := deck.getCard(i)) {
                rankFound[card.rank.ordinal] = True;
            }
        }
        
        for (Int rank : 0..12) {
            assert rankFound[rank] as $"Deck should have cards with rank {rank}";
        }
    }

    @Test
    void testDeckPopAllCards() {
        Deck deck = new Deck("Standard Deck");
        Int count = 0;
        
        while (Card card := deck.popCard()) {
            count++;
        }
        
        assert count == 52 as "Should be able to pop all 52 cards";
        assert deck.isEmpty() as "Deck should be empty";
    }
}
