/**
 * ChatApi Service
 *
 * RESTful API service for online chat functionality in multiplayer chess games.
 * Provides endpoints for:
 * - Sending chat messages in a game room
 * - Retrieving chat history for a room
 *
 * All operations require a valid room code and player ID for authentication.
 */
@WebService("/api/chat")
service ChatApi {
    // Injected dependencies
    @Inject ChessSchema schema;
    @Inject Clock       clock;

    /**
     * POST /api/chat/send/{roomCode}/{playerId}
     *
     * Sends a chat message to the specified room.
     *
     * @param roomCode The room code identifying the game
     * @param playerId The player's session ID
     * @param request The request body containing the message
     * @return SendMessageResponse indicating success or failure
     */
    @Post("send/{roomCode}/{playerId}")
    @Produces(Json)
    SendMessageResponse sendMessage(String roomCode, String playerId, @BodyParam SendMessageRequest request) {
        using (schema.createTransaction()) {
            // Verify the room exists
            if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                // Verify the player is in this room
                if (!game.hasPlayer(playerId)) {
                    return new SendMessageResponse(False, "You are not a player in this room", Null);
                }

                // Get player's color
                Color? color = game.getPlayerColor(playerId);
                if (color == Null) {
                    return new SendMessageResponse(False, "Could not determine player color", Null);
                }

                // Validate message content
                String trimmed = request.message.trim();
                if (trimmed.size == 0) {
                    return new SendMessageResponse(False, "Message cannot be empty", Null);
                }
                if (trimmed.size > 500) {
                    return new SendMessageResponse(False, "Message too long (max 500 characters)", Null);
                }

                // Create and store the chat message
                Int timestamp = (clock.now.epochPicos / 1_000_000_000).toInt64();
                ChatMessage msg = new ChatMessage(roomCode, playerId, color, trimmed, timestamp);
                String msgKey = $"{roomCode}_{timestamp}_{playerId}";
                schema.chatMessages.put(msgKey, msg);

                return new SendMessageResponse(True, Null, "Message sent successfully");
            }
            return new SendMessageResponse(False, "Room not found", Null);
        }
    }

    /**
     * GET /api/chat/history/{roomCode}/{playerId}?limit={number}
     *
     * Retrieves chat message history for the specified room.
     * Only returns messages from the current room.
     *
     * @param roomCode The room code identifying the game
     * @param playerId The player's session ID
     * @param limit Optional limit on number of messages (default: 100)
     * @return ChatHistoryResponse with array of messages
     */
    @Get("history/{roomCode}/{playerId}")
    @Produces(Json)
    ChatHistoryResponse getHistory(String roomCode, String playerId, @QueryParam("limit") Int limit = 100) {
        using (schema.createTransaction()) {
            // Verify the room exists
            if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                // Verify the player is in this room
                if (!game.hasPlayer(playerId)) {
                    return new ChatHistoryResponse(False, "You are not a player in this room", []);
                }

                // Filter messages for this room and convert to response format
                ChatMessageResponse[] messages = new Array<ChatMessageResponse>();
                Int count = 0;
                
                // Iterate through all chat messages and filter by room code
                for (ChatMessage msg : schema.chatMessages.values) {
                    if (msg.roomCode == roomCode) {
                        String colorName = msg.playerColor == White ? "White" : "Black";
                        messages.add(new ChatMessageResponse(
                            msg.playerId,
                            colorName,
                            msg.message,
                            msg.timestamp
                        ));
                        count++;
                        if (count >= limit) {
                            break;
                        }
                    }
                }

                return new ChatHistoryResponse(True, Null, messages.freeze(inPlace=True));
            }
            return new ChatHistoryResponse(False, "Room not found", []);
        }
    }

    /**
     * GET /api/chat/recent/{roomCode}/{playerId}/{since}
     *
     * Retrieves chat messages sent after a specific timestamp.
     * Used for polling to get only new messages.
     *
     * @param roomCode The room code identifying the game
     * @param playerId The player's session ID
     * @param since Timestamp (milliseconds) - only return messages after this time
     * @return ChatHistoryResponse with array of new messages
     */
    @Get("recent/{roomCode}/{playerId}/{since}")
    @Produces(Json)
    ChatHistoryResponse getRecent(String roomCode, String playerId, Int since) {
        using (schema.createTransaction()) {
            // Verify the room exists
            if (OnlineGame game := schema.onlineGames.get(roomCode)) {
                // Verify the player is in this room
                if (!game.hasPlayer(playerId)) {
                    return new ChatHistoryResponse(False, "You are not a player in this room", []);
                }

                // Filter messages for this room that are newer than 'since'
                ChatMessageResponse[] messages = new Array<ChatMessageResponse>();
                
                for (ChatMessage msg : schema.chatMessages.values) {
                    if (msg.roomCode == roomCode && msg.timestamp > since) {
                        String colorName = msg.playerColor == White ? "White" : "Black";
                        messages.add(new ChatMessageResponse(
                            msg.playerId,
                            colorName,
                            msg.message,
                            msg.timestamp
                        ));
                    }
                }

                return new ChatHistoryResponse(True, Null, messages.freeze(inPlace=True));
            }
            return new ChatHistoryResponse(False, "Room not found", []);
        }
    }
}
