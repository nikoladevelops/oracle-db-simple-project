-- 1. Клиенти с не-БГН сметки
SELECT DISTINCT c.client_id, c.first_name, c.last_name
FROM clients c
JOIN accounts a ON c.client_id = a.client_id
WHERE a.currency <> 'BGN';

-- 2. Клиенти с нулев баланс
SELECT DISTINCT c.client_id, c.first_name, c.last_name
FROM clients c
JOIN accounts a ON c.client_id = a.client_id
WHERE a.balance = 0;

-- 3. Обновяване на account_name
MERGE INTO accounts a
USING clients c
ON (a.client_id = c.client_id)
WHEN MATCHED THEN
  UPDATE SET a.account_name = c.first_name || ' ' || c.last_name || ' сметка ' || a.currency;