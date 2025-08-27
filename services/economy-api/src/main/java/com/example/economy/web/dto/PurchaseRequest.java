package com.example.economy.web.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Positive;

/**
 * Запрос на покупку предмета.
 */
public record PurchaseRequest(
    @NotBlank String userId,
    @NotBlank String itemId,
    @NotNull @Positive Integer quantity
) {}
