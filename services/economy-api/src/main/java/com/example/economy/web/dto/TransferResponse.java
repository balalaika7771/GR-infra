package com.example.economy.web.dto;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Ответ на перевод денег между игроками.
 */
public class TransferResponse {
    private UUID transactionId;
    private String fromUserId;
    private String toUserId;
    private BigDecimal amount;
    private BigDecimal fromBalance;
    private BigDecimal toBalance;
    private String message;

    public TransferResponse() {}

    public TransferResponse(UUID transactionId, String fromUserId, String toUserId, 
                          BigDecimal amount, BigDecimal fromBalance, BigDecimal toBalance, String message) {
        this.transactionId = transactionId;
        this.fromUserId = fromUserId;
        this.toUserId = toUserId;
        this.amount = amount;
        this.fromBalance = fromBalance;
        this.toBalance = toBalance;
        this.message = message;
    }

    public UUID getTransactionId() {
        return transactionId;
    }

    public void setTransactionId(UUID transactionId) {
        this.transactionId = transactionId;
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

    public BigDecimal getFromBalance() {
        return fromBalance;
    }

    public void setFromBalance(BigDecimal fromBalance) {
        this.fromBalance = fromBalance;
    }

    public BigDecimal getToBalance() {
        return toBalance;
    }

    public void setToBalance(BigDecimal toBalance) {
        this.toBalance = toBalance;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
