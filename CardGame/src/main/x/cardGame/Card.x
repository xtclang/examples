class Card (Int suit, Int rank) {

    static String[] SUITS = ["Hearts", "Diamonds", "Clubs", "Spades"];
    static String[] RANKS = ["null", "Ace", "2", "3", "4", "5", "6", "7",
                             "8", "9", "10", "Jack", "Queen", "King"];

    @Override
    String toString() {
        return RANKS[rank] + " of " + SUITS[suit];
    }
}
