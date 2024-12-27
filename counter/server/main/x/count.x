/**
 * This is a simple Ecstasy-based web application that utilizes "webauth" module.
 */
@WebApp
module count.examples.org {
    package db   import countDB.examples.org;
    package web  import web.xtclang.org;

    import web.*;
    import web.security.*;

    @StaticContent("/", /public/index.html)
    service Home {}

    @LoginRequired
    @StaticContent("/authorized", /public/authorized/)
    service CounterPages {}

    @LoginRequired
    @WebService("/api")
    service CounterApi {
        @Inject db.CountSchema schema;

        @Get("user")
        @Produces(Text)
        String getUser(Session session) = session.principal?.name : "";

        @Get("count")
        Int count(Session session) {
            String user  = getUser(session);
            Int    count = schema.counters.getOrDefault(user, 0);
            schema.counters.put(user, ++count);
            return count;
        }
    }
}