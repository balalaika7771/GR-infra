package com.example.mcplugin.api;

import com.fasterxml.jackson.databind.ObjectMapper;
import okhttp3.*;
import java.io.IOException;

/**
 * HTTP клиент для взаимодействия с economy-api.
 */
public class BackendClient {
    private final OkHttpClient client;
    private final ObjectMapper mapper;
    private final String baseUrl;
    
    public BackendClient(String baseUrl) {
        this.baseUrl = baseUrl;
        this.client = new OkHttpClient();
        this.mapper = new ObjectMapper();
    }
    
    public String purchase(String userId, String itemId, int quantity) throws IOException {
        var request = new PurchaseRequest(userId, itemId, quantity);
        var json = mapper.writeValueAsString(request);
        
        var body = RequestBody.create(json, MediaType.get("application/json"));
        var httpRequest = new Request.Builder()
            .url(baseUrl + "/api/purchases")
            .post(body)
            .build();
        
        try (var response = client.newCall(httpRequest).execute()) {
            if (!response.isSuccessful()) {
                throw new IOException("Purchase failed: " + response.code());
            }
            
            var responseBody = response.body();
            if (responseBody == null) {
                throw new IOException("Empty response");
            }
            
            var purchaseResponse = mapper.readValue(responseBody.string(), PurchaseAcceptedResponse.class);
            return purchaseResponse.transactionId();
        }
    }
    
    public record PurchaseRequest(String userId, String itemId, Integer quantity) {}
    public record PurchaseAcceptedResponse(String transactionId, String amount, String timestamp) {}
}
