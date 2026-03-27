plugins {
    alias(libs.plugins.xtc)
}

dependencies {
    xdkDistribution(libs.xdk)
}

// Run configuration - can be overridden from command line:
//   ./gradlew runXtc --module=other --method=main --args=arg1,arg2
xtcRun {
    module {
        moduleName = "cardGame"
    }
}
