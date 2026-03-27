/**
 * Tests for the Hand class.
 */
module HandTest {
    package cardGame import cardGame;

    import cardGame.Card;
    import cardGame.Hand;

    @Test
    void testHandCanBeCreated() {
        Hand hand = new Hand("Test Hand");
        assert hand.size() == 0 as "New hand should be empty";
    }

    @Test
    void testHandCanAddCards() {
        Hand hand = new Hand("Test Hand");
        Card card1 = new Card(0, 5);
        Card card2 = new Card(1, 10);
        
        hand.addCard(card1);
        hand.addCard(card2);
        
        assert hand.size() == 2 as "Hand should have 2 cards after adding 2";
    }

    @Test
    void testHandCanPopCards() {
        Hand hand = new Hand("Test Hand");
        Card card = new Card(2, 7);
        hand.addCard(card);
        
        if (Card popped := hand.popCard()) {
            assert popped == card as "Popped card should match added card";
            assert hand.isEmpty() as "Hand should be empty after pop";
        } else {
            assert False as "Pop should succeed";
        }
    }

    @Test
    void testHandCanRemoveCards() {
        Hand hand = new Hand("Test Hand");
        Card card1 = new Card(0, 1);
        Card card2 = new Card(1, 2);
        Card card3 = new Card(2, 3);
        
        hand.addCard(card1);
        hand.addCard(card2);
        hand.addCard(card3);
        
        if (Card removed := hand.removeCard(1)) {
            assert removed == card2 as "Removed card should be card2";
            assert hand.size() == 2 as "Hand should have 2 cards";
        } else {
            assert False as "Remove should succeed";
        }
    }

    @Test
    void testHandCanBeCleared() {
        Hand hand = new Hand("Test Hand");
        for (Int i : 0..<5) {
            hand.addCard(new Card(0, 1));
        }
        
        hand.clear();
        assert hand.isEmpty() as "Hand should be empty after clear";
    }

    @Test
    void testHandCanGetCard() {
        Hand hand = new Hand("Test Hand");
        Card card = new Card(3, 12);
        hand.addCard(card);
        
        if (Card retrieved := hand.getCard(0)) {
            assert retrieved == card as "Retrieved card should match";
        } else {
            assert False as "GetCard should succeed";
        }
    }

    @Test
    void testHandInheritsShuffle() {
        Hand hand = new Hand("Test Hand");
        for (Int i : 0..<10) {
            hand.addCard(new Card(i / 4, (i % 13) + 1));
        }
        
        hand.shuffle();
        assert hand.size() == 10 as "Hand should still have 10 cards after shuffle";
    }
}
