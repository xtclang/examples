const Pawn extends Piece{

    @Override @Lazy public Boolean isPawn.calc() = True;

        construct (Color color) {
            construct Piece(color, 'p', 100);
       }
}