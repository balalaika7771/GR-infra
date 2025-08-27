package com.example.economy.service;

import com.example.economy.events.RedisPublisher;
import com.example.economy.model.TxLedger;
import com.example.economy.model.Wallet;
import com.example.economy.repo.TxLedgerRepository;
import com.example.economy.repo.WalletRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.Optional;
import java.util.UUID;

/**
 * Логика покупки: создание транзакций и обновление баланса кошелька.
 */
@Service
@Transactional
public class PurchaseService {
    private final WalletRepository walletRepo;
    private final TxLedgerRepository ledgerRepo;
    private final RedisPublisher publisher;

    public PurchaseService(WalletRepository walletRepo, TxLedgerRepository ledgerRepo, RedisPublisher publisher) {
        this.walletRepo = walletRepo;
        this.ledgerRepo = ledgerRepo;
        this.publisher = publisher;
    }

    public TxLedger processPurchase(UUID userId, String itemId, Integer quantity) {
        // Создаем или получаем кошелек пользователя
        Wallet wallet = walletRepo.findById(userId).orElseGet(() -> {
            var w = new Wallet();
            w.setUserId(userId);
            return walletRepo.save(w);
        });
        
        // Простая логика: каждая покупка стоит 10 монет
        BigDecimal amount = BigDecimal.valueOf(10 * quantity);
        
        // Проверяем баланс
        if (wallet.getBalance().compareTo(amount) < 0) {
            throw new IllegalStateException("Insufficient funds");
        }
        
        // Списываем средства
        wallet.setBalance(wallet.getBalance().subtract(amount));
        walletRepo.save(wallet);
        
        // Создаем транзакцию
        var tx = new TxLedger();
        tx.setUserId(userId);
        tx.setType(TxLedger.TransactionType.PURCHASE);
        tx.setAmount(amount);
        tx.setDescription("Purchase: " + itemId + " x" + quantity);
        
        var savedTx = ledgerRepo.save(tx);
        
        // Публикуем событие
        publisher.publish("purchase:confirmed", userId + ":" + itemId + ":" + savedTx.getId());
        
        return savedTx;
    }
    
    /**
     * Получает баланс кошелька пользователя.
     * ВНИМАНИЕ: Этот метод предназначен только для разработки и тестирования!
     */
    public BigDecimal getWalletBalance(UUID userId) {
        Optional<Wallet> wallet = walletRepo.findById(userId);
        return wallet.map(Wallet::getBalance).orElse(BigDecimal.ZERO);
    }
}
