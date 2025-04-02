
-- Всичко тук е форматирано колкото се може по добре с AI
-- Направил съм всичко така че скрипта може да се изпълнява колкото пъти човек иска - което прави промяната и добавянето на нова логика доста по-лесно
-- (именно затова имаме стъпка 0 за триене)
-- Накрая на самия скрипт има тестове, стига всички тестове да минават цялата логика значи че е правилна


---------------------------
-- 0. Пълно почистване на обекти (обратимо)
---------------------------
BEGIN
    EXECUTE IMMEDIATE 'DROP TRIGGER trg_accounts_update_status'; -- това е тригера от Домашма 2, махам го понеже се заменя със Scheduled job (което си е доста добре понеже подобрява performance-a вместо да се изпълнява тригер за всеки път като има запис отново и отново)
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE users CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE inactive_users CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE password_notifications CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE users_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE password_notifications_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    DBMS_SCHEDULER.DROP_JOB('ARCHIVE_INACTIVE_USERS_JOB');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    DBMS_SCHEDULER.DROP_JOB('PASSWORD_EXPIRY_JOB');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    DBMS_SCHEDULER.DROP_JOB('VIP_STATUS_JOB');
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

---------------------------
-- 1. Създаване на таблици
---------------------------
CREATE TABLE users (
    user_id NUMBER PRIMARY KEY,
    client_id NUMBER NOT NULL UNIQUE REFERENCES clients(client_id),
    username VARCHAR2(100) NOT NULL UNIQUE,
    hashed_password RAW(2000) NOT NULL,
    last_login DATE,
    last_password_change DATE
);

CREATE TABLE inactive_users (
    user_id NUMBER PRIMARY KEY,
    username VARCHAR2(100),
    client_id NUMBER,
    last_login DATE,
    archive_date DATE DEFAULT SYSDATE
);

CREATE TABLE password_notifications (
    notification_id NUMBER PRIMARY KEY,
    user_id NUMBER NOT NULL,
    username VARCHAR2(100),
    notification_date DATE DEFAULT SYSDATE
);

---------------------------
-- 2. Последователности и тригери
---------------------------
CREATE SEQUENCE users_seq START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE password_notifications_seq START WITH 1 INCREMENT BY 1 NOCACHE;

CREATE OR REPLACE TRIGGER users_trg
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    :NEW.user_id := users_seq.NEXTVAL;
END;
/

CREATE OR REPLACE TRIGGER pn_trg
BEFORE INSERT ON password_notifications
FOR EACH ROW
BEGIN
    :NEW.notification_id := password_notifications_seq.NEXTVAL;
END;
/

---------------------------
-- 3. Пакет за логин
---------------------------
CREATE OR REPLACE PACKAGE login_package AS
    PROCEDURE user_login(p_username VARCHAR2, p_password VARCHAR2);
    PROCEDURE change_password(p_user_id NUMBER, p_old_password VARCHAR2, p_new_password VARCHAR2);
END login_package;
/

CREATE OR REPLACE PACKAGE BODY login_package AS
    PROCEDURE user_login(p_username VARCHAR2, p_password VARCHAR2) IS
        v_hashed_password RAW(2000);
        v_user_id NUMBER;
    BEGIN
        SELECT user_id, hashed_password INTO v_user_id, v_hashed_password
        FROM users WHERE username = p_username;

        IF v_hashed_password != DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_password, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256) THEN
            RAISE_APPLICATION_ERROR(-20020, 'Грешна парола');
        END IF;

        UPDATE users SET last_login = SYSDATE WHERE user_id = v_user_id;
        COMMIT;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20021, 'Потребителят не съществува');
    END;

    PROCEDURE change_password(p_user_id NUMBER, p_old_password VARCHAR2, p_new_password VARCHAR2) IS
        v_current_hash RAW(2000);
    BEGIN
        SELECT hashed_password INTO v_current_hash FROM users WHERE user_id = p_user_id;
        IF v_current_hash != DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_old_password, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256) THEN
            RAISE_APPLICATION_ERROR(-20022, 'Невалидна стара парола');
        END IF;

        UPDATE users SET 
            hashed_password = DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_new_password, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256),
            last_password_change = SYSDATE
        WHERE user_id = p_user_id;
        COMMIT;
    END;
END login_package;
/

---------------------------
-- 4. Пакет за управление на потребители (CRUD)
---------------------------
CREATE OR REPLACE PACKAGE user_management_package AS
    PROCEDURE create_user(
        p_client_id NUMBER,
        p_username VARCHAR2,
        p_password VARCHAR2
    );
END user_management_package;
/

CREATE OR REPLACE PACKAGE BODY user_management_package AS
    PROCEDURE create_user(
        p_client_id NUMBER,
        p_username VARCHAR2,
        p_password VARCHAR2
    ) IS
    BEGIN
        INSERT INTO users (client_id, username, hashed_password, last_password_change)
        VALUES (
            p_client_id,
            p_username,
            DBMS_CRYPTO.HASH(UTL_I18N.STRING_TO_RAW(p_password, 'AL32UTF8'), DBMS_CRYPTO.HASH_SH256),
            SYSDATE
        );
        COMMIT;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20023, 'Потребителското име е заето');
    END;
END user_management_package;
/

---------------------------
-- 5. Процедури за автоматични задачи
---------------------------
CREATE OR REPLACE PROCEDURE archive_inactive_users IS
    CURSOR c_inactive IS
        SELECT user_id, username, client_id, last_login
        FROM users
        WHERE last_login < ADD_MONTHS(SYSDATE, -3);
BEGIN
    FOR rec IN c_inactive LOOP
        INSERT INTO inactive_users (user_id, username, client_id, last_login)
        VALUES (rec.user_id, rec.username, rec.client_id, rec.last_login);
        DELETE FROM users WHERE user_id = rec.user_id;
    END LOOP;
    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE flag_password_expiry IS
    CURSOR c_expired IS
        SELECT user_id, username FROM users
        WHERE last_password_change < ADD_MONTHS(SYSDATE, -3);
BEGIN
    FOR rec IN c_expired LOOP
        INSERT INTO password_notifications (user_id, username)
        VALUES (rec.user_id, rec.username);
    END LOOP;
    COMMIT;
END;
/

CREATE OR REPLACE PROCEDURE update_vip_status IS
    CURSOR c_clients IS
        SELECT client_id, SUM(
            CASE 
                WHEN currency = 'BGN' THEN balance
                ELSE balance * COALESCE(
                    (SELECT rate FROM (
                        SELECT rate FROM exchange_rates 
                        WHERE currency_from = a.currency AND currency_to = 'BGN'
                        ORDER BY effective_date DESC
                    ) WHERE ROWNUM = 1
                ), 1)
            END
        ) AS total_balance
        FROM accounts a
        GROUP BY client_id;
BEGIN
    FOR rec IN c_clients LOOP
        IF rec.total_balance >= 100000 THEN
            UPDATE clients SET status = 'VIP клиент' WHERE client_id = rec.client_id;
        END IF;
    END LOOP;
    COMMIT;
END;
/

---------------------------
-- 6. Конфигуриране на автоматични задачи
---------------------------
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'ARCHIVE_INACTIVE_USERS_JOB',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'ARCHIVE_INACTIVE_USERS',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0;',
        enabled         => TRUE,
        auto_drop       => FALSE
    );
END;
/

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'PASSWORD_EXPIRY_JOB',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'FLAG_PASSWORD_EXPIRY',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0;',
        enabled         => TRUE,
        auto_drop       => FALSE
    );
END;
/

BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name        => 'VIP_STATUS_JOB',
        job_type        => 'STORED_PROCEDURE',
        job_action      => 'UPDATE_VIP_STATUS',
        start_date      => SYSTIMESTAMP,
        repeat_interval => 'FREQ=DAILY; BYHOUR=0;',
        enabled         => TRUE,
        auto_drop       => FALSE
    );
END;
/

---------------------------
-- 7. Тестове
---------------------------
SET SERVEROUTPUT ON;

DECLARE
    v_test_client_id    NUMBER;
    v_test_user_id      NUMBER;
    v_test_account_id   NUMBER;
    v_count             NUMBER;
    v_status            VARCHAR2(50);
    v_unique_acc_num    VARCHAR2(20); -- Нова променлива за уникален номер на сметка
BEGIN
    -- Почистване на данни В ПРАВИЛЕН РЕД
    BEGIN
        EXECUTE IMMEDIATE 'DELETE FROM password_notifications';
        EXECUTE IMMEDIATE 'DELETE FROM inactive_users';
        EXECUTE IMMEDIATE 'DELETE FROM users';
        EXECUTE IMMEDIATE 'DELETE FROM accounts'; -- Първо трием дъщерните таблици
        EXECUTE IMMEDIATE 'DELETE FROM clients';
        COMMIT;
        DBMS_OUTPUT.PUT_LINE('===== СИСТЕМАТА Е ПОДГОТВЕНА =====');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Грешка при почистване: ' || SQLERRM);
    END;

    -- Тест 1: Създаване на клиент + потребител
    BEGIN
        INSERT INTO clients (first_name, last_name, address, mobile_phone)
        VALUES ('Тест', 'Клиент', 'София', '+359888112233')
        RETURNING client_id INTO v_test_client_id;

        user_management_package.create_user(v_test_client_id, 'test_user', 'Secret123!');
        SELECT user_id INTO v_test_user_id FROM users WHERE username = 'test_user';
        DBMS_OUTPUT.PUT_LINE('[ТЕСТ 1] Успех: Създаден потребител ID=' || v_test_user_id);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 1] Грешка: ' || SQLERRM);
    END;

    -- Тест 2: Валиден логин
    BEGIN
        login_package.user_login('test_user', 'Secret123!');
        DBMS_OUTPUT.PUT_LINE('[ТЕСТ 2] Успешен логин');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 2] Грешка: ' || SQLERRM);
    END;

    -- Тест 3: Грешен логин
    BEGIN
        login_package.user_login('test_user', 'грешна_парола');
        DBMS_OUTPUT.PUT_LINE('[ТЕСТ 3] НЕОЧАКВАН УСПЕХ');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 3] Очаквана грешка: ' || SQLERRM);
    END;

    -- Тест 4: Смяна на парола
    BEGIN
        login_package.change_password(v_test_user_id, 'Secret123!', 'NewPassword456!');
        DBMS_OUTPUT.PUT_LINE('[ТЕСТ 4] Паролата е сменена');

        -- Проверка на новата парола
        BEGIN
            login_package.user_login('test_user', 'NewPassword456!');
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 4] Новата парола работи');
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('[ТЕСТ 4] Грешка: ' || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 4] Грешка: ' || SQLERRM);
    END;

    -- Тест 5: Архивиране
    BEGIN
        UPDATE users SET last_login = ADD_MONTHS(SYSDATE, -4) WHERE user_id = v_test_user_id;
        COMMIT;
        archive_inactive_users();
        
        SELECT COUNT(*) INTO v_count FROM inactive_users WHERE username = 'test_user';
        IF v_count = 1 THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 5] Архивиран потребител');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 5] Грешка: ' || v_count || ' записи');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 5] Грешка: ' || SQLERRM);
    END;

    -- Тест 6: VIP статус (FIXED)
    BEGIN
        -- Генериране на уникален номер на сметка
        v_unique_acc_num := 'BG11TEST' || TO_CHAR(SYSDATE, 'SSSSS'); -- Уникален стринг базиран на времето
        
        INSERT INTO accounts (client_id, account_number, balance, currency)
        VALUES (v_test_client_id, v_unique_acc_num, 150000, 'BGN');
        COMMIT;
        update_vip_status();
        
        SELECT status INTO v_status FROM clients WHERE client_id = v_test_client_id;
        IF v_status = 'VIP клиент' THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 6] VIP статус присъден');
        ELSE
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 6] Грешка: ' || v_status);
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[ТЕСТ 6] Грешка: ' || SQLERRM);
    END;

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('===== ТЕСТОВЕТЕ ПРИКЛЮЧИХА УСПЕШНО =====');
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Грешка: ' || SQLERRM);
        ROLLBACK;
END;
/