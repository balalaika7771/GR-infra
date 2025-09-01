package com.example.economy.service;

import com.example.economy.events.RedisPublisher;
import com.example.economy.model.TxLedger;
import com.example.economy.model.Wallet;
import com.example.economy.repo.TxLedgerRepository;
import com.example.economy.repo.WalletRepository;
import com.example.economy.web.dto.TransferRequest;
import com.example.economy.web.dto.TransferResponse;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Сервис для переводов денег между игроками.
 */
@Service
@Transactional
public class TransferService {
    private final WalletRepository walletRepo;
    private final TxLedgerRepository ledgerRepo;
    private final RedisPublisher publisher;

    public TransferService(WalletRepository walletRepo, TxLedgerRepository ledgerRepo, RedisPublisher publisher) {
        this.walletRepo = walletRepo;
        this.ledgerRepo = ledgerRepo;
        this.publisher = publisher;
    }

    /**
     * Выполняет перевод денег от одного игрока к другому.
     */
    public TransferResponse transferMoney(TransferRequest request) {
        // Валидация входных данных
        if (request.getAmount().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Amount must be positive");
        }

        if (request.getFromUserId().equals(request.getToUserId())) {
            throw new IllegalArgumentException("Cannot transfer to yourself");
        }

        // Получаем кошельки игроков
        UUID fromUserId = UUID.fromString(request.getFromUserId());
        UUID toUserId = UUID.fromString(request.getToUserId());

        Wallet fromWallet = walletRepo.findByUserId(fromUserId)
            .orElseThrow(() -> new IllegalStateException("Sender wallet not found"));
        
        Wallet toWallet = walletRepo.findByUserId(toUserId)
            .orElseGet(() -> {
                var w = new Wallet();
                w.setUserId(toUserId);
                w.setBalance(BigDecimal.ZERO);
                return walletRepo.save(w);
            });

        // Проверяем баланс отправителя
        if (fromWallet.getBalance().compareTo(request.getAmount()) < 0) {
            throw new IllegalStateException("Insufficient funds");
        }

        // Выполняем перевод
        fromWallet.setBalance(fromWallet.getBalance().subtract(request.getAmount()));
        toWallet.setBalance(toWallet.getBalance().add(request.getAmount()));

        // Сохраняем обновленные кошельки
        walletRepo.save(fromWallet);
        walletRepo.save(toWallet);

        // Создаем транзакции для обоих игроков
        var fromTx = new TxLedger();
        fromTx.setUserId(fromUserId);
        fromTx.setType(TxLedger.TransactionType.TRANSFER);
        fromTx.setAmount(request.getAmount().negate()); // Отрицательная сумма для отправителя
        fromTx.setDescription("Transfer to " + request.getToUserId() + ": " + request.getDescription());

        var toTx = new TxLedger();
        toTx.setUserId(toUserId);
        toTx.setType(TxLedger.TransactionType.TRANSFER);
        toTx.setAmount(request.getAmount()); // Положительная сумма для получателя
        toTx.setDescription("Transfer from " + request.getFromUserId() + ": " + request.getDescription());

        // Сохраняем транзакции
        var savedFromTx = ledgerRepo.save(fromTx);
        var savedToTx = ledgerRepo.save(toTx);

        // Публикуем событие
        publisher.publish("transfer:completed", 
            fromUserId + ":" + toUserId + ":" + request.getAmount() + ":" + savedFromTx.getId());

        // Очищаем кэш Redis для обоих игроков
        publisher.publish("cache:clear", "balance:" + fromUserId);
        publisher.publish("cache:clear", "balance:" + toUserId);

        return new TransferResponse(
            savedFromTx.getId(),
            request.getFromUserId(),
            request.getToUserId(),
            request.getAmount(),
            fromWallet.getBalance(),
            toWallet.getBalance(),
            "Transfer completed successfully"
        );
    }
}
