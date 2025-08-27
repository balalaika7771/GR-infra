package com.example.mcplugin.commands;

import com.example.mcplugin.MainPlugin;
import com.example.mcplugin.api.ExtendedBackendClient;
import com.example.mcplugin.nms.NMSUtils;
import org.bukkit.Material;
import org.bukkit.command.Command;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.CommandSender;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import org.bukkit.ChatColor;

/**
 * Демонстрационные команды для показа функциональности плагина.
 */
public class DemoCommands implements CommandExecutor {
    
    private final MainPlugin plugin;
    private final ExtendedBackendClient backendClient;
    
    public DemoCommands(MainPlugin plugin, ExtendedBackendClient backendClient) {
        this.plugin = plugin;
        this.backendClient = backendClient;
    }
    
    @Override
    public boolean onCommand(CommandSender sender, Command command, String label, String[] args) {
        if (!(sender instanceof Player player)) {
            sender.sendMessage(ChatColor.RED + "Эта команда только для игроков!");
            return true;
        }
        
        switch (command.getName().toLowerCase()) {
            case "balance":
                return handleBalance(player, args);
            case "transfer":
                return handleTransfer(player, args);
            case "customitem":
                return handleCustomItem(player, args);
            case "ping":
                return handlePing(player);
            case "auth":
                return handleAuth(player, args);
            default:
                return false;
        }
    }
    
    private boolean handleBalance(Player player, String[] args) {
        try {
            String userId = args.length > 0 ? args[0] : player.getUniqueId().toString();
            var balance = backendClient.getBalance(userId);
            
            player.sendMessage(ChatColor.GREEN + "Баланс игрока " + userId + ": " + 
                            ChatColor.GOLD + balance.balance() + " " + balance.currency());
        } catch (Exception e) {
            player.sendMessage(ChatColor.RED + "Ошибка получения баланса: " + e.getMessage());
        }
        return true;
    }
    
    private boolean handleTransfer(Player player, String[] args) {
        if (args.length < 2) {
            player.sendMessage(ChatColor.RED + "Использование: /transfer <игрок> <сумма>");
            return true;
        }
        
        try {
            String toPlayer = args[0];
            double amount = Double.parseDouble(args[1]);
            
            var transfer = backendClient.transfer(
                player.getUniqueId().toString(), 
                toPlayer, 
                amount
            );
            
            player.sendMessage(ChatColor.GREEN + "Перевод выполнен! ID транзакции: " + 
                            ChatColor.GOLD + transfer.transactionId());
        } catch (Exception e) {
            player.sendMessage(ChatColor.RED + "Ошибка перевода: " + e.getMessage());
        }
        return true;
    }
    
    private boolean handleCustomItem(Player player, String[] args) {
        if (args.length < 1) {
            player.sendMessage(ChatColor.RED + "Использование: /customitem <название> [описание...]");
            return true;
        }
        
        String itemName = args[0];
        String[] lore = new String[args.length - 1];
        System.arraycopy(args, 1, lore, 0, args.length - 1);
        
        // Создаем кастомный предмет
        ItemStack customItem = NMSUtils.createCustomItem(
            new ItemStack(Material.DIAMOND), 
            ChatColor.translateAlternateColorCodes('&', itemName),
            lore
        );
        
        // Добавляем кастомные данные
        NMSUtils.setCustomData(customItem, "owner", player.getName());
        NMSUtils.setCustomData(customItem, "created", String.valueOf(System.currentTimeMillis()));
        
        player.getInventory().addItem(customItem);
        player.sendMessage(ChatColor.GREEN + "Вы получили кастомный предмет!");
        
        return true;
    }
    
    private boolean handlePing(Player player) {
        int ping = NMSUtils.getPlayerPing(player);
        if (ping >= 0) {
            player.sendMessage(ChatColor.GREEN + "Ваш ping: " + ChatColor.GOLD + ping + "ms");
        } else {
            player.sendMessage(ChatColor.RED + "Не удалось получить ping");
        }
        return true;
    }
    
    private boolean handleAuth(Player player, String[] args) {
        player.sendMessage(ChatColor.YELLOW + "Авторизация не требуется!");
        player.sendMessage(ChatColor.GREEN + "Вы используете официальный лицензионный аккаунт Mojang.");
        player.sendMessage(ChatColor.GREEN + "Ваш UUID: " + ChatColor.GOLD + player.getUniqueId());
        player.sendMessage(ChatColor.GREEN + "Ваше имя: " + ChatColor.GOLD + player.getName());
        
        // Показываем текущий баланс
        try {
            var balance = backendClient.getBalance(player.getUniqueId().toString());
            player.sendMessage(ChatColor.GREEN + "Ваш баланс: " + 
                            ChatColor.GOLD + balance.balance() + " " + balance.currency());
        } catch (Exception e) {
            player.sendMessage(ChatColor.RED + "Ошибка получения баланса: " + e.getMessage());
        }
        
        return true;
    }
}
