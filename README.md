# Examples

This is the public repository for simple examples developed with Ecstasy to be deployed
on the `xqiz.it` hosting platform.

## Prerequisites

None! The Gradle build will automatically:
- Download the correct JDK (Java 25) via the Foojay toolchain plugin
- Download Node.js and npm for webapp builds (via the node-gradle plugin)
- Download the XTC compiler and runtime (XDK)

Just ensure you have the Gradle wrapper script (`./gradlew`) available.

## Project Structure

This is a multi-project Gradle build with three example applications:

- **welcome/** - A welcome application with database and React web interface
- **banking/** - A banking stress test application
- **counter/** - A counter application with database

Each example follows the standard XTC Gradle plugin layout:

```
examples/
├── settings.gradle.kts           # Root build configuration
├── build.gradle.kts              # Root build with XTC plugin and dependencies
├── gradle.properties             # Build properties (version, JVM args, etc.)
├── gradle/
│   └── libs.versions.toml        # Centralized version catalog
│
├── welcome/
│   ├── build.gradle.kts          # Welcome module build with Node.js integration
│   ├── src/
│   │   └── main/
│   │       └── x/                # Ecstasy source code (*.x files)
│   │           ├── welcome.x
│   │           ├── welcomeCLI.x
│   │           ├── welcomeDB.x
│   │           └── welcomeTest.x
│   └── webapp/                   # React webapp (integrated as resources)
│       ├── package.json
│       ├── public/
│       └── src/
│
├── banking/
│   ├── build.gradle.kts
│   ├── src/
│   │   └── main/
│   │       └── x/
│   │           ├── Bank.x
│   │           └── BankStressTest.x
│   └── webapp/                   # Static resources only
│       └── public/
│
└── counter/
    ├── build.gradle.kts
    ├── src/
    │   └── main/
    │       └── x/
    │           ├── count.x
    │           └── countDB.x
    └── webapp/                   # Static resources only
        └── public/
```

## Building

### Build Everything

From the repository root:

```bash
./gradlew build
```

This will:
1. Compile all Ecstasy modules (`.x` → `.xtc`)
2. Build all webapps (where applicable)
3. Package resources

### Build Individual Examples

```bash
./gradlew :welcome:build    # Build welcome example
./gradlew :banking:build    # Build banking example
./gradlew :counter:build    # Build counter example
```

### Clean Build Artifacts

```bash
./gradlew clean
```

## Development Workflow

### Working on Ecstasy Code

Ecstasy source files (`.x`) are located in `<example>/src/main/x/`. After editing:

```bash
./gradlew :welcome:compileXtc
```

The XTC plugin automatically discovers all `.x` files and compiles them in the correct order.

### Working on Webapp Code (Welcome Example)

The welcome example includes a React webapp. JavaScript/React source files are in `welcome/webapp/src/`.

To build the webapp:

```bash
./gradlew :welcome:build
```

Or for development with hot-reload:

```bash
cd welcome/webapp
npm start   # npm is downloaded automatically by Gradle
```

The built webapp is automatically integrated as resources in the XTC module during the build process.

## Deploying to XQIZ.IT Platform

1. Follow the instructions from the [platform setup](https://github.com/xtclang/platform/blob/master/README.md#steps-to-test-the-paas-functionality)
   repository to start the hosting site.

2. Build your example:
   ```bash
   ./gradlew :welcome:build
   ```

3. Use the platform UI to upload and run the compiled modules (`.xtc` files from `<example>/build/xtc/main/lib/`).

## Version Management

All projects share a single version defined in `gradle.properties`:

```properties
version=0.1.0
```

This ensures all compiled modules have consistent versioning.

## XTC Gradle Plugin Integration

This project follows the **platform** pattern for XTC Gradle integration:

1. **Root build** applies the XTC plugin and declares all modules as `xtcModule` dependencies
2. **Each module** applies the XTC plugin and declares `xdkDistribution(libs.xdk)` dependency
3. **Version catalog** (`gradle/libs.versions.toml`) centralizes all plugin and dependency versions
4. **Repository configuration** in `settings.gradle.kts` supports both release and snapshot XTC versions

The welcome example additionally integrates the `node-gradle` plugin for React webapp builds, following the `platformUI` pattern.

## Available Gradle Tasks

```bash
./gradlew tasks                   # List all available tasks
./gradlew compileXtc              # Compile all XTC modules
./gradlew processXtcResources     # Process resources for XTC modules
./gradlew build                   # Full build (compile + resources + webapp)
./gradlew clean                   # Remove build artifacts
./gradlew :welcome:npmInstall     # Install npm dependencies for welcome webapp
./gradlew :welcome:buildWebapp    # Build welcome React webapp
```

## Troubleshooting

**Build fails with "Java not found"**: The build will automatically download Java 25. Ensure you have internet connectivity.

**Webapp build fails**: Ensure `package.json` has a `"build"` script. The node-gradle plugin will automatically download Node.js and npm.

**XTC compilation errors**: Check that your `.x` files are in `<example>/src/main/x/` and that module dependencies are correct.

**Configuration cache issues**: Run `./gradlew --configuration-cache-problems` to diagnose configuration cache problems.

## Reference Projects

This examples repository follows the patterns established in:
- **xtc-app-template** - Simple XTC Gradle app template
- **platform** - Production XTC multi-module application with platformUI

See these projects for additional examples of XTC Gradle integration patterns.
