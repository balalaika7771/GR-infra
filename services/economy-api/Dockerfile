FROM openjdk:21-jdk-slim

ARG ARTIFACT_URL
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Скачиваем JAR напрямую из репозитория артефактов во время сборки образа
RUN test -n "$ARTIFACT_URL" || (echo "ARTIFACT_URL build-arg is required" && exit 1)
RUN echo "Downloading JAR from $ARTIFACT_URL" \
    && curl -fsSL "$ARTIFACT_URL" -o app.jar \
    && test -s app.jar

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
