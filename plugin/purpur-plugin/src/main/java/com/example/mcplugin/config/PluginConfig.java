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

    public String getResourcePackUrl() {
        return config.getString("resourcePack.url", "");
    }

    public String getResourcePackSha1() {
        return config.getString("resourcePack.sha1", "");
    }

    public boolean isResourcePackRequired() {
        return config.getBoolean("resourcePack.require", true);
    }

    public String getResourcePackPrompt() {
        return config.getString("resourcePack.prompt", "Для игры на сервере требуется установить ресурс-пак");
    }

    public String getResourcePackKickMessage() {
        return config.getString("resourcePack.kickMessage", "Для входа необходимо принять ресурс-пак. Перезапустите и согласитесь.");
    }
}
