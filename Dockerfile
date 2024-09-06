FROM maven:3.8.6-jdk-8 AS dependencies
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:resolve

FROM maven:3.8.6-jdk-8 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
COPY --from=dependencies /root/.m2 /root/.m2
RUN mvn clean package -DfinalName=wowchat

FROM openjdk:8-jre
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
