@Abstract
const Piece{

    Color color;
    protected Char char;
    protected Int centipawns;
    @Lazy public Boolean isQueen.calc() = False;
    @Lazy public Boolean isBishop.calc() = False;
    @Lazy public Boolean isRook.calc() = False;
    @Lazy public Boolean isKnight.calc() = False;
    @Lazy public Boolean isKing.calc() = False;
    @Lazy public Boolean isPawn.calc() = False;

    public Char getChar() { return this.char; }

    public Int getCentiPawns() {return this.centipawns;}

  construct (Color color, Char char, Int centipawns) {
        this.color = color;
        this.char = color == White ? char.lowercase : char.uppercase;
        this.centipawns = centipawns;

   }
}
