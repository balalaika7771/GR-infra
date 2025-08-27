package com.example.economy.web.dto;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * Ответ на успешную покупку.
 */
public record PurchaseAcceptedResponse(
    String transactionId,
    BigDecimal amount,
    OffsetDateTime timestamp
) {}
