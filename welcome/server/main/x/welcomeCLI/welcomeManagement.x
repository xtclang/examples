class WelcomeManagement {

    @Command("reset", "Reset the welcome URL")
    void reset() = Gateway.resetClient();

    @Command("org", "Get an organization name")
    String org() = Gateway.sendRequest(GET, "welcome/org");
}
