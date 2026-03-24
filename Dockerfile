FROM gradle:jdk25 AS builder

WORKDIR /workspace

# Layer 1: Build config and dependency resolution — cached until build files change
COPY settings.gradle.kts build.gradle.kts gradle.properties ./
COPY gradle/ gradle/
COPY build-logic/ build-logic/
COPY banking/build.gradle.kts banking/build.gradle.kts
COPY counter/build.gradle.kts counter/build.gradle.kts
COPY chess-game/build.gradle.kts chess-game/build.gradle.kts
COPY welcome/build.gradle.kts welcome/build.gradle.kts
RUN gradle dependencies --no-daemon 2>/dev/null || true

# Layer 2: Source code — only this layer rebuilds when sources change
COPY banking/ banking/
COPY counter/ counter/
COPY chess-game/ chess-game/
COPY welcome/ welcome/

RUN gradle build installDist --no-daemon

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
