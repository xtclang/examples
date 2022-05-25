/**
 * This is a simple Ecstasy-based web application.
 *
 * 1. Make sure your "hosts" file contains the following entries:
 *      127.0.0.10 admin.xqiz.it
 *      127.0.0.20 shop.acme.user.xqiz.it
 *
 * 2. Allow the loopback addresses binding by running this script:
 *        xvm/bin/allowLoopback.sh
 *
 * 3. Ensure the host is running (platform project)
 *      gradle run
 *
 * 4. Build and upload the "welcome" modules (examples.welcome project)
 *      gradle upload
 *
 * 5. Load this test:
 *      curl -i -w '\n' -X POST http://admin.xqiz.it:8080/host/load -G -d 'app=welcome,domain=shop.acme.user'
 *
 * 6. Open in the browser:
 *      http://shop.acme.user.xqiz.it:8080
 */
@web.WebModule
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

    @web.StaticContent(/webapp, ALL_TYPE)
    service Content
        {
        }
    }