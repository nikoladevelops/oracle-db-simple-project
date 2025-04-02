-- 2. Служители, работили в повече от 1 отдел за последните 2 месеца
SELECT employee_id, COUNT(DISTINCT new_department_id) AS dept_count
FROM employee_department_movements
WHERE movement_date >= ADD_MONTHS(SYSDATE, -2)
GROUP BY employee_id
HAVING COUNT(DISTINCT new_department_id) > 1;

-- 3. Служители, работили само в един отдел от началото на работата им
SELECT employee_id 
FROM employee_department_movements
GROUP BY employee_id
HAVING COUNT(DISTINCT new_department_id) = 1;