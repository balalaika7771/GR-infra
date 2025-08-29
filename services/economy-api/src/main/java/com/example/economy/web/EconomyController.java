package com.example.economy.web;

import com.example.economy.service.PurchaseService;
import com.example.economy.repo.WalletRepository;
import com.example.economy.model.Wallet;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

/**
 * Упрощенный REST API для экономики с Redis кэшированием.
 */
@RestController
@RequestMapping("/api/economy")
@Tag(name = "Economy API", description = "API для экономики с Redis кэшированием")
public class EconomyController {
    
    private final PurchaseService purchaseService;
    private final StringRedisTemplate redisTemplate;
    private final WalletRepository walletRepo;
    
    public EconomyController(PurchaseService purchaseService, StringRedisTemplate redisTemplate, WalletRepository walletRepo) {
        this.purchaseService = purchaseService;
        this.redisTemplate = redisTemplate;
        this.walletRepo = walletRepo;
    }
    
    @PostMapping("/ensure-wallet/{userId}")
    @Operation(summary = "Обеспечить кошелек игрока", description = "Создает кошелек для игрока с 100 монетами, если его нет")
    public ResponseEntity<String> ensurePlayerWallet(@PathVariable("userId") String userId) {
        try {
            UUID uuid = UUID.fromString(userId);
            
            // Создаем или получаем кошелек пользователя
            Wallet wallet = walletRepo.findByUserId(uuid).orElseGet(() -> {
                var w = new Wallet();
                w.setUserId(uuid);
                w.setBalance(BigDecimal.valueOf(100)); // Начальный баланс 100 монет
                return walletRepo.save(w);
            });
            
            // Кэшируем баланс в Redis на 5 минут
            String cacheKey = "balance:" + userId;
            redisTemplate.opsForValue().set(cacheKey, String.valueOf(wallet.getBalance()), 5, TimeUnit.MINUTES);
            
            return ResponseEntity.ok("Wallet ensured with balance: " + wallet.getBalance() + " (cached in Redis)");
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("Invalid UUID format");
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Failed to ensure wallet: " + e.getMessage());
        }
    }
    
    @GetMapping("/balance/{userId}")
    @Operation(summary = "Получить баланс игрока", description = "Возвращает баланс кошелька игрока (с Redis кэшированием)")
    public ResponseEntity<String> getPlayerBalance(@PathVariable("userId") String userId) {
        try {
            UUID uuid = UUID.fromString(userId);
            
            // Сначала проверяем Redis кэш
            String cacheKey = "balance:" + userId;
            String cachedBalance = redisTemplate.opsForValue().get(cacheKey);
            
            if (cachedBalance != null) {
                return ResponseEntity.ok("Balance (from Redis cache): " + cachedBalance);
            }
            
            // Если в кэше нет, получаем из базы
            var balance = purchaseService.getWalletBalance(uuid);
            
            // Кэшируем результат на 5 минут
            redisTemplate.opsForValue().set(cacheKey, String.valueOf(balance), 5, TimeUnit.MINUTES);
            
            return ResponseEntity.ok("Balance (from database): " + balance + " (now cached)");
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("Invalid UUID format");
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Failed to get balance: " + e.getMessage());
        }
    }
    
    @DeleteMapping("/cache/clear/{userId}")
    @Operation(summary = "Очистить кэш игрока", description = "Удаляет кэшированный баланс игрока из Redis")
    public ResponseEntity<String> clearPlayerCache(@PathVariable("userId") String userId) {
        try {
            String cacheKey = "balance:" + userId;
            Boolean deleted = redisTemplate.delete(cacheKey);
            
            if (deleted != null && deleted) {
                return ResponseEntity.ok("Cache cleared for player: " + userId);
            } else {
                return ResponseEntity.ok("No cache found for player: " + userId);
            }
            
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Failed to clear cache: " + e.getMessage());
        }
    }
    
    @GetMapping("/cache/stats")
    @Operation(summary = "Статистика кэша", description = "Показывает количество ключей в Redis")
    public ResponseEntity<String> getCacheStats() {
        try {
            Long keyCount = redisTemplate.getConnectionFactory().getConnection().dbSize();
            return ResponseEntity.ok("Redis cache contains " + keyCount + " keys");
            
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Failed to get cache stats: " + e.getMessage());
        }
    }
}
