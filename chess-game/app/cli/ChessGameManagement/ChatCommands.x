import webcli.*;

/**
 * Chat commands for online games.
 *
 * Covers the /api/chat/... endpoints:
 *   - messaging : send-message, chat-history, recent-messages
 *   - flows     : chat-flow (send + immediate history), chat-burst (3 rapid messages)
 */
mixin ChatCommands {

    /**
     * Send a chat message in an online game room.
     */
    @Command("send-message", "Send a chat message (roomCode playerId message)")
    String sendMessage(String roomCode, String playerId, String message) =
        post($|api/chat/send/{roomCode}/{playerId}
            , $|\{"message":"{message}"\}
            );

    /**
     * Retrieve full chat history for a room.
     */
    @Command("chat-history", "Get chat history (roomCode playerId)")
    String chatHistory(String roomCode, String playerId) =
        get($"api/chat/history/{roomCode}/{playerId}");

    /**
     * Retrieve recent chat messages since a given timestamp.
     */
    @Command("recent-messages", "Get recent messages (roomCode playerId sinceMs)")
    String recentMessages(String roomCode, String playerId, String sinceMs) =
        get($"api/chat/recent/{roomCode}/{playerId}/{sinceMs}");

    /**
     * Send a chat message and then immediately retrieve history.
     */
    @Command("chat-flow", "Send message then read history (roomCode playerId message)")
    String chatFlow(String roomCode, String playerId, String message) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Chat Flow ---\n");

        buf.append("Send: ");
        buf.append(post($|api/chat/send/{roomCode}/{playerId}
                        , $|\{"message":"{message}"\}
                        )).append('\n');

        buf.append("History: ");
        buf.append(get($"api/chat/history/{roomCode}/{playerId}")).append('\n');

        return buf.toString();
    }

    /**
     * Send three chat messages in quick succession, then fetch history.
     */
    @Command("chat-burst", "Send 3 messages quickly then read history (roomCode playerId)")
    String chatBurst(String roomCode, String playerId) {
        StringBuffer buf = new StringBuffer();
        buf.append("--- Chat Burst Test ---\n");

        for (Int i : 1..3) {
            buf.append($"Send {i}: ");
            buf.append(post($|api/chat/send/{roomCode}/{playerId}
                            , $|\{"message":"Test message {i}"\}
                            )).append('\n');
        }

        buf.append("History: ");
        buf.append(get($"api/chat/history/{roomCode}/{playerId}")).append('\n');

        return buf.toString();
    }
}
