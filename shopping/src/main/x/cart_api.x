@WebApp
module cart_api {

    package db  import cart_db;
    package web import web.xtclang.org;

    import db.Connection;
    import db.Cart;
    import db.Item;

    import web.BodyParam;
    import web.Consumes;
    import web.Delete;
    import web.Get;
    import web.HttpStatus;
    import web.Patch;
    import web.Post;
    import web.Produces;
    import web.QueryParam;
    import web.WebApp;
    import web.WebService;

    /**
     * The shopping carts API.
     */
    @WebService("/carts")
    service CartsApi() {
        /**
         * The carts database.
         */
        @Inject Connection dbc;

        /**
         * Get a specific Cart by id.
         */
        @Get("/{id}")
        @Produces(Json)
        conditional Cart getCart(String id) {
            return dbc.carts.get(id);
        }

        /**
         * Delete a specific Cart by id.
         */
        @Delete("/{id}")
        HttpStatus deleteCart(String id) {
            if (dbc.carts.contains(id)) {
                dbc.carts.remove(id);
                return HttpStatus.OK;
            }
            return HttpStatus.NotFound;
        }

        /**
         * Merge one shopping cart into another.
         *
         * Customer can add products to a shopping cart anonymously, but when
         * they log in the anonymous shopping cart needs to be merged into
         * the customer's own shopping cart
         */
        @Get("/{id}/merge")
        HttpStatus merge(String id, @QueryParam("sessionId") String sessionId) {
            return dbc.carts.merge(id, sessionId) ? HttpStatus.Accepted : HttpStatus.NotFound;
        }

        /**
         * Get the items for a specific Cart identifier.
         */
        @Get("{id}/items")
        @Produces(Json)
        conditional Item[] getItems(String id) {
            if (Cart cart := dbc.carts.get(id)) {
                return True, cart.items;
            }
            return False;
        }

        /**
         * Add item to the shopping cart.
         *
         * This operation will add item to the shopping cart if it doesn't already exist,
         * or increment quantity by the specified number of items if it does.
         */
        @Post("/{id}/items")
        @Consumes(Json)
        @Produces(Json)
        (Item, HttpStatus) addItem(String id, @BodyParam Item item) {
            Item added = dbc.carts.addItem(id, item);
            return (added, HttpStatus.Accepted);
        }

        /**
         * Return the specified item from the shopping cart.
         */
        @Get("/{id}/items/{itemId}")
        @Produces(Json)
        conditional Item getItem(String id, String itemId) {
            if (Cart cart := dbc.carts.get(id)) {
                return cart.getItem(itemId);
            }
            return False;
        }

        /**
         * Remove specified item from the shopping cart, if it exists.
         */
        @Delete("/{id}/items/{itemId}")
        HttpStatus deleteItem(String id, String itemId) {
            dbc.carts.removeItem(id, itemId);
            return HttpStatus.Accepted;
        }

        /**
         * Update item in a shopping cart.
         *
         * This operation will add item to the shopping cart if it doesn't
         * already exist, or replace it with the specified item if it does.
         */
        @Patch("/{id}/items")
        @Consumes(Json)
        HttpStatus updateItem(String id, @BodyParam Item item) {
            dbc.carts.updateItem(id, item);
            return HttpStatus.Accepted;
        }
    }
}
