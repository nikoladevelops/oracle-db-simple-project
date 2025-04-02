---------------------------
-- Изтриване на стари обекти (ако съществуват)
---------------------------
BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE transactions CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE employee_status_history CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE employee_department_movements CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE exchange_rates CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE accounts CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE clients CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE employees CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE departments CASCADE CONSTRAINTS';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

-- Изтриване на последователности
BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE departments_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE employees_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE clients_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE accounts_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE transactions_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE employee_department_movements_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

BEGIN
    EXECUTE IMMEDIATE 'DROP SEQUENCE employee_status_history_seq';
EXCEPTION WHEN OTHERS THEN NULL;
END;
/

---------------------------
-- Създаване на нови обекти
---------------------------

-- Отдели
CREATE SEQUENCE departments_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE departments (
    department_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL UNIQUE
);
CREATE OR REPLACE TRIGGER departments_trg
BEFORE INSERT ON departments
FOR EACH ROW
BEGIN
    SELECT departments_seq.NEXTVAL INTO :NEW.department_id FROM DUAL;
END;
/

-- Служители
CREATE SEQUENCE employees_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE employees (
    employee_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    middle_name VARCHAR2(50),
    address CLOB NOT NULL,
    mobile_phone VARCHAR2(20) NOT NULL,
    email VARCHAR2(100),
    position VARCHAR2(100) NOT NULL,
    department_id NUMBER REFERENCES departments(department_id),
    manager_id NUMBER REFERENCES employees(employee_id),
    salary NUMBER(10, 2) NOT NULL,
    start_date DATE NOT NULL,
    status VARCHAR2(50) DEFAULT 'active'
);
CREATE OR REPLACE TRIGGER employees_trg
BEFORE INSERT ON employees
FOR EACH ROW
BEGIN
    SELECT employees_seq.NEXTVAL INTO :NEW.employee_id FROM DUAL;
END;
/

-- Клиенти
CREATE SEQUENCE clients_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE clients (
    client_id NUMBER PRIMARY KEY,
    first_name VARCHAR2(50) NOT NULL,
    last_name VARCHAR2(50) NOT NULL,
    middle_name VARCHAR2(50),
    address CLOB NOT NULL,
    mobile_phone VARCHAR2(20) NOT NULL,
    email VARCHAR2(100),
    status VARCHAR2(50) DEFAULT 'standard'
);
CREATE OR REPLACE TRIGGER clients_trg
BEFORE INSERT ON clients
FOR EACH ROW
BEGIN
    SELECT clients_seq.NEXTVAL INTO :NEW.client_id FROM DUAL;
END;
/

-- Сметки
CREATE SEQUENCE accounts_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE accounts (
    account_id NUMBER PRIMARY KEY,
    client_id NUMBER NOT NULL REFERENCES clients(client_id),
    account_number VARCHAR2(50) NOT NULL UNIQUE,
    balance NUMBER(15, 2) DEFAULT 0 NOT NULL,
    currency VARCHAR2(3) DEFAULT 'BGN' NOT NULL,
    account_name VARCHAR2(200)
);
CREATE OR REPLACE TRIGGER accounts_trg
BEFORE INSERT ON accounts
FOR EACH ROW
BEGIN
    SELECT accounts_seq.NEXTVAL INTO :NEW.account_id FROM DUAL;
END;
/

-- Валутни курсове
CREATE TABLE exchange_rates (
    currency_from VARCHAR2(3) NOT NULL,
    currency_to VARCHAR2(3) NOT NULL,
    rate NUMBER(10, 4) NOT NULL,
    effective_date DATE NOT NULL,
    PRIMARY KEY (currency_from, currency_to, effective_date)
);

-- Транзакции
CREATE SEQUENCE transactions_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE transactions (
    transaction_id NUMBER PRIMARY KEY,
    from_account_id NUMBER NOT NULL REFERENCES accounts(account_id),
    to_account_id NUMBER NOT NULL REFERENCES accounts(account_id),
    amount NUMBER(15, 2) NOT NULL,
    currency_from VARCHAR2(3) NOT NULL,
    currency_to VARCHAR2(3) NOT NULL,
    exchange_rate NUMBER(10, 4) NOT NULL,
    transaction_date TIMESTAMP DEFAULT SYSTIMESTAMP
);
CREATE OR REPLACE TRIGGER transactions_trg
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    SELECT transactions_seq.NEXTVAL INTO :NEW.transaction_id FROM DUAL;
END;
/

-- История на движения между отдели
CREATE SEQUENCE employee_department_movements_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE employee_department_movements (
    movement_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL REFERENCES employees(employee_id),
    old_department_id NUMBER REFERENCES departments(department_id),
    new_department_id NUMBER NOT NULL REFERENCES departments(department_id),
    movement_date DATE NOT NULL
);
CREATE OR REPLACE TRIGGER edm_trg
BEFORE INSERT ON employee_department_movements
FOR EACH ROW
BEGIN
    SELECT employee_department_movements_seq.NEXTVAL INTO :NEW.movement_id FROM DUAL;
END;
/

-- История на статуси на служители
CREATE SEQUENCE employee_status_history_seq START WITH 1 INCREMENT BY 1;
CREATE TABLE employee_status_history (
    status_id NUMBER PRIMARY KEY,
    employee_id NUMBER NOT NULL REFERENCES employees(employee_id),
    status VARCHAR2(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE
);
CREATE OR REPLACE TRIGGER esh_trg
BEFORE INSERT ON employee_status_history
FOR EACH ROW
BEGIN
    SELECT employee_status_history_seq.NEXTVAL INTO :NEW.status_id FROM DUAL;
END;
/