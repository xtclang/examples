@oodb.Database
module countDB.examples.org
    {
    package oodb import oodb.xtclang.org;

    interface CountSchema
            extends oodb.RootSchema
        {
        @RO oodb.DBMap<String, Int> counters;
        }
    }