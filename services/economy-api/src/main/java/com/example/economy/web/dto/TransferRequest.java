package com.example.economy.web.dto;

import java.math.BigDecimal;

/**
 * Запрос на перевод денег между игроками.
 */
public class TransferRequest {
    private String fromUserId;
    private String toUserId;
    private BigDecimal amount;
    private String description;

    public TransferRequest() {}

    public TransferRequest(String fromUserId, String toUserId, BigDecimal amount, String description) {
        this.fromUserId = fromUserId;
        this.toUserId = toUserId;
        this.amount = amount;
        this.description = description;
    }

    public String getFromUserId() {
        return fromUserId;
    }

    public void setFromUserId(String fromUserId) {
        this.fromUserId = fromUserId;
    }

    public String getToUserId() {
        return toUserId;
    }

    public void setToUserId(String toUserId) {
        this.toUserId = toUserId;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }
}
