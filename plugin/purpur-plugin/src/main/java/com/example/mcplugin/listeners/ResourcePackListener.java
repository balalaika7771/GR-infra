package com.example.mcplugin.listeners;

import com.example.mcplugin.config.PluginConfig;
import net.kyori.adventure.text.Component;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerResourcePackStatusEvent;
import org.bukkit.plugin.Plugin;

import java.util.logging.Logger;

/**
 * Отправка ресурс-пака при входе и обработка статусов загрузки.
 */
public class ResourcePackListener implements Listener {

    private final Plugin plugin;
    private final PluginConfig config;
    private final Logger logger;

    public ResourcePackListener(Plugin plugin, PluginConfig config) {
        this.plugin = plugin;
        this.config = config;
        this.logger = plugin.getLogger();
    }

    @EventHandler
    public void onPlayerJoin(PlayerJoinEvent event) {
        String url = config.getResourcePackUrl();
        if (url == null || url.isBlank()) {
            return;
        }

        Player player = event.getPlayer();

        boolean required = config.isResourcePackRequired();
        Component prompt = Component.text(config.getResourcePackPrompt());
        String sha1 = config.getResourcePackSha1();

        try {
            if (sha1 != null && !sha1.isBlank()) {
                player.setResourcePack(url, sha1, required, prompt);
            } else {
                // Без SHA1 тоже допустимо, но хуже кэш
                player.setResourcePack(url, required, prompt);
            }
            logger.info("Отправлен ресурс-пак игроку " + player.getName());
        } catch (Throwable t) {
            logger.warning("Не удалось отправить ресурс-пак игроку " + player.getName() + ": " + t.getMessage());
        }
    }

    @EventHandler
    public void onResourcePackStatus(PlayerResourcePackStatusEvent event) {
        Player player = event.getPlayer();
        boolean required = config.isResourcePackRequired();
        switch (event.getStatus()) {
            case DECLINED -> {
                logger.info("Игрок " + player.getName() + " отклонил ресурс-пак");
                if (required) {
                    player.kick(Component.text(config.getResourcePackKickMessage()));
                }
            }
            case FAILED_DOWNLOAD -> {
                logger.info("У игрока " + player.getName() + " не удалось скачать ресурс-пак");
                if (required) {
                    player.kick(Component.text(config.getResourcePackKickMessage()));
                }
            }
            case SUCCESSFULLY_LOADED -> logger.info("Игрок " + player.getName() + " успешно загрузил ресурс-пак");
            case ACCEPTED -> logger.info("Игрок " + player.getName() + " принял ресурс-пак, ожидание загрузки");
        }
    }
}


