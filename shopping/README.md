# Simple Ecstasy DB Test Example

This example is primarily to show how to use XUnit DB to write tests of an application that uses 
an injected Ecstasy database.

## Shopping Cart Application

The application is a simple shopping cart made up of a database module and an API module.
The database module only depends on the Ecstasy OODB module, it doe snot need to use, nor have 
any knowledge of specific DB implementations (such as JSON DB). The API only depends on the Cart 
DB and does not need to know anything about the Ecstasy OODB.

## Cart DB

The database module is in the `shopping/src/main/x/cart_db.x` file and is a simple Ecstasy DB.

There are two entities in the database: `Cart` and `Item`.

The database contains a single table, a DBMap named `carts`. The `carts` table is actually a 
mixin `Carts` that adds functionality to a DBMap to perform operations on carts in the map.

## Cart API

The API module is in the `shopping/src/main/x/cart_api.x` file and is a simple REST API.

The API module uses an injected Cart DB to perform operations on the carts.

## Tests

The test code is in the `src/test/x/cart_api_tests.x` file. These tests are written as normal 
XUnit tests. The tests also use the XUnit DB extensions which allows the injection of databases 
into tests.

XUnit DB can inject any database into a test, so all a test needs to do is be annotated with 
`@DatabaseTest`. XUnit DB will use the Ecstasy JSON DB module to create databases as and when 
required for the injections. 

XUnit DB will automatically provide database injections into the XUnit tests.

## Controlling Injections

Because of how Ecstasy injection works, we need to tell the XVM that XUnit is responsible for 
injections into certain modules.

In a normal module that depended on the Carts API the module definition might look like the one 
below with a package import of `cart_api`.

```
module cart_api_tests {

    package carts   import cart_api;

    package db      import cart_db;
    package xunit   import xunit.xtclang.org;
    package xunitdb import xunit_db.xtclang.org;

```

However, for testing we specifically want XUnit to be able to inject databases (and maybe 
anything else) into the `carts` module. For this we need to add the `inject` keyword to the 
`import` statement. The `inject` keyword tels the XVM which injector to use for the module. In 
this case we want to use the XUnit `PassThruInjector` which simply passes XUnit injections 
through to the module. We do not need to do this for the `cart_db` module because it does not 
have anything injected. If it did and we wanted to write tests where we injected into that 
module too, then we could add the same injection keyword to the `import` statement.

```
module cart_api_tests {

    package carts   import cart_api inject (ecstasy.reflect.Injector _) using xunit.PassThruInjector;

    package db      import cart_db;
    package xunit   import xunit.xtclang.org;
    package xunitdb import xunit_db.xtclang.org;
```

