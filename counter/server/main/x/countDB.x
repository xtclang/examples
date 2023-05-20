@oodb.Database
module countDB.examples.org
    {
    package auth import webauth.xtclang.org;
    package oodb import oodb.xtclang.org;

    import ecstasy.mgmt.ResourceProvider;

    interface CountSchema
            extends oodb.RootSchema
        {
        @RO oodb.DBMap<String, Int> counters;

        @RO auth.AuthSchema authSchema;
        }
    }