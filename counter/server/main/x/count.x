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
            return schema.counters.getOrDefault(getUser(session), 0);
            }
        }

    Authenticator createAuthenticator()
        {
        return new DigestAuthenticator(new FixedRealm("count", ["acme"="password"]));
        }
    }