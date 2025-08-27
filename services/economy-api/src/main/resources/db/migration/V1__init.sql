-- Создание таблицы кошельков
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE,
    balance DECIMAL(19,4) NOT NULL DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Создание таблицы транзакций
CREATE TABLE IF NOT EXISTS tx_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    type VARCHAR(50) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_tx_ledger_user_id ON tx_ledger(user_id);
CREATE INDEX IF NOT EXISTS idx_tx_ledger_created_at ON tx_ledger(created_at);

-- Добавляем начальный баланс для тестирования
INSERT INTO wallets (user_id, balance) VALUES 
    ('550e8400-e29b-41d4-a716-446655440000', 1000.00)
ON CONFLICT (user_id) DO NOTHING;
