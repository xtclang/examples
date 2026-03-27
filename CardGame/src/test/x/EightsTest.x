module EightsTest {
    package cardGame import cardGame;

    import cardGame.Card;
    import cardGame.Eights;
    import cardGame.Player;
    import cardGame.Hand;

    @Test
    void testInitialHandSizes() {
        Eights game = new Eights("Alice", "Bob");
        assert game.one.hand.size() == 5 as "Player one should have 5 cards";
        assert game.two.hand.size() == 5 as "Player two should have 5 cards";
    }

    @Test
    void testInitialDiscardPileHasOneCard() {
        Eights game = new Eights("Alice", "Bob");
        assert game.discardPile.size() == 1 as "Discard pile should start with 1 card";
    }

    @Test
    void testInitialDrawPileSize() {
        Eights game = new Eights("Alice", "Bob");
        // 52 cards - 5 - 5 - 1 (discard) = 41
        assert game.drawPile.size() == 41 as "Draw pile should have 41 cards";
    }

    @Test
    void testIsDoneWhenHandEmpty() {
        Eights game = new Eights("Alice", "Bob");
        assert !game.isDone() as "Game should not be done at start";

        // Empty one player's hand
        while (!game.one.hand.isEmpty()) {
            game.one.hand.popCard();
        }
        assert game.isDone() as "Game should be done when a hand is empty";
    }

    @Test
    void testIsDoneReturnsFalseAtStart() {
        Eights game = new Eights("Alice", "Bob");
        assert !game.isDone() as "Game should not be done at start";
    }

    @Test
    void testNextPlayerRotation() {
        Eights game  = new Eights("Alice", "Bob");
        Player next  = game.nextPlayer(game.one);
        assert next == game.two as "Next player after one should be two";

        Player back = game.nextPlayer(game.two);
        assert back == game.one as "Next player after two should be one";
    }

    @Test
    void testDrawCardReducesDrawPile() {
        Eights game = new Eights("Alice", "Bob");
        Int before  = game.drawPile.size();
        if (Card card := game.drawCard()) {
            assert game.drawPile.size() == before - 1 as "Draw pile should shrink by 1";
        }
    }

    @Test
    void testReshuffleMovesDiscardToDrawPile() {
        Eights game = new Eights("Alice", "Bob");

        // Drain the draw pile
        while (!game.drawPile.isEmpty()) {
            game.drawPile.popCard();
        }

        // Add several cards to discard pile
        game.discardPile.addCard(new Card(0, 1));
        game.discardPile.addCard(new Card(0, 2));
        game.discardPile.addCard(new Card(0, 3));

        Int discardBefore = game.discardPile.size();
        game.reshuffle();

        // Discard should have only 1 card (the top), draw pile gets the rest
        assert game.discardPile.size() == 1       as "Discard pile should have 1 card after reshuffle";
        assert game.drawPile.size()    == discardBefore - 1 as "Draw pile should have gained cards";
    }

    @Test
    void testReshuffleDoesNothingWithOneCard() {
        Eights game = new Eights("Alice", "Bob");

        // Drain draw pile and set discard to exactly 1 card
        while (!game.drawPile.isEmpty()) {
            game.drawPile.popCard();
        }
        while (!game.discardPile.isEmpty()) {
            game.discardPile.popCard();
        }
        game.discardPile.addCard(new Card(0, 1));

        game.reshuffle();
        assert game.drawPile.isEmpty()         as "Draw pile should still be empty";
        assert game.discardPile.size() == 1    as "Discard pile should still have 1 card";
    }

    @Test
    void testDrawCardTriggersReshuffleWhenEmpty() {
        Eights game = new Eights("Alice", "Bob");

        // Drain the draw pile
        while (!game.drawPile.isEmpty()) {
            game.drawPile.popCard();
        }

        // Add cards to discard so reshuffle has something to work with
        game.discardPile.addCard(new Card(1, 5));
        game.discardPile.addCard(new Card(2, 7));

        // drawCard should trigger reshuffle and still return a card
        if (Card card := game.drawCard()) {
            assert True as "Should have drawn a card after reshuffle";
        } else {
            assert False as "drawCard should not return False after reshuffle with cards available";
        }
    }

    @Test
    void testPlayerNamesSetCorrectly() {
        Eights game = new Eights("Alice", "Bob");
        assert game.one.name == "Alice" as "Player one name should be Alice";
        assert game.two.name == "Bob"   as "Player two name should be Bob";
    }
}