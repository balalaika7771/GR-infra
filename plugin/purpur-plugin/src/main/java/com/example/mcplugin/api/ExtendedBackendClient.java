package com.example.mcplugin.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import java.io.IOException;

/**
 * Упрощенный HTTP клиент для взаимодействия с economy-api.
 */
public class ExtendedBackendClient {
    private final OkHttpClient client;
    private final ObjectMapper mapper;
    private final String economyUrl;
    
    public ExtendedBackendClient(String economyUrl) {
        this.economyUrl = economyUrl;
        this.client = new OkHttpClient();
        this.mapper = new ObjectMapper();
    }
    
    /**
     * Инициализирует учетную запись игрока на бэке: создаёт кошелек с 100 монетами, если его ещё нет.
     * Использует имя пользователя вместо UUID для стабильности в offline режиме.
     */
    public void ensurePlayerInitialized(String playerName) throws IOException {
        var httpRequest = new Request.Builder()
            .url(economyUrl + "/api/economy/ensure-wallet/" + playerName)
            .post(RequestBody.create("", null)) // POST с пустым телом
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Init failed: " + response.code());
            }
        }
    }
    
    /**
     * Получает баланс игрока.
     * Использует имя пользователя вместо UUID для стабильности в offline режиме.
     */
    public BalanceResponse getBalance(String playerName) throws IOException {
        var httpRequest = new Request.Builder()
            .url(economyUrl + "/api/economy/balance/" + playerName)
            .get()
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Failed to get balance: " + response.code());
            }
            
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            
            String responseText = responseBody.string();
            // Парсим ответ вида "Balance: 100.0" или "Balance (from Redis cache): 100.0"
            String balanceStr = responseText.replaceAll(".*Balance.*: ", "").replaceAll(" \\(.*\\)", "");
            double balance = Double.parseDouble(balanceStr);
            
            return new BalanceResponse(playerName, balance, "COINS");
        }
    }

    /**
     * Переводит деньги от одного игрока к другому.
     */
    public TransferResponse transferMoney(String fromPlayer, String toPlayer, double amount, String description) throws IOException {
        var transferRequest = new TransferRequest(fromPlayer, toPlayer, amount, description);
        String jsonRequest = mapper.writeValueAsString(transferRequest);
        
        var httpRequest = new Request.Builder()
            .url(economyUrl + "/api/economy/transfer")
            .post(RequestBody.create(jsonRequest, MediaType.parse("application/json")))
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Transfer failed: " + response.code());
            }
            
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            
            String responseText = responseBody.string();
            return mapper.readValue(responseText, TransferResponse.class);
        }
    }
    
    // Record classes for responses
    public record BalanceResponse(String userId, double balance, String currency) {}
    
    public record TransferRequest(String fromUserId, String toUserId, double amount, String description) {}
    
    public record TransferResponse(String transactionId, String fromUserId, String toUserId, 
                                 double amount, double fromBalance, double toBalance, String message) {}
}
