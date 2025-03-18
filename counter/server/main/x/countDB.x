@oodb.Database
module countDB.examples.org {
    package auth import webauth.xtclang.org;
    package oodb import oodb.xtclang.org;

    interface CountSchema
            extends oodb.RootSchema {

        /**
         * Number of times a user for a given id has logged in.
         */
        @RO oodb.DBMap<Int, Int> counters;

        /**
         * Persistent authentication info.
         */
        @RO auth.AuthSchema authSchema;
    }
}