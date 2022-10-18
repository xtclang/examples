/**
 * This is a simple Ecstasy-based web application.
 */
@web.WebApp
module welcome
    {
    package web import web.xtclang.org;
    package db  import welcomeDB;

    @web.WebService("/welcome")
    service SimpleApi
        {
        @Inject db.WelcomeSchema schema;

        @web.Get
        Int count()
            {
            return schema.count.next();
            }
        }

    @web.StaticContent("/", Directory:/webapp)
    service Content
        {
        }
    }