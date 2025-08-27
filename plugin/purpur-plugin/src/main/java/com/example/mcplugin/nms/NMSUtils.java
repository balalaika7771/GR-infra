package com.example.mcplugin.nms;

import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.persistence.PersistentDataContainer;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.NamespacedKey;

import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.UUID;

/**
 * NMS утилиты для продвинутых функций Minecraft.
 */
public class NMSUtils {
    
    /**
     * Получает NMS EntityPlayer объект для игрока.
     */
    public static Object getNMSPlayer(Player player) {
        try {
            Method getHandle = player.getClass().getMethod("getHandle");
            return getHandle.invoke(player);
        } catch (Exception e) {
            // NMS operation failed
            return null;
        }
    }
    
    /**
     * Устанавливает кастомные данные в предмет.
     */
    public static void setCustomData(ItemStack item, String key, String value) {
        ItemMeta meta = item.getItemMeta();
        if (meta != null) {
            PersistentDataContainer container = meta.getPersistentDataContainer();
            NamespacedKey namespacedKey = new NamespacedKey("mcplugin", key);
            container.set(namespacedKey, PersistentDataType.STRING, value);
            item.setItemMeta(meta);
        }
    }
    
    /**
     * Получает кастомные данные из предмета.
     */
    public static String getCustomData(ItemStack item, String key) {
        ItemMeta meta = item.getItemMeta();
        if (meta != null) {
            PersistentDataContainer container = meta.getPersistentDataContainer();
            NamespacedKey namespacedKey = new NamespacedKey("mcplugin", key);
            return container.get(namespacedKey, PersistentDataType.STRING);
        }
        return null;
    }
    
    /**
     * Создает кастомный предмет с NBT данными.
     */
    public static ItemStack createCustomItem(ItemStack baseItem, String customName, String... lore) {
        ItemMeta meta = baseItem.getItemMeta();
        if (meta != null) {
            meta.setDisplayName(customName);
            if (lore.length > 0) {
                meta.setLore(java.util.Arrays.asList(lore));
            }
            
            // Добавляем кастомные данные
            PersistentDataContainer container = meta.getPersistentDataContainer();
            NamespacedKey key = new NamespacedKey("mcplugin", "custom_item");
            container.set(key, PersistentDataType.STRING, UUID.randomUUID().toString());
            
            baseItem.setItemMeta(meta);
        }
        return baseItem;
    }
    
    /**
     * Отправляет кастомный пакет игроку (NMS).
     */
    public static void sendCustomPacket(Player player, Object packet) {
        try {
            // Используем Bukkit API вместо NMS для отправки пакетов
            // В будущем можно добавить ProtocolLib для более продвинутой работы с пакетами
            player.sendMessage(ChatColor.YELLOW + "Отправка кастомных пакетов временно отключена");
        } catch (Exception e) {
            // NMS operation failed
        }
    }
    
    /**
     * Получает ping игрока через NMS.
     */
    public static int getPlayerPing(Player player) {
        try {
            // Используем Bukkit API вместо NMS для получения ping
            return player.getPing();
        } catch (Exception e) {
            // NMS operation failed
        }
        return -1;
    }
    
    /**
     * Устанавливает кастомный MOTD для сервера.
     */
    public static void setCustomMOTD(String motd) {
        try {
            // Используем Bukkit API для установки MOTD
            Bukkit.getServer().setMotd(motd);
        } catch (Exception e) {
            // NMS operation failed
        }
    }
}
