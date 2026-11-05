-- Лабораторная работа №2. Создание запросов (PostgreSQL)
-- Вариант 22. Почтовые отделения
-- Схема и тестовые данные включены для самостоятельного запуска скрипта.
-- Запускать целиком в Query Tool PostgreSQL.

BEGIN;

CREATE SCHEMA IF NOT EXISTS lab2_v22;
SET search_path TO lab2_v22;

DROP TABLE IF EXISTS selected_departments;
DROP TABLE IF EXISTS work_schedule CASCADE;
DROP TABLE IF EXISTS departments CASCADE;
DROP TABLE IF EXISTS post_offices CASCADE;

CREATE TABLE post_offices (
    office_id INTEGER PRIMARY KEY,
    postal_code VARCHAR(6) NOT NULL,
    address TEXT NOT NULL
);

CREATE TABLE departments (
    department_id INTEGER PRIMARY KEY,
    office_id INTEGER NOT NULL REFERENCES post_offices(office_id),
    department_name TEXT NOT NULL,
    serves_individuals BOOLEAN NOT NULL,
    serves_legal_entities BOOLEAN NOT NULL,
    accepts_registered_letters BOOLEAN NOT NULL
);

CREATE TABLE work_schedule (
    schedule_id INTEGER PRIMARY KEY,
    department_id INTEGER NOT NULL REFERENCES departments(department_id),
    weekday INTEGER NOT NULL CHECK (weekday BETWEEN 1 AND 7),
    work_start TIME NOT NULL,
    work_end TIME NOT NULL,
    break_start TIME,
    break_end TIME,
    CHECK ((break_start IS NULL) = (break_end IS NULL)),
    CHECK (work_end > work_start),
    CHECK (break_start IS NULL OR (break_start >= work_start AND break_end <= work_end AND break_end > break_start)),
    UNIQUE (department_id, weekday)
);

INSERT INTO post_offices VALUES
(1, '101000', 'Москва, ул. Мясницкая, 26'),
(2, '115093', 'Москва, ул. Люсиновская, 39'),
(3, '190000', 'Санкт-Петербург, Невский проспект, 1');

INSERT INTO departments VALUES
(1, 1, 'Приём писем', TRUE, FALSE, TRUE),
(2, 1, 'Обслуживание организаций', FALSE, TRUE, TRUE),
(3, 2, 'Универсальный отдел', TRUE, TRUE, TRUE),
(4, 2, 'Выдача посылок', TRUE, FALSE, FALSE),
(5, 3, 'Отдел корпоративных клиентов', FALSE, TRUE, FALSE),
(6, 3, 'Экспресс доставка', TRUE, TRUE, TRUE);

INSERT INTO work_schedule VALUES
(1, 1, 1, '09:00', '19:00', '13:00', '13:30'),
(2, 1, 2, '09:00', '19:00', '13:00', '13:30'),
(3, 2, 1, '10:00', '19:00', '14:00', '14:20'),
(4, 2, 3, '10:00', '20:00', '14:00', '14:45'),
(5, 3, 1, '08:00', '20:00', '13:00', '14:00'),
(6, 3, 2, '08:00', '20:00', '13:00', '14:00'),
(7, 3, 3, '08:00', '20:00', '13:00', '14:00'),
(8, 4, 4, '09:00', '18:00', '13:00', '13:15'),
(9, 5, 5, '09:00', '19:00', '12:00', '13:00'),
(10, 6, 6, '09:00', '19:00', NULL, NULL),
(11, 6, 7, '10:00', '18:00', NULL, NULL);

-- 1. Дни недели, в которые отделения работают более 8 часов
-- Продолжительность считается без перерыва.
SELECT DISTINCT
    s.weekday,
    (ARRAY['Понедельник', 'Вторник', 'Среда', 'Четверг',
           'Пятница', 'Суббота', 'Воскресенье'])[s.weekday] AS day_name
FROM work_schedule AS s
WHERE (s.work_end - s.work_start)
      - COALESCE(s.break_end - s.break_start, INTERVAL '0 minutes')
      > INTERVAL '8 hours'
ORDER BY s.weekday;

-- 2. Отделы, работающие только с физическими лицами и принимающие заказные письма
SELECT d.department_id, d.department_name, p.postal_code, p.address
FROM departments AS d
JOIN post_offices AS p ON p.office_id = d.office_id
WHERE d.serves_individuals = TRUE
  AND d.serves_legal_entities = FALSE
  AND d.accepts_registered_letters = TRUE
ORDER BY d.department_id;

-- 3. Создание таблицы из запроса №1 с данными о расписании и отделах
CREATE TABLE selected_departments AS
SELECT s.schedule_id, s.weekday,
       (ARRAY['Понедельник', 'Вторник', 'Среда', 'Четверг',
              'Пятница', 'Суббота', 'Воскресенье'])[s.weekday] AS day_name,
       s.work_start, s.work_end, s.break_start, s.break_end,
       d.department_id, d.department_name,
       d.serves_individuals, d.serves_legal_entities,
       d.accepts_registered_letters,
       p.office_id, p.postal_code, p.address
FROM work_schedule AS s
JOIN departments AS d ON d.department_id = s.department_id
JOIN post_offices AS p ON p.office_id = d.office_id
WHERE (s.work_end - s.work_start)
      - COALESCE(s.break_end - s.break_start, INTERVAL '0 minutes')
      > INTERVAL '8 hours';

-- 4. Добавление в созданную таблицу отделов с названиями из нескольких слов
-- Добавляются записи расписания этих отделов, без повторений.
INSERT INTO selected_departments
SELECT s.schedule_id, s.weekday,
       (ARRAY['Понедельник', 'Вторник', 'Среда', 'Четверг',
              'Пятница', 'Суббота', 'Воскресенье'])[s.weekday],
       s.work_start, s.work_end, s.break_start, s.break_end,
       d.department_id, d.department_name,
       d.serves_individuals, d.serves_legal_entities,
       d.accepts_registered_letters,
       p.office_id, p.postal_code, p.address
FROM work_schedule AS s
JOIN departments AS d ON d.department_id = s.department_id
JOIN post_offices AS p ON p.office_id = d.office_id
WHERE d.department_name ~ '\S+\s+\S+'
  AND NOT EXISTS (
      SELECT 1 FROM selected_departments AS t
      WHERE t.schedule_id = s.schedule_id
  );

-- 5. Включить обслуживание физических лиц для отделов,
-- которые до изменения работали только с юридическими лицами
UPDATE selected_departments
SET serves_individuals = TRUE
WHERE serves_legal_entities = TRUE
  AND serves_individuals = FALSE;

-- 6. Удалить отделы с перерывом меньше получаса
-- Записи без перерыва не удаляются.
DELETE FROM selected_departments
WHERE break_start IS NOT NULL
  AND break_end - break_start < INTERVAL '30 minutes';

-- 7. Посчитать по каждому дню недели количество отделов,
-- обслуживающих только юрлиц, и количество отделов, обслуживающих обе категории.
-- Подсчёт ведётся по изменённой таблице selected_departments.
SELECT days.weekday,
       days.day_name,
       COUNT(DISTINCT t.department_id) FILTER (
          WHERE t.serves_legal_entities = TRUE
            AND t.serves_individuals = FALSE
       ) AS legal_only_count,
       COUNT(DISTINCT t.department_id) FILTER (
          WHERE t.serves_legal_entities = TRUE
            AND t.serves_individuals = TRUE
       ) AS all_clients_count
FROM (VALUES
  (1, 'Понедельник'), (2, 'Вторник'), (3, 'Среда'),
  (4, 'Четверг'), (5, 'Пятница'), (6, 'Суббота'),
  (7, 'Воскресенье')
) AS days(weekday, day_name)
LEFT JOIN selected_departments AS t ON t.weekday = days.weekday
GROUP BY days.weekday, days.day_name
ORDER BY days.weekday;

-- Итоговое содержимое созданной таблицы
SELECT * FROM selected_departments ORDER BY weekday, department_id;

COMMIT;
