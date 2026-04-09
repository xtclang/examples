class Eights {
    public Player one;
    public Player two;
    public Hand   drawPile;
    public Hand   discardPile;

    construct(String name1, String name2) {
        this.one         = new Player(name1);
        this.two         = new Player(name2);
        this.drawPile    = new Hand(GameConstants.DRAW_PILE_NAME);
        this.discardPile = new Hand(GameConstants.DISCARD_PILE_NAME);
    } finally {
        initializeGame();
    }

    private void initializeGame() {
        Deck deck = new Deck(GameConstants.DECK_NAME);
        deck.shuffle();
        deck.deal(one.hand, GameConstants.INITIAL_HAND_SIZE);
        deck.deal(two.hand, GameConstants.INITIAL_HAND_SIZE);
        deck.dealAll(drawPile);
        if (Card card := drawCard()) {
            discardPile.addCard(card);
        }
    }

    Boolean isDone() {
        return one.hand.isEmpty() || two.hand.isEmpty();
    }

    void reshuffle() {
        if (discardPile.size() <= GameConstants.MIN_DISCARD_PILE_FOR_RESHUFFLE) {
            return;
        }
        if (Card top := discardPile.popCard()) {
            discardPile.dealAll(drawPile);
            discardPile.addCard(top);
            drawPile.shuffle();
        }
    }

    conditional Card drawCard() {
        if (drawPile.isEmpty()) {
            reshuffle();
        }
        return drawPile.popCard();
    }

    Player nextPlayer(Player current) {
        return current == one ? two : one;
    }

    void displayState() {
        @Inject Console console;
        console.print(GameConstants.DISPLAY_SEPARATOR);
        if (Card top := discardPile.getCard(discardPile.size() - 1)) {
            console.print($"Top of discard: {top}");
        }
        console.print($"{one.name} hand size: {one.hand.size()}");
        console.print($"{two.name} hand size: {two.hand.size()}");
        console.print($"Draw pile size: {drawPile.size()}");
        console.print("Press Enter for next turn...");
        console.readLine();
    }

    void takeTurn(Player player) {
        @Inject Console console;
        if (Card prev := discardPile.getCard(discardPile.size() - 1)) {
            if (Card card := player.play(this, prev)) {
                console.print($"{player.name} plays {card}");
                discardPile.addCard(card);
            } else {
                console.print($"{player.name} cannot play and passes.");
            }
        }
    }

    void playGame() {
        @Inject Console console;
        Player current = one;
        while (!isDone()) {
            displayState();
            takeTurn(current);
            current = nextPlayer(current);
        }
        console.print(GameConstants.DISPLAY_SEPARATOR);
        if (one.hand.isEmpty()) {
            console.print($"{one.name} wins!");
        } else {
            console.print($"{two.name} wins!");
        }
    }
}
