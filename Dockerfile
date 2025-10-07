# syntax=docker/dockerfile:1.7

############################
# Stage 1: Build (Gradle)
############################
FROM gradle:8.5-jdk21 AS builder
WORKDIR /app

# Cache Gradle deps
COPY gradle gradle
COPY gradlew settings.gradle build.gradle.kts* build.gradle* ./
RUN ./gradlew --no-daemon -v >/dev/null 2>&1 || true

# Bring in sources last (better cache)
COPY src src

# Build fat jar (Boot jar). Skip tests for speed in CI images.
RUN ./gradlew --no-daemon clean bootJar -x test

############################
# Stage 2: Runtime (slim JRE)
############################
FROM eclipse-temurin:21-jre-alpine AS runtime
WORKDIR /app

# (Optional) add a non-root user for safety
RUN addgroup -S app && adduser -S app -G app
USER app

# Copy the fat jar (there should be exactly one boot jar)
COPY --from=builder /app/build/libs/*-SNAPSHOT.jar /app/app.jar
# If you version with semver instead of -SNAPSHOT, you can use: /*.jar

# Sensible defaults for a migration job
ENV SPRING_MAIN_WEB_APPLICATION_TYPE=none \
    SPRING_FLYWAY_ENABLED=true \
    SPRING_FLYWAY_BASELINE_ON_MIGRATE=true \
    JAVA_OPTS="-XX:+ExitOnOutOfMemoryError -XX:MaxRAMPercentage=75.0"

ENTRYPOINT ["sh","-c","java $JAVA_OPTS -jar /app/app.jar"]