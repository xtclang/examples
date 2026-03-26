/**
 * This is a simple Ecstasy-based web application that utilizes "webauth" module.
 */
@WebApp
module count.examples.org {
    package db   import countDB.examples.org;
    package sec  import sec.xtclang.org;
    package web  import web.xtclang.org;

    import sec.*;
    import web.*;
    import web.security.*;

    /**
     * The public website area (no authentication is necessary).
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
         * Triggered when an authenticated user enters the "protected" application area.
         */
        @LoginRequired
        @Get("count")
        Int count() = schema.updateUserData(principalId);

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

    annotation SessionData
            into Session {
        @Override
        void sessionAuthenticated(Principal? principal, Credential? credential,
                                  Entitlement[] entitlements) {
            assert principal != Null;

            // an example of non-persistent web app logging
            @Inject Console console;
            console.print($"User {principal.name}#{principal.principalId} has logged in");

            super(principal, credential, entitlements);
        }
    }
}