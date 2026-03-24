class Player {
    public String name;
    public Hand   hand;

    construct(String name) {
        this.name = name;
        this.hand = new Hand(name + " Hand");
    }

    conditional Card play(Eights eights, Card? prev) {
        if (Card card := searchForMatch(prev)) {
            return True, card;
        }
        return drawForMatch(eights, prev);
    }

    conditional Card searchForMatch(Card? prev) {
        if (prev == Null) {
            return hand.popCard();
        }
        for (Int i : 0 ..< hand.size()) {
            if (Card card := hand.getCard(i)) {
                if (cardMatches(card, prev)) {
                    return hand.removeCard(i);
                }
            }
        }
        return False;
    }

    conditional Card drawForMatch(Eights eights, Card? prev) {
        @Inject Console console;
        while (True) {
            if (Card card := eights.drawCard()) {
                console.print($"{name} draws {card}");
                if (prev == Null || cardMatches(card, prev)) {
                    return True, card;
                }
                hand.addCard(card);
            } else {
                return False;
            }
        }
    }

    static Boolean cardMatches(Card card1, Card card2) {
        return card1.suit == card2.suit
            || card1.rank == card2.rank
            || card1.rank == 8;
    }
}
