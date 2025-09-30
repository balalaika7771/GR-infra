FROM openjdk:21-jdk-slim

WORKDIR /app

# Ожидаем локальный app.jar в контексте билда (подложим его из deploy.sh)
COPY app.jar /app/app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
