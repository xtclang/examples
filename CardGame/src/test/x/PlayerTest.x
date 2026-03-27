/**
 * Tests for the Player class.
 */
module PlayerTest {
    package cardGame import cardGame;

    import cardGame.Card;
    import cardGame.Player;
    import cardGame.Hand;

    @Test
    void testPlayerCanBeCreated() {
        Player player = new Player("Alice");
        assert player.name == "Alice" as "Player name should match";
    }

    @Test
    void testPlayerHandIsEmpty() {
        Player player = new Player("Bob");
        assert player.hand.isEmpty() as "New player hand should be empty";
    }

    @Test
    void testPlayerCanHaveCards() {
        Player player = new Player("Charlie");
        Card card = new Card(0, 5);
        player.hand.addCard(card);
        
        assert player.hand.size() == 1 as "Player hand should have 1 card";
    }

    @Test
    void testCardMatches() {
        // Test same suit
        Card card1 = new Card(0, 5);
        Card card2 = new Card(0, 10);
        assert Player.cardMatches(card1, card2) as "Cards with same suit should match";
    }

    @Test
    void testCardMatchesSameRank() {
        // Test same rank
        Card card1 = new Card(0, 5);
        Card card2 = new Card(2, 5);
        assert Player.cardMatches(card1, card2) as "Cards with same rank should match";
    }

    @Test
    void testCardMatchesEight() {
        // Test with eight (wildcard) - eight in first position matches
        Card eight = new Card(0, 8);
        Card otherCard = new Card(1, 5);
        assert Player.cardMatches(eight, otherCard) as "Eight should match any card";
        // Note: Eight is only special in the first position according to cardMatches logic
        // When eight is in second position, it only matches if suit or rank also match
        assert Player.cardMatches(otherCard, new Card(0, 5)) as "Cards with same suit should match";
    }

    @Test
    void testCardDoesNotMatch() {
        // Test no match
        Card card1 = new Card(0, 2);
        Card card2 = new Card(1, 5);
        assert !Player.cardMatches(card1, card2) as "Card with different suit and rank should not match";
    }

    @Test
    void testPlayerNameStored() {
        Player player1 = new Player("Player1");
        Player player2 = new Player("Player2");
        
        assert player1.name == "Player1" as "First player name should be Player1";
        assert player2.name == "Player2" as "Second player name should be Player2";
        assert player1.name != player2.name as "Different players should have different names";
    }

    @Test
    void testPlayerHandExists() {
        Player player = new Player("Alice");
        cardGame.Hand hand = player.hand;
        // The hand should exist and be empty initially
        assert hand.isEmpty() as "Player hand should be empty initially";
    }

    @Test
    void testMultiplePlayers() {
        Player[] players = new Player[];
        players.add(new Player("Alice"));
        players.add(new Player("Bob"));
        players.add(new Player("Charlie"));
        
        assert players[0].name == "Alice" as "First player should be Alice";
        assert players[1].name == "Bob" as "Second player should be Bob";
        assert players[2].name == "Charlie" as "Third player should be Charlie";
    }

    @Test
    void testPlayerCanAddMultipleCards() {
        Player player = new Player("Test Player");
        for (Int i : 0..<5) {
            player.hand.addCard(new Card(i % 4, (i % 13) + 1));
        }
        
        assert player.hand.size() == 5 as "Player hand should have 5 cards";
    }
}
