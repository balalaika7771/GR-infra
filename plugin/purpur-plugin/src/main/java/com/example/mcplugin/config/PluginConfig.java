package com.example.mcplugin.config;

import org.bukkit.configuration.file.FileConfiguration;

/**
 * Конфигурация плагина.
 */
public class PluginConfig {
    private final FileConfiguration config;
    
    public PluginConfig(FileConfiguration config) {
        this.config = config;
    }
    
    // Auth URL больше не нужен - используем Mojang UUID
    // public String getAuthUrl() {
    //     return config.getString("auth.url", "http://auth-bridge:8080");
    // }
    
    public String getEconomyUrl() {
        return config.getString("economy.url", "http://economy-api:8080");
    }
    
    public String getRedisHost() {
        return config.getString("redis.host", "redis");
    }
    
    public int getRedisPort() {
        return config.getInt("redis.port", 6379);
    }
    
    public int getHealthPort() {
        return config.getInt("health.port", 8080);
    }
}
