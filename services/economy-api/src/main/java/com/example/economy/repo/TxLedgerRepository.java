package com.example.economy.repo;

import com.example.economy.model.TxLedger;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.UUID;

/** Репозиторий журнала транзакций. */
public interface TxLedgerRepository extends JpaRepository<TxLedger, UUID> {
}
