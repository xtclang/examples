/**
 * CardGame application module.
 *
 * Run with: ./gradlew runXtc
 * Run with args: ./gradlew runXtc --args=World,XTC
 */
module CardGame {
    void run(String[] args=[]) {
        @Inject Console console;
        if (args.empty) {
            console.print("Hello from CardGame!");
            return;
        }
        for (String arg : args) {
            console.print($"Hello, {arg}!");
        }
    }
}
