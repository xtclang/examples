/**
 * The "welcome" interaction command line tool.
 */
@TerminalApp("Welcome Command Line Tool", "Welcome>")
module welcomeCLI.examples.org {
    package webcli import webcli.xtclang.org;

    import webcli.*;

    @Command("org", "Get an organization name")
    String org() = get("welcome/org");
}