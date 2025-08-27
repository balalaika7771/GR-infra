FROM openjdk:21-jre-slim

# Устанавливаем необходимые пакеты
RUN apt-get update && apt-get install -y \
    curl \
    netcat \
    && rm -rf /var/lib/apt/lists/*

# Создаем пользователя minecraft
RUN useradd -r -m -U -d /minecraft -s /bin/bash minecraft

# Создаем директории
RUN mkdir -p /minecraft/plugins /minecraft/logs
RUN chown -R minecraft:minecraft /minecraft

# Копируем плагин
COPY purpur-plugin-1.0.0.jar /minecraft/plugins/

# Переключаемся на пользователя minecraft
USER minecraft
WORKDIR /minecraft

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# Expose port
EXPOSE 8080

# Default command
CMD ["java", "-jar", "/minecraft/plugins/purpur-plugin-1.0.0.jar"]


