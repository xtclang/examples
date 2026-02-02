/**
 * Chat Message Record
 * 
 * Represents a single chat message sent during an online game.
 * 
 * @param roomCode      The room code this message belongs to
 * @param playerId      Session ID of the player who sent the message
 * @param playerColor   Color of the player (White or Black)
 * @param message       Text content of the message
 * @param timestamp     When the message was sent (milliseconds since epoch)
 */
const ChatMessage(String roomCode,
                  String playerId,
                  Color playerColor,
                  String message,
                  Time timestamp) {}
