package com.example.mcplugin.listeners;

import com.example.mcplugin.api.ExtendedBackendClient;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.plugin.Plugin;

import java.io.IOException;
import java.util.logging.Logger;

/**
 * Слушатель событий входа игроков для автоматического создания кошельков.
 */
public class PlayerJoinListener implements Listener {
    
    private final Plugin plugin;
    private final ExtendedBackendClient backendClient;
    private final Logger logger;
    
    public PlayerJoinListener(Plugin plugin, ExtendedBackendClient backendClient) {
        this.plugin = plugin;
        this.backendClient = backendClient;
        this.logger = plugin.getLogger();
    }
    
    @EventHandler
    public void onPlayerJoin(PlayerJoinEvent event) {
        String playerName = event.getPlayer().getName();
        String playerUuid = event.getPlayer().getUniqueId().toString();
        
        logger.info("Игрок " + playerName + " (" + playerUuid + ") зашел на сервер");
        
        // Асинхронно создаем кошелек для игрока
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                // Создаем кошелек с 100 монетами, если его нет
                backendClient.ensurePlayerInitialized(playerUuid);
                logger.info("Кошелек для игрока " + playerName + " создан/проверен");
                
            } catch (IOException e) {
                logger.warning("Ошибка при создании кошелька для игрока " + playerName + ": " + e.getMessage());
            }
        });
    }
}
