module cardGame.examples.org {

    void run() {
        @Inject Console console;
        console.print("Starting Eights with default players.");
        Eights game = new Eights("Player 1", "Player 2");
        game.playGame();
    }
}
