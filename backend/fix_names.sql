\c hidden_talents
SET client_encoding = 'UTF8';
DELETE FROM judge_seats;
INSERT INTO judge_seats (room_id, seat_number, ai_judge_name) VALUES (1, 1, 'Анна Петрова');
INSERT INTO judge_seats (room_id, seat_number, ai_judge_name) VALUES (1, 2, 'Иван Смирнов');
INSERT INTO judge_seats (room_id, seat_number, ai_judge_name) VALUES (1, 3, 'Мария Иванова');
SELECT seat_number, ai_judge_name FROM judge_seats;