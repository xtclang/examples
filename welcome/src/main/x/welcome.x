/**
 * This is a simple Ecstasy-based web application.
 */
@WebApp
module welcome.examples.org {
    package web import web.xtclang.org;
    package db  import welcomeDB.examples.org;

    import web.*;

    @WebService("/welcome")
    service SimpleApi {
        @Inject Client client;
        @Inject db.WelcomeSchema schema;

        @Get("org")
        String organization() {
            @Inject String org;
            return org;
        }

        @Get("info")
        @Produces(Text)
        String callerInfo(RequestIn request) {
            ResponseIn response = client.get($"http://ip-api.com/json/{request.client}");
            return response.body?.bytes.unpackUtf8() : "";
        }

        @Get("count")
        Int count(RequestIn request) {
            using (val tx = schema.connection.createTransaction()) {
                String address = request.client.toString();
                Int    count   = tx.counters.getOrDefault(address, 0);
                tx.counters.put(address, ++count);
                return count;
            }
        }
    }

    @StaticContent("/", /build)
    service Content {}
}