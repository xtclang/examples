/**
 * This is a simple Ecstasy-based web application.
 */
@WebApp
module welcome
    {
    package web import web.xtclang.org;
    package db  import welcomeDB;

    import web.*;

    @WebService("/welcome")
    service SimpleApi
        {
        @Inject db.WelcomeSchema schema;

        @Get
        Int count()
            {
            return schema.count.next();
            }
        }

    @StaticContent("/", /webapp)
    service Content
        {
        }
    }