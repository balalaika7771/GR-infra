package com.example.mcplugin.listeners;

import com.example.mcplugin.api.ExtendedBackendClient;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.plugin.Plugin;

import java.io.IOException;
import java.util.logging.Logger;

/**
 * Слушатель событий входа игроков для автоматического создания записей.
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
        
        // Асинхронно создаем запись для игрока
        plugin.getServer().getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                // 1) Гарантируем инициализацию на бэке (создание кошелька при отсутствии)
                backendClient.ensurePlayerInitialized(playerUuid);
                
                // Проверяем, есть ли уже кошелек у игрока
                var balance = backendClient.getBalance(playerUuid);
                logger.info("Игрок " + playerName + " имеет баланс: " + balance.balance());
                
            } catch (IOException e) {
                logger.warning("Ошибка при получении баланса для игрока " + playerName + ": " + e.getMessage());
            }
        });
    }
}
