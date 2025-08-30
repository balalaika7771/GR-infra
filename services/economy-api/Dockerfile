FROM openjdk:21-jdk-slim

WORKDIR /app

COPY build/libs/economy-api-1.0.0.jar app.jar

EXPOSE 8080

CMD ["java", "-jar", "app.jar"]
