@oodb.Database
module countDB.examples.org
    {
    package auth import webauth.xtclang.org inject(auth.Configuration startingCfg) using AuthInjector;
    package oodb import oodb.xtclang.org;

    import ecstasy.mgmt.ResourceProvider;

    interface CountSchema
            extends oodb.RootSchema
        {
        @RO oodb.DBMap<String, Int> counters;

        @RO auth.AuthSchema authSchema;
        }

    static service AuthInjector
            implements ResourceProvider
        {
        @Override
        ResourceProvider.Supplier getResource(Type type, String name)
            {
            return type == auth.Configuration
                    ? new auth.Configuration(["admin"="password"], configured=False)
                    : throw new Exception($|Unsupported resource: type="{type}" name="{name}"
                                         );
            }
        }
    }