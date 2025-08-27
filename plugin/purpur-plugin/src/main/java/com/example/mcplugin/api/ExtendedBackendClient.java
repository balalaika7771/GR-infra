package com.example.mcplugin.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import java.io.IOException;
import java.util.List;

/**
 * Расширенный HTTP клиент для взаимодействия с auth-bridge и economy-api.
 */
public class ExtendedBackendClient {
    private final OkHttpClient client;
    private final ObjectMapper mapper;
    private final String authUrl;
    private final String economyUrl;
    
    public ExtendedBackendClient(String authUrl, String economyUrl) {
        this.authUrl = authUrl; // может быть null
        this.economyUrl = economyUrl;
        this.client = new OkHttpClient();
        this.mapper = new ObjectMapper();
    }
    
    // Auth Bridge API (отключено - используем Mojang UUID)
    public AuthResponse authenticate(String username, String password) throws IOException {
        if (authUrl == null) {
            throw new IOException("Auth-bridge не доступен - используем Mojang UUID");
        }
        
        var request = new AuthRequest(username, password);
        var json = mapper.writeValueAsString(request);
        
        var body = RequestBody.create(json, MediaType.get("application/json"));
        var httpRequest = new Request.Builder()
            .url(authUrl + "/api/auth/login")
            .post(body)
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Authentication failed: " + response.code());
            }
            
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            
            return mapper.readValue(responseBody.string(), AuthResponse.class);
        }
    }
    
    public UserProfile getUserProfile(String token) throws IOException {
        if (authUrl == null) {
            throw new IOException("Auth-bridge не доступен - используем Mojang UUID");
        }
        
        var httpRequest = new Request.Builder()
            .url(authUrl + "/api/auth/profile")
            .addHeader("Authorization", "Bearer " + token)
            .get()
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Failed to get user profile: " + response.code());
            }
            
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            
            return mapper.readValue(responseBody.string(), UserProfile.class);
        }
    }
    
    // Economy API
    public BalanceResponse getBalance(String userId) throws IOException {
        // Сначала пробуем получить список кошельков и найти нужный
        var listRequest = new Request.Builder()
            .url(economyUrl + "/api/test/wallets")
            .get()
            .build();
        
        try (var response = client.newCall(listRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Failed to list wallets: " + response.code());
            }
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            var walletsJson = responseBody.string();
            List<Wallet> wallets = mapper.readerForListOf(Wallet.class).readValue(walletsJson);
            for (Wallet w : wallets) {
                if (userId.equalsIgnoreCase(w.userId())) {
                    return new BalanceResponse(w.userId(), w.balance(), "COINS");
                }
            }
        }
        
                    // Если кошелек не найден — возвращаем баланс 0 вместо попытки создания
            return new BalanceResponse(userId, 0.0, "COINS");
    }
    
    public TransactionResponse transfer(String fromUserId, String toUserId, double amount) throws IOException {
        var request = new TransferRequest(fromUserId, toUserId, amount);
        var json = mapper.writeValueAsString(request);
        
        var body = RequestBody.create(json, MediaType.get("application/json"));
        var httpRequest = new Request.Builder()
            .url(economyUrl + "/api/transfer")
            .post(body)
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Transfer failed: " + response.code());
            }
            
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            
            return mapper.readValue(responseBody.string(), TransactionResponse.class);
        }
    }
    
            /**
         * Инициализирует учетную запись игрока на бэке: создаёт кошелек, если его ещё нет.
         * Использует эндпоинт /api/purchases/ensure-wallet/{userId}
         */
        public void ensurePlayerInitialized(String userId) throws IOException {
            var httpRequest = new Request.Builder()
                .url(economyUrl + "/api/purchases/ensure-wallet/" + userId)
                .post(RequestBody.create("", null)) // POST с пустым телом
                .build();
            
            try (var response = client.newCall(httpRequest).execute()) {
                if (!response.isSuccessful()) {
                    throw new IOException("Init failed: " + response.code());
                }
            }
        }
    
    // Record classes for requests/responses
    public record AuthRequest(String username, String password) {}
    public record AuthResponse(String token, String userId, String message) {}
    public record UserProfile(String userId, String username, String email, String role) {}
    public record BalanceResponse(String userId, double balance, String currency) {}
    public record TransferRequest(String fromUserId, String toUserId, double amount) {}
    public record TransactionResponse(String transactionId, String fromUserId, String toUserId, double amount, String status) {}

    public record Wallet(String id, String userId, double balance, String createdAt, String updatedAt) {}
}
