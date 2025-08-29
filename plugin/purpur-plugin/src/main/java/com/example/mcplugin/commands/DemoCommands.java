package com.example.mcplugin.commands;

import com.example.mcplugin.api.ExtendedBackendClient;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.plugin.Plugin;

import java.io.IOException;
import java.util.logging.Logger;

/**
 * Команды для экономики.
 */
public class DemoCommands implements CommandExecutor {
    
    private final Plugin plugin;
    private final ExtendedBackendClient backendClient;
    private final Logger logger;
    
    public DemoCommands(Plugin plugin, ExtendedBackendClient backendClient) {
        this.plugin = plugin;
        this.backendClient = backendClient;
        this.logger = plugin.getLogger();
    }
    
    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player)) {
            sender.sendMessage("Эта команда только для игроков!");
            return true;
        }
        
        Player player = (Player) sender;
        String playerUuid = player.getUniqueId().toString();
        
        if (command.getName().equalsIgnoreCase("balance")) {
            try {
                var balance = backendClient.getBalance(playerUuid);
                player.sendMessage("§aВаш баланс: §e" + balance.balance() + " монет");
                
            } catch (IOException e) {
                logger.warning("Ошибка при получении баланса для игрока " + player.getName() + ": " + e.getMessage());
                player.sendMessage("§cОшибка при получении баланса!");
            }
            return true;
        }
        
        return false;
    }
}
