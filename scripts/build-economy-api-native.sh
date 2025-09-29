#!/bin/bash

# Скрипт для сборки economy-api с GraalVM Native Image
# Значительно ускоряет запуск приложения

set -e

echo "🚀 Building economy-api with GraalVM Native Image..."

# Переходим в директорию economy-api
cd "$(dirname "$0")/../services/economy-api"

# Проверяем наличие Gradle wrapper
if [ ! -f "./gradlew" ]; then
    echo "❌ Gradle wrapper not found. Please run from economy-api directory."
    exit 1
fi

# Делаем gradlew исполняемым
chmod +x ./gradlew

echo "📦 Building native image..."
./gradlew clean buildNative --no-daemon

echo "🐳 Building Docker image with native binary..."
docker build -t economy-api:native .

echo "✅ Native image build completed!"
echo "📊 Benefits of native image:"
echo "   - ⚡ Startup time: ~50ms (vs ~3-5s for JVM)"
echo "   - 💾 Memory usage: ~50-100MB (vs ~200-500MB for JVM)"
echo "   - 🔋 CPU usage: Lower during startup"
echo "   - 📦 Smaller container size"

echo ""
echo "🔧 To deploy:"
echo "   kubectl set image deployment/economy-api economy-api=economy-api:native -n minecraft"
echo "   # or"
echo "   helm upgrade economy-api ./helm/economy-api --set image.tag=native"
