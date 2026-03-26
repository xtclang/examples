@oodb.Database
module countDB.examples.org {
    package auth import webauth.xtclang.org;
    package oodb import oodb.xtclang.org;

    interface CountSchema
            extends oodb.RootSchema {

        /**
         * The number of times a user with a given id has logged in.
         */
        @RO oodb.DBMap<Int, Int> counters;

        /**
         * Persistent authentication info.
         */
        @RO auth.AuthSchema authSchema;

        /**
         * Update user data for the specified user id.
         *
         * @return the login count
         */
         Int updateUserData(Int id) {
            Int count = counters.getOrDefault(id, 0);
            counters.put(id, ++count);

            if (count % 5 == 0) {
                // an example of non-persistent db logging
                @Inject Console console;
                console.print($"The counter for user {id} has reached {count}");
            }
            return count;
         }
    }
}