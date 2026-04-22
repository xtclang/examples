module ChessDBPieceTest {
    package db import chessDB.examples.org;

    import db.models.Color;
    import db.types.PieceType;
    import db.factory.PieceFactory;
    import db.base.Piece;
    import db.pieces.Pawn;
    import db.pieces.Knight;
    import db.pieces.Bishop;
    import db.pieces.Rook;
    import db.pieces.Queen;
    import db.pieces.King;

    /**
     * Tests for PieceType properties and PieceFactory product creation.
     */
    class PieceTypeAndFactoryTests {
        @Test
        void shouldExposePieceTypeProperties() {
            assert PieceType.Pawn.symbol == 'p';
            assert PieceType.Knight.value == 320;
            assert PieceType.Queen.isMajorPiece();
            assert PieceType.Bishop.isMinorPiece();
            assert PieceType.Rook.isSliding();
            assert PieceType.King.getChar(Color.White) == 'K';
        }

        @Test
        void shouldCreateAllPiecesFromFactory() {
            Piece pawn;
            Piece knight;
            Piece bishop;
            Piece rook;
            Piece queen;
            Piece king;

            if (Piece p := PieceFactory.createPiece('p', Color.White)) { pawn = p; } else { assert False; }
            if (Piece n := PieceFactory.createPiece('n', Color.Black)) { knight = n; } else { assert False; }
            if (Piece b := PieceFactory.createPiece('b', Color.White)) { bishop = b; } else { assert False; }
            if (Piece r := PieceFactory.createPiece('r', Color.Black)) { rook = r; } else { assert False; }
            if (Piece q := PieceFactory.createPiece('q', Color.White)) { queen = q; } else { assert False; }
            if (Piece k := PieceFactory.createPiece('k', Color.Black)) { king = k; } else { assert False; }

            assert pawn.getChar() == 'p';
            assert knight.getChar() == 'N';
            assert bishop.getChar() == 'b';
            assert rook.getChar() == 'R';
            assert queen.getChar() == 'q';
            assert king.getChar() == 'K';
        }

        @Test
        void shouldRecognizePieceTypes() {
            assert PieceFactory.isPieceType('Q', 'q');
            assert PieceFactory.isPieceType('q', 'q');
            assert !PieceFactory.isPieceType('R', 'q');
        }

        @Test
        void shouldCreateStandardSet() {
            assert PieceFactory.createStandardSet(Color.White).size == 16;
            assert PieceFactory.createStandardSet(Color.Black).size == 16;
        }

        @Test
        void shouldIdentifyMajorAndMinorPieces() {
            assert PieceType.Queen.isMajorPiece();
            assert PieceType.Rook.isMajorPiece();
            assert !PieceType.Bishop.isMajorPiece();
            assert !PieceType.Knight.isMajorPiece();
            assert !PieceType.Pawn.isMajorPiece();

            assert PieceType.Bishop.isMinorPiece();
            assert PieceType.Knight.isMinorPiece();
            assert !PieceType.Queen.isMinorPiece();
            assert !PieceType.Rook.isMinorPiece();
        }

        @Test
        void shouldIdentifySlidingPieces() {
            assert PieceType.Rook.isSliding();
            assert PieceType.Bishop.isSliding();
            assert PieceType.Queen.isSliding();
            assert !PieceType.Knight.isSliding();
            assert !PieceType.King.isSliding();
            assert !PieceType.Pawn.isSliding();
        }

        @Test
        void shouldReturnCorrectCharForBothColors() {
            assert PieceType.Pawn.getChar(Color.White) == 'P';
            assert PieceType.Pawn.getChar(Color.Black) == 'p';
            assert PieceType.King.getChar(Color.White) == 'K';
            assert PieceType.King.getChar(Color.Black) == 'k';
            assert PieceType.Queen.getChar(Color.White) == 'Q';
            assert PieceType.Queen.getChar(Color.Black) == 'q';
        }
    }
}
