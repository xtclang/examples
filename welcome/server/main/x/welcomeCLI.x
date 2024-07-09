/**
 * The "welcome" interaction command line tool.
 */
module welcomeCLI.examples.org
        incorporates TerminalApp("Welcome command line tool", "Welcome>") {
    package cli  import cli.xtclang.org;
    package json import json.xtclang.org;
    package net  import net.xtclang.org;
    package web  import web.xtclang.org;

    import cli.Command;
    import cli.Desc;
    import cli.TerminalApp;

    import json.Doc;
    import json.Parser;
    import json.Printer;

    import net.Uri;
    import web.*;

    @Inject Console console;

    @Override
    void run(String[] args) {
        console.print("*** Welcome Command Line Tool");
        Gateway.resetClient();
        super([]);
    }

    static service Gateway {
        private @Unassigned Client client;
        private @Unassigned String welcomeUri;

        void resetClient() {
            client          = new HttpClient();
            this.welcomeUri = console.readLine($"Enter welcome host: ");
        }

        String send(RequestOut request) {
            ResponseIn response = client.send(request);
            HttpStatus status   = response.status;
            if (status == OK) {
                assert Body body ?= response.body;
                Byte[] bytes = body.bytes;
                if (bytes.size == 0) {
                    return "Empty response";
                }

                switch (body.mediaType) {
                case Text:
                    return bytes.unpackUtf8();
                case Json:
                    String jsonString = bytes.unpackUtf8();
                    Doc    doc        = new Parser(jsonString.toReader()).parseDoc();
                    return Printer.PRETTY.render(doc);
                default:
                    return $"<Unsupported media type: {body.mediaType}>";
                }
            } else {
                return response.toString();
            }
        }

        String sendRequest(HttpMethod method, String path, Object? content=Null) {
            RequestOut request = client.createRequest(method,
                    new Uri($"https://{welcomeUri}/{path}"), content);
            return send(request);
        }
    }
}