\c hidden_talents
SET client_encoding = 'UTF8';
DELETE FROM seasons;
INSERT INTO seasons (name, start_date, end_date, status, prize_description)
VALUES ('Сезон 1: Зимний прорыв', '2026-12-01', '2027-03-01', 'active', '10 000 ₽ + продвижение в Shorts + запись на YouTube');
SELECT id, name, prize_description FROM seasons;