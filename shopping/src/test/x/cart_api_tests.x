module cart_api_tests {
    // We will be injecting test DBs into the cart_api module so we must tell the XDK
    // to use the XUnit injector for this module.
    package carts   import cart_api inject (ecstasy.reflect.Injector _) using xunit.PassThruInjector;

    package db      import cart_db;
    package web     import web.xtclang.org;
    package xunit   import xunit.xtclang.org;
    package xunitdb import xunit_db.xtclang.org;

    import db.Connection;
    import db.Cart;
    import db.Item;

    import carts.CartsApi;

    import xunitdb.DatabaseTest;

    import web.HttpStatus;

    /**
     * This class is annotated with @DatabaseTest because it uses XUnit DB to manage test databases.
     * The PerTest db strategy means that a new database will be created for each test method.
     */
    @DatabaseTest(PerTest)
    class CartLifecycleTests {

        /**
         * The carts database.
         * Even though the field is at the class level, a new DB will be available for each test.
         * This is because XUnit uses a new instance of the test class to execute each test method.
         */
        @Inject Connection dbc;

        @Test
        public void shouldNotHaveCart() {
            assert dbc.carts.empty;
            CartsApi api = new CartsApi();
            assert api.getCart("foo") == False;
        }

        @Test
        public void shouldHaveCart() {
            assert dbc.carts.empty;

            // create a Cart and put it directly into the DB
            String cartId = "foo";
            Cart   cart   = new Cart(cartId);
            dbc.carts.put(cartId, cart);

            // now get the Cart using the API
            CartsApi api  = new CartsApi();
            assert Cart result := api.getCart(cartId);
            assert result == cart;
        }

        /**
         * This test is the same as the previous one, but it uses the @DatabaseTest
         * annotation to specify the database files to use.
         * The database files are located from the test module's embedded resources
         * (the src/test/resources directory).
         * The files are copied into the test's temporary directory before the test runs, so the
         * same test DB can be used multiple times.
         */
        @Test
        @DatabaseTest(PerTest, Directory:./dbData/fooCartDB)
        public void shouldHaveCartFromExistingDB() {
            // the DB files used should have an empty Cart with id=foo
            String cartId = "foo";
            assert Cart cart := dbc.carts.get(cartId);

            // get the Cart using the API
            CartsApi api = new CartsApi();
            assert Cart result := api.getCart(cartId);
            assert result == cart;
            assert result.items.empty;
        }

        @Test
        public void shouldDeleteCart() {
            // create a Cart and put it directly into the DB
            String cartId = "foo";
            Cart   cart   = new Cart(cartId);
            dbc.carts.put(cartId, cart);
            assert dbc.carts.contains(cartId);

            // now delete the Cart using the API
            CartsApi api  = new CartsApi();
            HttpStatus status = api.deleteCart(cartId);
            assert status == HttpStatus.OK;
            assert !dbc.carts.contains(cartId);
        }

        @Test
        public void shouldDeleteNonExistentCart() {
            // create a Cart and put it directly into the DB
            String cartId = "foo";
            assert dbc.carts.contains(cartId) == False;

            // now try to delete the Cart using the API
            CartsApi api  = new CartsApi();
            HttpStatus status = api.deleteCart(cartId);
            assert status == HttpStatus.NotFound;
            assert !dbc.carts.contains(cartId);
        }
    }

    /**
     * This class is annotated with @DatabaseTest because it uses XUnit DB to manage test databases.
     * The Shared db strategy means that all test methods will share a single test database, unless
     a test method is annotated with @DatabaseTest(PerTest) to override the class level annotation.
     */
    @DatabaseTest(Shared)
    class CartItemTests {

        @Inject Connection dbc;

        @Test
        public void shouldAddItemToCart() {
            // create an empty Cart in the database
            String cartId = "foo";
            Cart   cart   = new Cart(cartId);
            dbc.carts.put(cartId, cart);

            // add an item using the API
            CartsApi api  = new CartsApi();
            Item     item = new Item("awesome product", 100, 10.99);

            (Item added, HttpStatus status) = api.addItem(cartId, item);
            assert status == HttpStatus.Accepted;
            assert added == item;
            assert Cart dbCart := dbc.carts.get(cartId);
            assert dbCart.items.contains(item);
        }

        @Test
        public void shouldCreateCartIfRequiredWhenAddingItem() {
            String cartId = "foo";
            assert dbc.carts.contains(cartId) == False;

            // add an item using the API, which should create the Cart
            CartsApi api  = new CartsApi();
            Item     item = new Item("awesome product", 100, 10.99);

            (Item added, HttpStatus status) = api.addItem(cartId, item);
            assert status == HttpStatus.Accepted;
            assert added == item;
            assert Cart dbCart := dbc.carts.get(cartId);
            assert dbCart.items.contains(item);
        }


    }
}