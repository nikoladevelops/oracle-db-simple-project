-- 1. Всички имена на отдели
SELECT name FROM departments;

-- 2. Имена и заплати на служители
SELECT first_name, last_name, salary FROM employees;

-- 3. Генериране на имейли
SELECT 
    first_name,
    last_name,
    LOWER(first_name) || '.' || LOWER(last_name) || '@bankoftomarow.bg' AS email 
FROM employees;

-- 4. Служители с минимум 5 години стаж
SELECT * FROM employees
WHERE MONTHS_BETWEEN(SYSDATE, start_date) / 12 >= 5;

-- 5. Служители със 'l' в имената (case-insensitive)
SELECT *
FROM employees
WHERE 
    LOWER(first_name) LIKE '%l%' OR
    LOWER(last_name) LIKE '%l%' OR 
    LOWER(middle_name) LIKE '%l%';