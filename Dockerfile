# syntax=docker/dockerfile:1
# Enables COPY --exclude (BuildKit). Config edits then only rebuild the small final stage.
FROM maven:3.8.6-jdk-8 AS dependencies
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:resolve

FROM maven:3.8.6-jdk-8 AS builder
WORKDIR /app
COPY pom.xml .
# Omit user-editable configs from this layer so Maven stays cached when only those files change.
# Exclude paths are relative to the COPY source (`src/`), not the build context — use main/resources/..., not src/main/...
COPY --exclude=main/resources/wowchat.conf --exclude=main/resources/wowchat_test.conf src ./src
# Assembly still packages wowchat.conf; runtime uses /app/config.conf from the final stage.
RUN touch src/main/resources/wowchat.conf
COPY --from=dependencies /root/.m2 /root/.m2
RUN mvn clean package -DfinalName=wowchat

FROM eclipse-temurin:8
WORKDIR /app
ARG CONF_FILE
COPY ./src/main/resources/logback.xml /app/logback.xml
COPY ./src/main/resources/${CONF_FILE} /app/config.conf
COPY --from=builder /app/target/wowchat.jar /app

ENTRYPOINT ["java",\
            "-XX:+HeapDumpOnOutOfMemoryError",\
            "-Dfile.encoding=UTF-8", \
            "-Dlogback.configurationFile=logback.xml", \
            "-jar", \
            "wowchat.jar", \
            "config.conf"]
