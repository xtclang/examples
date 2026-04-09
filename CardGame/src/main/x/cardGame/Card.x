const Card(Suit suit, Rank rank) {
    @Override
    String toString() {
        return $"{rank} of {suit}";
    }
}
