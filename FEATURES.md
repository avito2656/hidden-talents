# FEATURES.md — Скрытые Таланты

**Версия документа:** 4.0
**Дата обновления:** 02.10.2026
**Статус проекта:** ~90% готовности MVP
**Репозиторий:** https://github.com/avito2656/hidden-talents
**Сервер:** `37.139.51.232` (Ubuntu, PostgreSQL, Nginx, PM2)
**Дедлайн запуска:** 01.12.2026

---

## 🎯 О ПРОЕКТЕ

**Название:** Hidden Talents («Скрытые Таланты»)
**Идея:** «Голос», но в интернете. Прямые эфиры, AI-судьи, сезоны, Shorts, донаты.
**Аудитория:** 150k YouTube + 12k VK.
**Цель:** 1000 зрителей, первые 10 000 ₽, потом миллион пользователей.

**Основатель:** не программист, делает проект с AI-ассистентом.
**Юридический статус:** самозанятый.

---

## 🛠 ТЕХНОЛОГИЧЕСКИЙ СТЕК

### Клиент
- **Flutter (Dart)**.
- **Пакеты:** `agora_rtc_engine: ^6.5.0`, `permission_handler: ^11.3.0`, `http: ^1.2.0`, `shared_preferences: ^2.2.0`, `video_player: ^2.9.0`, `cupertino_icons: ^1.0.8`.

### Сервер
- **Node.js (Express 5.2.1)**.
- **PostgreSQL** — база `hidden_talents` (UTF8).
- **PM2**, **Nginx**, **dotenv**, **cors**, **pg**, **bcrypt**, **agora-token**.

### База данных (12 таблиц)
`users`, `rooms`, `messages`, `judge_votes`, `judge_seats`, `queue`, `seasons`, `shorts`, `shorts_likes`, `shorts_comments`, `banned_words`, `donations`.

**Ключевые данные:**
- **Сезон:** id=1, «Сезон 1: Зимний прорыв», `active`, 01.12.2026 — 01.03.2027.
- **Комнаты:** 1-Отбор, 2-Битва, 3-Дуэли, 4-Финал.
- **AI-судьи:** 12 мест (по 3 на комнату): Строгий, Добрый, Эксперт.

### Видео
- **Agora RTC SDK** — App ID `30e1225ad640464f847561b9c1470b8b`.
- **Primary Certificate** — активен, требует токен.
- **Токен** — генерируется на сервере через `/api/agora/token`.

### Хранилище
- **Cloudflare R2** — bucket `hidden-talents-video`.
- **Public URL:** `https://pub-05687291849f426ab84d3b25490bac31.r2.dev`.

### Инфраструктура
- **VDS:** `37.139.51.232`, Ubuntu 26.04, 10 ГБ (~6.8 ГБ свободно).
- **Папки:** `/root/hidden-talents/`, `/root/hidden-talents/backend/`.

---

## 📂 СТРУКТУРА FLUTTER

- `lib/main.dart` — SplashScreen, WelcomeScreen.
- `lib/screens/home_screen.dart` — StageTab (2 кнопки), ShortsScreen, ProfileTab.
- `lib/screens/live_room_screen.dart` — комната с 3 режимами (performer/viewer/judge).
- `lib/screens/seasons_screen.dart` — сезоны.
- `lib/screens/shorts_screen.dart` — Shorts с плеером и донатами.
- `lib/screens/registration_screen.dart`, `login_screen.dart` — авторизация.
- `lib/services/api_service.dart` — API (20+ методов).
- `lib/services/user_service.dart` — SharedPreferences.

---

## 🔌 API-ЭНДПОИНТЫ (30)

### Пользователи
- `POST /api/users` — регистрация (100 монет).
- `POST /api/login` — вход.
- `GET /api/users`, `GET /api/users/:id`.

### Agora
- `GET /api/agora/token?channelName=...&uid=...` — токен.

### Донаты
- `POST /api/donate`, `GET /api/donations/received/:id`, `GET /api/donations/sent/:id`.

### AI-судьи
- `POST /api/judge/auto-vote` — AI-голосование.
- `GET /api/judge-results/:room_id/:performer_id`.

### Судьи
- `POST /api/judge_votes`, `GET /api/judge-seats/:room_id`, `POST /api/judge-seats/occupy`.

### Модерация
- `POST /api/moderate/check`.

### Сообщения
- `POST /api/messages`, `GET /api/messages/:room_id`.

### Очередь
- `POST /api/queue/join`, `GET /api/queue/:room_id`, `POST /api/queue/start-performance`, `POST /api/queue/end-performance`, `GET /api/queue/current/:room_id`, `POST /api/queue/check-limit`.

### Сезоны
- `GET /api/seasons/current`, `GET /api/seasons`, `POST /api/seasons`, `GET /api/seasons/:id/leaderboard`.

### Shorts
- `GET /api/shorts`, `POST /api/shorts/:id/like`.

---

## ✅ ЧТО РАБОТАЕТ

### Авторизация
- ✅ Регистрация (100 монет новым).
- ✅ Вход, выход.
- ✅ Профиль с реальным балансом.

### Shorts
- ✅ Плеер (video_player + R2).
- ✅ Лайки.
- ✅ Донаты (диалог 10/50/100).

### Эфиры
- ✅ Камера (Agora с токеном).
- ✅ Чат (polling 3 сек).
- ✅ Очередь.
- ✅ 3 режима: performer / viewer / judge.
- ✅ AI-судьи (рандом + комментарии).

### Донаты
- ✅ Перевод монет между пользователями.
- ✅ История.

---

## ❌ ЧТО НЕ РАБОТАЕТ

### Критично
1. **Анимация судей** (поворот карточек, звуки, конфетти) — не сделано.
2. **Судья-человек** — UI есть, логики нет.
3. **`is_live`** — комната работает 24/7, должна только во время эфира.
4. **HTTPS + домен** — сейчас `http://`.
5. **Расписание** — до эфира показывается заглушка.

### Важно
6. **Запись эфира** (Agora Cloud Recording) — нужна карта.
7. **Нарезка (FFmpeg)** — не подключено.
8. **YouTube** — не подключено.
9. **Правила + оферта** — не написаны.
10. **Комментарии Shorts** — заглушка.
11. **Поделиться Shorts** — заглушка.

### Технический долг
12. **`node_modules/` в Git** — убрать.
13. **`is_performing` застревает** — нужен сброс.
14. **`bot.js`** — назначение неясно.

---

## 📅 ПЛАН ДО 1 ДЕКАБРЯ

- **Неделя 1-2:** ✅ Авторизация, Shorts, R2, донаты.
- **Неделя 2-3:** ✅ AI-судьи, Agora-токен.
- **Неделя 3:** Анимация судей + звуки + конфетти.
- **Неделя 4:** `is_live` + расписание.
- **Неделя 5:** HTTPS + домен.
- **Неделя 6:** Запись эфира (Agora Cloud Recording).
- **Неделя 7:** Нарезка (FFmpeg) + YouTube.
- **Неделя 8:** Юридическая часть.
- **Неделя 9:** Тестирование + маркетинг.

---

## 🔑 КЛЮЧЕВЫЕ ДАННЫЕ

- **IP сервера:** `37.139.51.232`
- **Agora App ID:** `30e1225ad640464f847561b9c1470b8b`
- **Agora Certificate:** активен (в `.env` на сервере)
- **R2 Public URL:** `https://pub-05687291849f426ab84d3b25490bac31.r2.dev`
- **R2 Account ID:** `b6f37330b6871bcc156d8290636237b7`
- **Сезон:** id=1, active
- **AI-судьи:** Строгий, Добрый, Эксперт

---

## 📌 ПРАВИЛА РАБОТЫ С AI

1. **Пароли никогда не присылаются** в чат.
2. **Объяснять по шагам**.
3. **Проверять результат** после каждого шага.
4. **Давать полные коды** для замены файлов.
5. **Использовать SSH, psql, SQL, scp** — основатель умеет.
6. **Уважать уровень** — не программист, но делает.
7. **Не перескакивать** через этапы.

---

## 🚀 С ЧЕГО ПРОДОЛЖИТЬ

**Текущая задача:** **Анимация AI-судей** (поворот карточек, звуки, конфетти).

**Что нужно:**
- Пакеты `audioplayers`, `confetti`.
- Звуки `success.mp3`, `fail.mp3` в `assets/sounds/`.
- Виджет `_JudgeRevealCard` в `live_room_screen.dart`.
- Анимация: карточка переворачивается → показывает результат → звук.
- Итог: 2 из 3 → «Прошёл» + конфетти.

**Потом:** `is_live` + расписание, HTTPS, запись эфира.

---

**Конец документа.**