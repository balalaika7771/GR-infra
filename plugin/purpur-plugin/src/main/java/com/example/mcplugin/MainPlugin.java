package com.example.mcplugin;

import com.example.mcplugin.api.ExtendedBackendClient;
import com.example.mcplugin.commands.DemoCommands;
import com.example.mcplugin.config.PluginConfig;
import com.example.mcplugin.redis.RedisSubscriber;
import com.example.mcplugin.nms.NMSUtils;
import com.example.mcplugin.listeners.PlayerJoinListener;
import org.bukkit.plugin.java.JavaPlugin;

/**
 * Основной класс плагина с интеграцией NMS и бэкенд сервисов.
 */
public class MainPlugin extends JavaPlugin {
    
    private ExtendedBackendClient backendClient;
    private RedisSubscriber redisSubscriber;
    private HealthHttpServer healthServer;
    
    @Override
    public void onEnable() {
        // Загружаем конфигурацию
        saveDefaultConfig();
        var config = new PluginConfig(getConfig());
        
        // Инициализируем расширенный API клиент (только economy-api)
        backendClient = new ExtendedBackendClient(
            null, // auth-bridge больше не нужен
            config.getEconomyUrl()
        );
        
        redisSubscriber = new RedisSubscriber(config.getRedisHost(), config.getRedisPort());
        
        // Регистрируем команды
        registerCommands();
        
        // Регистрируем слушатели событий
        registerListeners();
        
        // Запускаем health check сервер
        healthServer = new HealthHttpServer(config.getHealthPort());
        healthServer.start();
        
        // Устанавливаем кастомный MOTD
        NMSUtils.setCustomMOTD("§6§lK8s Minecraft Network §7- §aС NMS и API!");
        
        getLogger().info("Plugin enabled successfully with NMS and Backend integration!");
    }
    
    private void registerCommands() {
        var demoCommands = new DemoCommands(this, backendClient);
        
        getCommand("balance").setExecutor(demoCommands);
        getCommand("transfer").setExecutor(demoCommands);
        getCommand("customitem").setExecutor(demoCommands);
        getCommand("ping").setExecutor(demoCommands);
        getCommand("auth").setExecutor(demoCommands);
    }
    
    private void registerListeners() {
        var playerJoinListener = new PlayerJoinListener(this, backendClient);
        getServer().getPluginManager().registerEvents(playerJoinListener, this);
    }
    
    @Override
    public void onDisable() {
        if (healthServer != null) {
            healthServer.stop();
        }
        
        if (redisSubscriber != null) {
            redisSubscriber.close();
        }
        
        getLogger().info("Plugin disabled successfully!");
    }
    
    public ExtendedBackendClient getBackendClient() {
        return backendClient;
    }
    
    public RedisSubscriber getRedisSubscriber() {
        return redisSubscriber;
    }
}
