FROM gradle:9.7.0-jdk25 AS builder

WORKDIR /workspace

# Layer 1: Build config and dependency resolution — cached until build files change
COPY settings.gradle.kts build.gradle.kts gradle.properties ./
COPY gradle/ gradle/
COPY build-logic/ build-logic/
COPY banking/build.gradle.kts banking/build.gradle.kts
COPY counter/build.gradle.kts counter/build.gradle.kts
COPY card-game/build.gradle.kts card-game/build.gradle.kts
COPY chess-game/settings.gradle.kts chess-game/build.gradle.kts chess-game/
COPY chess-game/app/build.gradle.kts chess-game/app/
COPY chess-game/db/build.gradle.kts chess-game/db/
COPY welcome/build.gradle.kts welcome/build.gradle.kts
RUN gradle dependencies --no-daemon 2>/dev/null || true

# Layer 2: Source code — only this layer rebuilds when sources change
COPY banking/ banking/
COPY counter/ counter/
COPY card-game/ card-game/
COPY chess-game/ chess-game/
COPY welcome/ welcome/

# Tests already run on the dedicated CI `build` job on Linux. The image
# build's job is packaging only — `installDist` covers compile + assemble +
# stage. The final-stage `RUN xtc run ... welcomeTest` below provides a
# runtime smoke check on the produced image.
RUN gradle installDist --no-daemon

# Stage 2: Grab the XVM runtime from its official image
FROM ghcr.io/xtclang/xvm:latest AS xvm

# Stage 3: Runtime image with compiled modules and XVM
FROM eclipse-temurin:25-jre

COPY --from=xvm /opt/xdk/ /opt/xdk/
COPY --from=builder /workspace/build/install/examples/lib/ /opt/examples/lib/

ENV PATH="/opt/xdk/bin:${PATH}"

# Verify: run the welcomeTest module
RUN xtc run -L /opt/examples/lib welcomeTest

ENTRYPOINT ["xtc"]
CMD ["run", "-L", "/opt/examples/lib", "welcomeTest"]
