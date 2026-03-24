class Deck extends CardCollection {
    construct(String label) {
        construct CardCollection(label);
    } finally {
        for (Int suit : 0..<4 ) {
            for (Int rank : 1..13) {
                addCard(new Card(suit, rank));
            }
        }
    }
}
