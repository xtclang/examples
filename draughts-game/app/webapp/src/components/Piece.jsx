/** The crown on a king: a gold band with five points, outlined so it reads on both colours. */
export function Crown() {
  return (
    <svg className="crown" viewBox="0 0 32 28" aria-hidden="true">
      <path
        d="M3 22 1.5 7.5 9.5 13 16 3l6.5 10 8-5.5L29 22z"
        fill="#f4c542"
        stroke="#7a5608"
        strokeWidth="1.6"
        strokeLinejoin="round"
      />
      <rect x="3" y="22.5" width="26" height="4" rx="1.6" fill="#e0a82a" stroke="#7a5608" strokeWidth="1.6" />
      <circle cx="1.8" cy="7.2" r="2" fill="#fff3b8" stroke="#7a5608" strokeWidth="1.2" />
      <circle cx="16" cy="3.2" r="2" fill="#fff3b8" stroke="#7a5608" strokeWidth="1.2" />
      <circle cx="30.2" cy="7.2" r="2" fill="#fff3b8" stroke="#7a5608" strokeWidth="1.2" />
    </svg>
  );
}

/** A piece as it sits on the board: 'b' (black) or 'w' (white), a man or a king. */
export function Piece({ color, king = false }) {
  return <span className={`piece ${color}${king ? ' king' : ''}`}>{king && <Crown />}</span>;
}

/**
 * The same piece, drawn anywhere on the page at a given size -- in the header, the dialogs and
 * beside a player's name -- so the pieces on the page are the pieces on the board.
 */
export function PieceIcon({ color, king = false, size = 28 }) {
  return (
    <span className="piece-icon" style={{ '--size': `${size}px` }} aria-hidden="true">
      <Piece color={color} king={king} />
    </span>
  );
}

/** A black and a white piece side by side. */
export function PiecePair({ size = 28 }) {
  return (
    <span className="piece-pair" aria-hidden="true">
      <PieceIcon color="b" size={size} />
      <PieceIcon color="w" size={size} />
    </span>
  );
}
