/**
 * Room Record - a game two people play from their own devices.
 *
 * One player creates the room and is Black (who moves first); a friend joins with the room code
 * and is White. Each is known by a private player id, which the browser keeps and sends with every
 * request, so only the two seated players can move.
 *
 * @param code     The room's code, which the creator shares (e.g. "K7M2QX")
 * @param game     The game being played; its nicknames are the two players'
 * @param blackId  The creator's player id
 * @param whiteId  The joiner's player id, or Null while the room waits for a second player
 * @param leftId   The id of a player who has left, or Null
 * @param timeControl  The clocks, or Null for an untimed room
 * @param timedOut Whether the game ended because a player's time ran out
 */
const RoomRecord(String code,
                 GameRecord game,
                 String blackId,
                 String? whiteId = Null,
                 String? leftId = Null,
                 TimeControl? timeControl = Null,
                 Boolean timedOut = False) {}
