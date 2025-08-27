package com.example.economy.web;

import com.example.economy.service.PurchaseService;
import com.example.economy.web.dto.PurchaseRequest;
import com.example.economy.web.dto.PurchaseAcceptedResponse;
import com.example.economy.events.RedisPublisher;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.UUID;

/**
 * REST API для покупок.
 */
@RestController
@RequestMapping("/api/purchases")
@Tag(name = "Purchase API", description = "API для покупок и экономики")
public class PurchaseController {
    
    private final PurchaseService purchaseService;
    private final RedisPublisher redisPublisher;
    
    public PurchaseController(PurchaseService purchaseService, RedisPublisher redisPublisher) {
        this.purchaseService = purchaseService;
        this.redisPublisher = redisPublisher;
    }
    
    @PostMapping
    @Operation(summary = "Создать покупку", description = "Создает новую покупку для пользователя")
    public ResponseEntity<PurchaseAcceptedResponse> createPurchase(@Valid @RequestBody PurchaseRequest req) {
        UUID userId = UUID.fromString(req.userId());
        
        var transaction = purchaseService.processPurchase(userId, req.itemId(), req.quantity());
        
        var response = new PurchaseAcceptedResponse(
            transaction.getId().toString(),
            transaction.getAmount(),
            transaction.getCreatedAt()
        );
        
        return ResponseEntity.ok(response);
    }
    
    @PostMapping("/ensure-wallet/{userId}")
    @Operation(summary = "Обеспечить кошелек игрока", description = "Создает кошелек для игрока, если его нет, или возвращает существующий")
    public ResponseEntity<String> ensurePlayerWallet(@PathVariable("userId") String userId) {
        try {
            UUID uuid = UUID.fromString(userId);
            
            // Получаем баланс - если кошелек не существует, он будет создан автоматически
            var balance = purchaseService.getWalletBalance(uuid);
            return ResponseEntity.ok("Wallet ensured with balance: " + balance);
            
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("Invalid UUID format");
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Failed to ensure wallet: " + e.getMessage());
        }
    }
    
    @GetMapping("/health")
    @Operation(summary = "Проверка здоровья", description = "Проверяет работоспособность сервиса")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Economy API is running!");
    }
    
    @GetMapping("/test-wallet/{userId}")
    @Operation(summary = "Тест кошелька", description = "Проверяет баланс кошелька пользователя (только для разработки)")
    public ResponseEntity<String> testWallet(@PathVariable String userId) {
        try {
            UUID uuid = UUID.fromString(userId);
            // В продакшене этот эндпоинт должен быть отключен
            var wallet = purchaseService.getWalletBalance(uuid);
            return ResponseEntity.ok("Wallet balance: " + wallet);
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body("Invalid UUID format");
        }
    }
    
    @PostMapping("/test-redis")
    @Operation(summary = "Тест Redis", description = "Отправляет тестовое сообщение в Redis (только для разработки)")
    public ResponseEntity<String> testRedis() {
        try {
            String testMessage = "Test message from Economy API at " + System.currentTimeMillis();
            redisPublisher.publish("test:channel", testMessage);
            return ResponseEntity.ok("Test message sent to Redis: " + testMessage);
        } catch (Exception e) {
            return ResponseEntity.internalServerError().body("Redis test failed: " + e.getMessage());
        }
    }
}
