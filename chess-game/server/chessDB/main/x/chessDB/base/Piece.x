@Abstract
const Piece{

    Color color;
    protected Char char;
    protected Int centipawns;

    public Char getChar() { return this.char; }

    public Int getCentiPawns() {return this.centipawns;}

    construct (Color color, Char char, Int centipawns) {
        this.color = color;
        this.char = color == White ? char.lowercase : char.uppercase;
        this.centipawns = centipawns;

    }
}
