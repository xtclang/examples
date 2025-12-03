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
    }
}