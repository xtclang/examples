/**
 * This is a simple Ecstasy-based web application that utilizes "webauth" module.
 */
@WebApp
module count.examples.org {
    package db  import countDB.examples.org;
    package web import web.xtclang.org;

    import web.*;
    import web.security.*;

    /**
     * The public website area (no authentication is required).
     */
    @StaticContent("/", /public/index.html)
    service Home {}

    /**
     * The protected website area (authentication is required).
     */
    @LoginRequired
    @StaticContent("/authorized", /public/authorized/)
    service CounterPages {}

    @HttpsRequired
    @SessionRequired
    @WebService("/api")
    service CounterApi {
        @Inject db.CountSchema schema;

        /**
         * The authenticated user id.
         */
        @LoginRequired
        @Get("user")
        @Produces(Text)
        String userName() = session?.userName? : assert;

        /**
         * The endpoint triggered when an authenticated user enters the "protected" application area.
         */
        @LoginRequired
        @Get("count")
        Int count() {
            using (schema.createTransaction()) {
                Int    id    = principalId;
                Int    count = schema.counters.getOrDefault(id, 0);
                schema.counters.put(id, ++count);
                return count;
            }
        }

        // ----- restricted endpoints for external REST API (allowing entitlements) ----------------

        @LoginRequired
        @Restrict
        @Get("quiet-count")
        Int quietCount() = schema.counters.getOrDefault(principalId, 0);

        @Restrict
        @Get("all-count")
        Int allCount() = schema.counters.reduce(0, (v, e) -> v + e.value);

        @RO Int principalId.get() = session?.principal?.principalId : assert;
    }
}