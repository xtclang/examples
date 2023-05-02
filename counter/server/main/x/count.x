/**
 * This is a simple Ecstasy-based web application.
 */
@WebApp
module count.examples.org
    {
    package db  import countDB.examples.org;
    package web import web.xtclang.org;

    import web.*;
    import web.security.*;

    @StaticContent("/", /webapp/index.html)
    service Home {}

    @LoginRequired
    @StaticContent("authorized", /webapp/authorized)
    service CounterPages {}

    @LoginRequired
    @WebService("api")
    service CounterApi
        {
        @Inject db.CountSchema schema;

        @Get("user")
        @Produces(Text)
        String getUser(Session session)
            {
            return session.userId ?: "";
            }

        @Get("count")
        Int count(Session session)
            {
            String user  = getUser(session);
            Int    count = schema.counters.getOrDefault(user, 0);
            schema.counters.put(user, ++count);
            return count;
            }
        }

    Authenticator createAuthenticator()
        {
        return new DigestAuthenticator(new FixedRealm("count", ["acme"="password"]));
        }
    }