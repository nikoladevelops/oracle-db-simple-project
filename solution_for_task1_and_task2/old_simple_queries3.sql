-- 1. Уволени служители
SELECT e.employee_id, e.first_name, e.last_name, esh.status, esh.start_date
FROM employees e
JOIN employee_status_history esh ON e.employee_id = esh.employee_id
WHERE esh.status = 'dismissed';

-- 2. Служители в майчинство (текущо)
SELECT e.employee_id, e.first_name, e.last_name
FROM employees e
JOIN employee_status_history esh ON e.employee_id = esh.employee_id
WHERE esh.status = 'maternity' AND esh.end_date IS NULL;

-- 3. Служители на временен отпуск (болничен/отпуск)
SELECT e.employee_id, e.first_name, e.last_name, esh.status, esh.start_date
FROM employees e
JOIN employee_status_history esh ON e.employee_id = esh.employee_id
WHERE esh.status IN ('vacation', 'sick') AND esh.end_date IS NULL;

-- 4. Служители без мениджър
SELECT employee_id, first_name, last_name
FROM employees
WHERE manager_id IS NULL;

-- 5. Старши служители със заплата над 5000 лв
SELECT first_name, last_name, salary
FROM employees
WHERE salary > 5000 
  AND MONTHS_BETWEEN(SYSDATE, start_date)/12 >= 5
ORDER BY first_name DESC;

-- 6. Топ 5 високоплатени служители по отдел
WITH ranked_employees AS (
  SELECT 
    e.*, 
    d.name AS department,
    ROW_NUMBER() OVER (PARTITION BY e.department_id ORDER BY e.salary DESC) AS rank
  FROM employees e
  JOIN departments d ON e.department_id = d.department_id
)
SELECT department, first_name, last_name, salary
FROM ranked_employees
WHERE rank <= 5;

-- 7. Отдел с най-ниска обща заплата
SELECT department, total_salary
FROM (
  SELECT 
    d.name AS department, 
    SUM(e.salary) AS total_salary,
    ROW_NUMBER() OVER (ORDER BY SUM(e.salary) ASC) AS rn
  FROM employees e
  JOIN departments d ON e.department_id = d.department_id
  GROUP BY d.name
)
WHERE rn = 1;

-- 8. Средна заплата по отдели
SELECT d.name AS department, ROUND(AVG(e.salary), 2) AS avg_salary
FROM employees e
JOIN departments d ON e.department_id = d.department_id
GROUP BY d.name;