\c hidden_talents
SET client_encoding = 'UTF8';
INSERT INTO banned_words (word) VALUES 
('хуй'),
('пизда'),
('пиздец')
ON CONFLICT (word) DO NOTHING;
SELECT id, word FROM banned_words;
