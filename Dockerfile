FROM maven:3.8.6-jdk-8 AS dependencies
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:resolve

FROM maven:3.8.6-jdk-8 as builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
COPY --from=dependencies /root/.m2 /root/.m2
RUN mvn clean package

FROM openjdk:8-jre
WORKDIR /app
COPY ./wowchat_custom.conf /app
COPY --from=builder /app/target/wowchat-1.3.8-t1.17.1-2.zip /app
RUN unzip wowchat-1.3.8-t1.17.1-2.zip

ENTRYPOINT ["java", "-jar", "wowchat/wowchat.jar", "wowchat_custom.conf"]
