package com.example.mcplugin;

import com.example.mcplugin.api.ExtendedBackendClient;
import com.example.mcplugin.commands.DemoCommands;
import com.example.mcplugin.config.PluginConfig;
import com.example.mcplugin.listeners.PlayerJoinListener;
import com.example.mcplugin.listeners.ResourcePackListener;
import org.bukkit.plugin.java.JavaPlugin;

/**
 * Упрощенный плагин с экономикой и Redis кэшированием.
 */
public class MainPlugin extends JavaPlugin {
    
    private ExtendedBackendClient backendClient;
    
    @Override
    public void onEnable() {
        // Загружаем конфигурацию
        saveDefaultConfig();
        var config = new PluginConfig(getConfig());
        
        // Инициализируем API клиент для экономики
        backendClient = new ExtendedBackendClient(config.getEconomyUrl());
        
        // Регистрируем команды
        registerCommands();
        
        // Регистрируем слушатели событий
        registerListeners(config);
        
        getLogger().info("Economy plugin enabled successfully!");
    }
    
    private void registerCommands() {
        var demoCommands = new DemoCommands(this, backendClient);
        
        getCommand("balance").setExecutor(demoCommands);
        getCommand("transfer").setExecutor(demoCommands);
    }
    
    private void registerListeners(PluginConfig config) {
        var playerJoinListener = new PlayerJoinListener(this, backendClient);
        getServer().getPluginManager().registerEvents(playerJoinListener, this);

        var resourcePackListener = new ResourcePackListener(this, config);
        getServer().getPluginManager().registerEvents(resourcePackListener, this);
    }
    
    @Override
    public void onDisable() {
        getLogger().info("Economy plugin disabled successfully!");
    }
    
    public ExtendedBackendClient getBackendClient() {
        return backendClient;
    }
}
