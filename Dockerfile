FROM eclipse-temurin:25-jdk AS builder

WORKDIR /workspace

# Copy Gradle wrapper and build config first (cacheable layer)
COPY gradlew gradlew.bat ./
COPY gradle/ gradle/
COPY settings.gradle.kts build.gradle.kts gradle.properties ./
COPY build-logic/ build-logic/

# Copy all example sources and webapp content
COPY banking/ banking/
COPY counter/ counter/
COPY chess-game/ chess-game/
COPY welcome/ welcome/

# Build everything and collect modules
RUN ./gradlew build installDist --no-daemon --refresh-dependencies

# Lightweight output image with just the compiled modules
FROM eclipse-temurin:25-jre

COPY --from=builder /workspace/build/install/examples/lib/ /opt/examples/lib/

ENTRYPOINT ["echo", "Compiled modules in /opt/examples/lib/"]
