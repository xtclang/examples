/**
 * This is a simple Ecstasy-based web application that utilizes "webauth" module.
 */
@WebApp
module count.examples.org {
    package db  import countDB.examples.org;
    package web import web.xtclang.org;

    import web.*;
    import web.security.*;

    @StaticContent("/", /public/index.html)
    service Home {}

    @LoginRequired
    @StaticContent("/authorized", /public/authorized/)
    service CounterPages {}

    @HttpsRequired
    @SessionRequired
    @WebService("/api")
    service CounterApi {
        @Inject db.CountSchema schema;

        @LoginRequired
        @Get("user")
        @Produces(Text)
        String getUser() = session?.principal?.name : "";

        @LoginRequired
        @Get("count")
        Int count() {
            String user = getUser();
            using (schema.createTransaction()) {
                Int count = schema.counters.getOrDefault(user, 0);
                schema.counters.put(user, ++count);
                return count;
            }
        }

        // ----- restricted endpoints for external REST API (allowing entitlements) ----------------

        @LoginRequired
        @Restrict
        @Get("quiet-count")
        Int quietCount() = schema.counters.getOrDefault(getUser(), 0);

        @Restrict
        @Get("all-count")
        Int allCount() = schema.counters.reduce(0, (v, e) -> v + e.value);
    }
}