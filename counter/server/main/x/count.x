/**
 * This is a simple Ecstasy-based web application that utilizes "webauth" module.
 */
@WebApp
module count.examples.org {
    package auth import webauth.xtclang.org inject(auth.Configuration startingCfg) using AuthInjector;
    package db   import countDB.examples.org;
    package web  import web.xtclang.org;

    import ecstasy.mgmt.ResourceProvider;

    import web.*;
    import web.security.*;

    @StaticContent("/", /public/index.html)
    service Home {}

    @LoginRequired
    @StaticContent("authorized", /public/authorized/)
    service CounterPages {}

    @LoginRequired
    @WebService("api")
    service CounterApi {
        @Inject db.CountSchema schema;

        @Get("user")
        @Produces(Text)
        String getUser(Session session) {
            return session.userId ?: "";
        }

        @Get("count")
        Int count(Session session) {
            String user  = getUser(session);
            Int    count = schema.counters.getOrDefault(user, 0);
            schema.counters.put(user, ++count);
            return count;
        }
    }

    Authenticator createAuthenticator() {
        return new DigestAuthenticator(new auth.DBRealm("count"));
    }

    static service AuthInjector
            implements ResourceProvider {
        @Override
        ResourceProvider.Supplier getResource(Type type, String name) {
            return type == auth.Configuration
                    ? new auth.Configuration(
                        ["admin"="password"],
                        ["Administrator"=["admin"]],
                        configured=False)
                    : throw new Exception($|Unsupported resource: type="{type}" name="{name}"
                                         );
        }
    }
}