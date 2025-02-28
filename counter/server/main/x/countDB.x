@oodb.Database
module countDB.examples.org {
    package auth import webauth.xtclang.org;
    package oodb import oodb.xtclang.org;

    interface CountSchema
            extends oodb.RootSchema {

        @RO oodb.DBMap<Int, Int> counters;

        @RO auth.AuthSchema authSchema;
    }
}