module CardTest {
    package cardGame import cardGame;

    import cardGame.Card;

    @Test
    void testToStringAceOfHearts() {
        Card card = new Card(0, 1);
        assert card.toString() == "Ace of Hearts" as "Expected 'Ace of Hearts'";
    }

    @Test
    void testToStringKingOfSpades() {
        Card card = new Card(3, 13);
        assert card.toString() == "King of Spades" as "Expected 'King of Spades'";
    }

    @Test
    void testToStringEightOfClubs() {
        Card card = new Card(2, 8);
        assert card.toString() == "8 of Clubs" as "Expected '8 of Clubs'";
    }

    @Test
    void testToStringTwoOfDiamonds() {
        Card card = new Card(1, 2);
        assert card.toString() == "2 of Diamonds" as "Expected '2 of Diamonds'";
    }

    @Test
    void testSuitStoredCorrectly() {
        Card card = new Card(2, 5);
        assert card.suit == 2 as "Suit should be 2 (Clubs)";
    }

    @Test
    void testRankStoredCorrectly() {
        Card card = new Card(2, 5);
        assert card.rank == 5 as "Rank should be 5";
    }

    @Test
    void testAllSuits() {
        String[] expectedSuits = ["Hearts", "Diamonds", "Clubs", "Spades"];
        for (Int s : 0 ..< 4) {
            Card card = new Card(s, 1);
            assert card.toString() == $"Ace of {expectedSuits[s]}"
                as $"Expected 'Ace of {expectedSuits[s]}'";
        }
    }

    @Test
    void testAllRanks() {
        String[] expectedRanks = ["null", "Ace", "2", "3", "4", "5", "6", "7",
                                  "8", "9", "10", "Jack", "Queen", "King"];
        for (Int r : 1 ..< 14) {
            Card card = new Card(0, r);
            assert card.toString() == $"{expectedRanks[r]} of Hearts"
                as $"Expected '{expectedRanks[r]} of Hearts'";
        }
    }

    @Test
    void testTwoCardsWithSameSuitAndRankAreEqual() {
        Card card1 = new Card(1, 7);
        Card card2 = new Card(1, 7);
        assert card1.equals(card2) as "Two cards with same suit and rank should be equal";
    }

    @Test
    void testTwoCardsWithDifferentSuitAreNotEqual() {
        Card card1 = new Card(0, 7);
        Card card2 = new Card(1, 7);
        assert card1 != card2 as "Cards with different suits should not be equal";
    }

    @Test
    void testTwoCardsWithDifferentRankAreNotEqual() {
        Card card1 = new Card(0, 7);
        Card card2 = new Card(0, 8);
        assert card1 != card2 as "Cards with different ranks should not be equal";
    }
}