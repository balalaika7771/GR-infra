package com.example.mcplugin.config;

import org.bukkit.configuration.file.FileConfiguration;

/**
 * Конфигурация плагина экономики.
 */
public class PluginConfig {
    private final FileConfiguration config;
    
    public PluginConfig(FileConfiguration config) {
        this.config = config;
    }
    
    public String getEconomyUrl() {
        return config.getString("economy.url", "http://economy-api:8080");
    }
}
