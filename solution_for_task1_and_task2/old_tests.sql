SET SERVEROUTPUT ON;

---------------------------
-- 1. Подготовка на тестови данни (съобразено с връзките в схемата)
---------------------------
DECLARE
    -- Глобални променливи за всички блокове
    v_dept1_id          NUMBER;
    v_dept2_id          NUMBER;
    v_emp1_id           NUMBER;
    v_emp2_id           NUMBER;
    v_client1_id        NUMBER;
    v_client2_id        NUMBER;
    v_account1_id       NUMBER;
    v_account2_id       NUMBER;
    v_new_client_id     NUMBER;
    v_new_account_id    NUMBER;
BEGIN
    ---------------------------
    -- Изчистване на таблици
    ---------------------------
    BEGIN
        EXECUTE IMMEDIATE 'DELETE FROM transactions';
        EXECUTE IMMEDIATE 'DELETE FROM employee_status_history';
        EXECUTE IMMEDIATE 'DELETE FROM employee_department_movements';
        EXECUTE IMMEDIATE 'DELETE FROM accounts';
        EXECUTE IMMEDIATE 'DELETE FROM clients';
        EXECUTE IMMEDIATE 'DELETE FROM employees';
        EXECUTE IMMEDIATE 'DELETE FROM departments';
        EXECUTE IMMEDIATE 'DELETE FROM exchange_rates';
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Таблиците са изчистени.');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при изчистване: ' || SQLERRM);
    END;

    ---------------------------
    -- Добавяне на отдели
    ---------------------------
    BEGIN
        INSERT INTO departments (name) VALUES ('Финанси') RETURNING department_id INTO v_dept1_id;
        INSERT INTO departments (name) VALUES ('ИТ') RETURNING department_id INTO v_dept2_id;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Добавени отдели: Финанси (ID=' || v_dept1_id || '), ИТ (ID=' || v_dept2_id || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при добавяне на отдели: ' || SQLERRM);
    END;

    ---------------------------
    -- Добавяне на служители
    ---------------------------
    BEGIN
        INSERT INTO employees (first_name, last_name, address, mobile_phone, position, department_id, salary, start_date)
        VALUES ('Иван', 'Иванов', 'София', '+359881112233', 'Мениджър', v_dept1_id, 8000, SYSDATE - 365*5) 
        RETURNING employee_id INTO v_emp1_id;

        INSERT INTO employees (first_name, last_name, address, mobile_phone, position, department_id, salary, start_date)
        VALUES ('Мария', 'Петрова', 'Пловдив', '+359882223344', 'Програмист', v_dept2_id, 6000, SYSDATE - 365*3) 
        RETURNING employee_id INTO v_emp2_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Добавени служители: Иван (ID=' || v_emp1_id || '), Мария (ID=' || v_emp2_id || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при добавяне на служители: ' || SQLERRM);
    END;

    ---------------------------
    -- Добавяне на клиенти
    ---------------------------
    BEGIN
        INSERT INTO clients (first_name, last_name, address, mobile_phone)
        VALUES ('Клиент', 'Един', 'София', '+3591111111') 
        RETURNING client_id INTO v_client1_id;

        INSERT INTO clients (first_name, last_name, address, mobile_phone)
        VALUES ('Клиент', 'Два', 'Пловдив', '+3592222222') 
        RETURNING client_id INTO v_client2_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Добавени клиенти: Клиент Един (ID=' || v_client1_id || '), Клиент Два (ID=' || v_client2_id || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при добавяне на клиенти: ' || SQLERRM);
    END;

    ---------------------------
    -- Добавяне на сметки
    ---------------------------
    BEGIN
        INSERT INTO accounts (client_id, account_number, balance, currency)
        VALUES (v_client1_id, 'BG111111', 50000, 'BGN') 
        RETURNING account_id INTO v_account1_id;

        INSERT INTO accounts (client_id, account_number, balance, currency)
        VALUES (v_client2_id, 'BG222222', 0, 'EUR') 
        RETURNING account_id INTO v_account2_id;

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Добавени сметки: BG111111 (ID=' || v_account1_id || '), BG222222 (ID=' || v_account2_id || ')');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при добавяне на сметки: ' || SQLERRM);
    END;

    ---------------------------
    -- Валутни курсове (добавяне на двупосочни курсове)
    ---------------------------
    BEGIN
        INSERT INTO exchange_rates (currency_from, currency_to, rate, effective_date)
        VALUES ('EUR', 'BGN', 1.95, SYSDATE);

        INSERT INTO exchange_rates (currency_from, currency_to, rate, effective_date)
        VALUES ('BGN', 'EUR', 1/1.95, SYSDATE); -- Обратен курс

        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Добавени валутни курсове: EUR ↔ BGN');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при добавяне на валутен курс: ' || SQLERRM);
    END;

    ---------------------------
    -- 2. Тест на тригери
    ---------------------------
    -- Тест 1: VIP статус при баланс >= 100 000 BGN
    BEGIN
        UPDATE accounts SET balance = 150000 WHERE account_id = v_account1_id;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Тест 1: Балансът на сметка BG111111 е увеличен до 150 000 BGN.');

        FOR rec IN (SELECT status FROM clients WHERE client_id = v_client1_id) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('Резултат: Клиент ' || v_client1_id || ' има статус "' || rec.status || '" (Очакван: VIP клиент)');
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 1: ' || SQLERRM);
    END;

    -- Тест 2: Запис на движение между отдели
    BEGIN
        UPDATE employees SET department_id = v_dept2_id WHERE employee_id = v_emp1_id;
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Тест 2: Служител ' || v_emp1_id || ' е преместен от отдел ' || v_dept1_id || ' към ' || v_dept2_id);

        FOR rec IN (SELECT * FROM employee_department_movements WHERE employee_id = v_emp1_id) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('Резултат: Движение записано (Отдел ' || rec.old_department_id || ' → ' || rec.new_department_id || ')');
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 2: ' || SQLERRM);
    END;

    ---------------------------
    -- 3. Тест на CRUD процедури
    ---------------------------
    -- Тест 3: Добавяне на нов клиент
    BEGIN
        add_client('Тест', 'Клиент', NULL, 'Адрес', '+359887776655', 'test@test.com');
        COMMIT;
        
        SELECT client_id INTO v_new_client_id FROM clients WHERE last_name = 'Клиент' AND ROWNUM = 1;
        DBMS_OUTPUT.PUT_LINE('Тест 3: Добавен клиент с ID ' || v_new_client_id);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 3: ' || SQLERRM);
    END;

    -- Тест 4: Обновяване на имейл на клиент
    BEGIN
        update_client(v_new_client_id, 'Тест', 'Клиент', NULL, 'Адрес', '+359887776655', 'updated@test.com');
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Тест 4: Клиент ' || v_new_client_id || ' е обновен с нов имейл.');

        FOR rec IN (SELECT email FROM clients WHERE client_id = v_new_client_id) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('Резултат: Нов имейл - ' || rec.email || ' (Очакван: updated@test.com)');
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 4: ' || SQLERRM);
    END;

    -- Тест 5: Добавяне на сметка за новия клиент
    BEGIN
        add_account(v_new_client_id, 'BG333333', 1000, 'BGN', 'Тестова сметка');
        COMMIT;
        
        SELECT account_id INTO v_new_account_id FROM accounts WHERE account_number = 'BG333333';
        DBMS_OUTPUT.PUT_LINE('Тест 5: Добавена сметка с ID ' || v_new_account_id);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 5: ' || SQLERRM);
    END;

    -- Тест 6: Обновяване на валута на сметка
    BEGIN
        update_account(v_new_account_id, 2000, 'USD', 'Обновена сметка');
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Тест 6: Сметка ' || v_new_account_id || ' е конвертирана към USD.');

        FOR rec IN (SELECT currency, balance FROM accounts WHERE account_id = v_new_account_id) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('Резултат: Валута - ' || rec.currency || ', Баланс - ' || rec.balance);
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 6: ' || SQLERRM);
    END;

    -- Тест 7: Изтриване на сметка
    BEGIN
        delete_account(v_new_account_id);
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Тест 7: Сметка ' || v_new_account_id || ' е изтрита.');

        FOR rec IN (SELECT COUNT(*) AS cnt FROM accounts WHERE account_id = v_new_account_id) 
        LOOP
            DBMS_OUTPUT.PUT_LINE('Резултат: Оставащи сметки - ' || rec.cnt || ' (Очакван: 0)');
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 7: ' || SQLERRM);
    END;

    ---------------------------
    -- 4. Тест на превод между валути
    ---------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Тест 8: Превод от BGN към EUR с курс 1.95');
        transfer_funds(v_account1_id, v_account2_id, 10000); -- 10 000 BGN → EUR
        COMMIT;

        FOR rec IN (
            SELECT t.amount, t.currency_from, t.currency_to, t.exchange_rate 
            FROM transactions t
            WHERE t.from_account_id = v_account1_id
        )
        LOOP
            DBMS_OUTPUT.PUT_LINE('Транзакция: ' || rec.amount || ' ' || rec.currency_from || 
                                ' → ' || rec.currency_to || ' (Курс: ' || rec.exchange_rate || ')');
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 8: ' || SQLERRM);
    END;

    ---------------------------
    -- 5. Тест на обновяване на валутен курс
    ---------------------------
    BEGIN
        update_exchange_rate('EUR', 'BGN', 1.96, SYSDATE + 1); -- Нов курс за утре
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Тест 9: Курсът EUR → BGN е обновен до 1.96 (за утре).');

        FOR rec IN (
            SELECT rate, effective_date 
            FROM exchange_rates 
            WHERE currency_from = 'EUR' 
            ORDER BY effective_date DESC
        )
        LOOP
            DBMS_OUTPUT.PUT_LINE('Резултат: Курс EUR → BGN = ' || rec.rate || ' (Дата: ' || rec.effective_date || ')');
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка в Тест 9: ' || SQLERRM);
    END;

    ---------------------------
    -- 6. Тест на грешки (очаквани)
    ---------------------------
    BEGIN
        DBMS_OUTPUT.PUT_LINE('Тест 10: Опит за превод от сметка с недостатъчен баланс...');
        transfer_funds(v_account2_id, v_account1_id, 5000); -- 5000 EUR → BGN (сметка 2 има 0 EUR)
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Очаквана грешка: ' || SQLERRM);
            ROLLBACK;
    END;

    ---------------------------
    -- 7. Почистване на данни
    ---------------------------
    BEGIN
        EXECUTE IMMEDIATE 'DELETE FROM transactions';
        EXECUTE IMMEDIATE 'DELETE FROM employee_status_history';
        EXECUTE IMMEDIATE 'DELETE FROM employee_department_movements';
        EXECUTE IMMEDIATE 'DELETE FROM accounts';
        EXECUTE IMMEDIATE 'DELETE FROM clients';
        EXECUTE IMMEDIATE 'DELETE FROM employees';
        EXECUTE IMMEDIATE 'DELETE FROM departments';
        EXECUTE IMMEDIATE 'DELETE FROM exchange_rates';
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('Всички данни са изчистени.');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при изчистване: ' || SQLERRM);
    END;
END;
/