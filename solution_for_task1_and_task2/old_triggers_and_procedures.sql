---------------------------
-- Тригери и процедури
---------------------------

---------------------------
-- 1. Тригер за VIP статус на клиенти
---------------------------
CREATE OR REPLACE TRIGGER trg_accounts_update_status
AFTER INSERT OR UPDATE OR DELETE ON accounts
BEGIN
    FOR client_rec IN (SELECT DISTINCT client_id FROM accounts) 
    LOOP
        DECLARE
            total_balance_bgn NUMBER(15, 2);
        BEGIN
            SELECT SUM(
                CASE 
                    WHEN a.currency = 'BGN' THEN a.balance
                    ELSE a.balance * COALESCE(
                        (SELECT rate FROM (
                            SELECT rate 
                            FROM exchange_rates 
                            WHERE currency_from = a.currency 
                              AND currency_to = 'BGN' 
                              AND effective_date <= SYSDATE
                            ORDER BY effective_date DESC
                        ) WHERE ROWNUM = 1
                        ), 1
                    )
                END
            ) INTO total_balance_bgn
            FROM accounts a
            WHERE a.client_id = client_rec.client_id;

            UPDATE clients
            SET status = CASE 
                            WHEN total_balance_bgn >= 100000 THEN 'VIP клиент'
                            ELSE 'standard'
                         END
            WHERE client_id = client_rec.client_id;
        END;
    END LOOP;
END;
/

---------------------------
-- 2. Тригер за преместване между отдели
---------------------------
CREATE OR REPLACE TRIGGER trg_employee_department_change
AFTER UPDATE OF department_id ON employees
FOR EACH ROW
BEGIN
    INSERT INTO employee_department_movements (
        employee_id, old_department_id, new_department_id, movement_date
    ) VALUES (
        :NEW.employee_id, :OLD.department_id, :NEW.department_id, SYSDATE
    );
END;
/

---------------------------
-- 3. CRUD процедури за сметки
---------------------------

-- Добавяне на сметка
CREATE OR REPLACE PROCEDURE add_account(
    p_client_id IN NUMBER,
    p_account_number IN VARCHAR2,
    p_balance IN NUMBER,
    p_currency IN VARCHAR2,
    p_account_name IN VARCHAR2
) AS
BEGIN
    INSERT INTO accounts (client_id, account_number, balance, currency, account_name)
    VALUES (p_client_id, p_account_number, p_balance, p_currency, p_account_name);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20010, 'Грешка при добавяне на сметка: ' || SQLERRM);
END;
/

-- Обновяване на сметка
CREATE OR REPLACE PROCEDURE update_account(
    p_account_id IN NUMBER,
    p_balance IN NUMBER,
    p_currency IN VARCHAR2,
    p_account_name IN VARCHAR2
) AS
BEGIN
    UPDATE accounts
    SET balance = p_balance,
        currency = p_currency,
        account_name = p_account_name
    WHERE account_id = p_account_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20011, 'Грешка при обновяване на сметка: ' || SQLERRM);
END;
/

-- Изтриване на сметка
CREATE OR REPLACE PROCEDURE delete_account(p_account_id IN NUMBER) AS
BEGIN
    DELETE FROM accounts WHERE account_id = p_account_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20012, 'Грешка при изтриване на сметка: ' || SQLERRM);
END;
/

---------------------------
-- 4. CRUD процедури за клиенти
---------------------------

-- Добавяне на клиент
CREATE OR REPLACE PROCEDURE add_client(
    p_first_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_middle_name IN VARCHAR2,
    p_address IN CLOB,
    p_mobile_phone IN VARCHAR2,
    p_email IN VARCHAR2
) AS
BEGIN
    INSERT INTO clients (first_name, last_name, middle_name, address, mobile_phone, email)
    VALUES (p_first_name, p_last_name, p_middle_name, p_address, p_mobile_phone, p_email);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20013, 'Грешка при добавяне на клиент: ' || SQLERRM);
END;
/

-- Обновяване на клиент
CREATE OR REPLACE PROCEDURE update_client(
    p_client_id IN NUMBER,
    p_first_name IN VARCHAR2,
    p_last_name IN VARCHAR2,
    p_middle_name IN VARCHAR2,
    p_address IN CLOB,
    p_mobile_phone IN VARCHAR2,
    p_email IN VARCHAR2
) AS
BEGIN
    UPDATE clients
    SET 
        first_name = p_first_name,
        last_name = p_last_name,
        middle_name = p_middle_name,
        address = p_address,
        mobile_phone = p_mobile_phone,
        email = p_email
    WHERE client_id = p_client_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20014, 'Грешка при обновяване на клиент: ' || SQLERRM);
END;
/

-- Изтриване на клиент
CREATE OR REPLACE PROCEDURE delete_client(p_client_id IN NUMBER) AS
BEGIN
    DELETE FROM clients WHERE client_id = p_client_id;
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20015, 'Грешка при изтриване на клиент: ' || SQLERRM);
END;
/

---------------------------
-- 5. Процедура за превод между сметки
---------------------------
CREATE OR REPLACE PROCEDURE transfer_funds(
    p_from_account_id IN NUMBER,
    p_to_account_id IN NUMBER,
    p_amount IN NUMBER
) AS
    from_currency VARCHAR2(3);
    to_currency VARCHAR2(3);
    converted_amount NUMBER(15, 2);
    exchange_rate_val NUMBER(10, 4);
BEGIN
    DECLARE
        CURSOR c_from_account IS 
            SELECT currency, balance FROM accounts WHERE account_id = p_from_account_id FOR UPDATE;
        CURSOR c_to_account IS 
            SELECT currency FROM accounts WHERE account_id = p_to_account_id FOR UPDATE;
    BEGIN
        OPEN c_from_account;
        FETCH c_from_account INTO from_currency, converted_amount;
        IF c_from_account%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20001, 'Изходната сметка не съществува');
        END IF;
        CLOSE c_from_account;

        OPEN c_to_account;
        FETCH c_to_account INTO to_currency;
        IF c_to_account%NOTFOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'Целевата сметка не съществува');
        END IF;
        CLOSE c_to_account;

        IF converted_amount < p_amount THEN
            RAISE_APPLICATION_ERROR(-20003, 'Недостатъчен баланс');
        END IF;

        IF from_currency != to_currency THEN
            BEGIN
                SELECT rate INTO exchange_rate_val
                FROM (
                    SELECT rate 
                    FROM exchange_rates 
                    WHERE currency_from = from_currency 
                      AND currency_to = to_currency 
                      AND effective_date <= SYSDATE
                    ORDER BY effective_date DESC
                ) WHERE ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RAISE_APPLICATION_ERROR(-20004, 'Няма валутен курс за ' || from_currency || ' към ' || to_currency);
            END;
            converted_amount := p_amount * exchange_rate_val;
        ELSE
            exchange_rate_val := 1;
            converted_amount := p_amount;
        END IF;

        UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from_account_id;
        UPDATE accounts SET balance = balance + converted_amount WHERE account_id = p_to_account_id;
        INSERT INTO transactions (
            from_account_id, to_account_id, amount, currency_from, currency_to, exchange_rate
        ) VALUES (
            p_from_account_id, p_to_account_id, p_amount, from_currency, to_currency, exchange_rate_val
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            RAISE;
    END;
END;
/

---------------------------
-- 6. Процедура за обновяване на валутни курсове
---------------------------
CREATE OR REPLACE PROCEDURE update_exchange_rate(
    p_currency_from IN VARCHAR2,
    p_currency_to IN VARCHAR2,
    p_rate IN NUMBER,
    p_effective_date IN DATE
) AS
BEGIN
    DELETE FROM exchange_rates
    WHERE currency_from = p_currency_from
      AND currency_to = p_currency_to
      AND effective_date = p_effective_date;

    INSERT INTO exchange_rates (currency_from, currency_to, rate, effective_date)
    VALUES (p_currency_from, p_currency_to, p_rate, p_effective_date);
EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20016, 'Грешка при обновяване на валутен курс: ' || SQLERRM);
END;
/

---------------------------
-- Команди за изтриване (REVERSIBLE)
---------------------------
-- Тригери
DROP TRIGGER trg_accounts_update_status;
DROP TRIGGER trg_employee_department_change;

-- CRUD процедури за сметки
DROP PROCEDURE add_account;
DROP PROCEDURE update_account;
DROP PROCEDURE delete_account;

-- CRUD процедури за клиенти
DROP PROCEDURE add_client;
DROP PROCEDURE update_client;
DROP PROCEDURE delete_client;

-- Процедури за транзакции
DROP PROCEDURE transfer_funds;
DROP PROCEDURE update_exchange_rate;