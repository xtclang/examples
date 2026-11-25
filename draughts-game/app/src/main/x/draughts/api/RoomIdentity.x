import db.models.RoomRecord;

/**
 * RoomIdentity - who is who in a room.
 *
 * Rooms have no accounts. Each player holds a private random id, handed out when they create or
 * join, and these helpers turn an id into a side and say whether it is that side's move.
 */
service RoomIdentity {
    /**
     * Characters for room codes: no I, O, 0 or 1, which are easily misread.
     */
    static String CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    /**
     * Characters for private player ids.
     */
    static String ID_CHARS = "abcdefghijklmnopqrstuvwxyz0123456789";

    /**
     * Which side a player has in a room, or Null if they are not in it.
     */
    static Color? colorOf(RoomRecord room, String playerId) {
        if (playerId == room.blackId) {
            return Black;
        }
        String? white = room.whiteId;
        return white != Null && white == playerId ? White : Null;
    }

    /**
     * True if the game is live, both seats are taken, and it is this player's move.
     */
    static Boolean isYourTurn(RoomRecord room, String playerId) {
        return room.whiteId != Null
                && room.game.status == Ongoing
                && colorOf(room, playerId) == room.game.turn;
    }

    /**
     * A random string of `size` characters drawn from `chars`.
     */
    static String randomText(Random random, String chars, Int size) {
        StringBuffer buf = new StringBuffer();
        for (Int i : 0 ..< size) {
            buf.append(chars[random.int(chars.size)]);
        }
        return buf.toString();
    }
}
