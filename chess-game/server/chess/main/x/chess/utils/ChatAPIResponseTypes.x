/**
 * Chat API Response Types Package
 * Contains all data structures for chat API request/response handling
 */
package ChatAPIResponseTypes {
    // ===== Chat API Response Types =====

    /**
     * ChatMessageResponse - API response format for a single chat message
     */
    const ChatMessageResponse(String playerId,
                              String playerColor,
                              String message = "",
                              Int timestamp);

    /**
     * ChatHistoryResponse - API response containing chat messages
     */
    const ChatHistoryResponse(Boolean success,
                              String? error,
                              ChatMessageResponse[] messages = []);

    /**
     * SendMessageResponse - API response after sending a message
     */
    const SendMessageResponse(Boolean success,
                              String? error,
                              String? message = Null);

    /**
     * SendMessageRequest - API request body for sending a message
     */
    const SendMessageRequest(String message = "");
}
