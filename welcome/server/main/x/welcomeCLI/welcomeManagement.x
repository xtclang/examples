class WelcomeManagement {

    @Command("org", "Get an organization name")
    String org() = Gateway.sendRequest(GET, "welcome/org");
}
