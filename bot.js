const TelegramBot = require('node-telegram-bot-api');

const TOKEN = '8256903830:AAHuTIINeKlaUDt0waLth7ToIDvELBTwm1A';

const bot = new TelegramBot(TOKEN, { polling: true });

bot.onText(/\/start/, (msg) => {
    const chatId = msg.chat.id;
    const name = msg.from.first_name || 'друг';
    bot.sendMessage(chatId, `Привет, ${name}! 👋\n\nДобро пожаловать в "Скрытые Таланты"!\n\n/stats — статистика\n/schedule — расписание\n/help — все команды`);
});

bot.onText(/\/stats/, (msg) => {
    bot.sendMessage(msg.chat.id, `📊 Статистика за сегодня:\n👥 Новых: 0\n🎤 Выступлений: 0\n💰 Доход: 0 ₽`);
});

bot.onText(/\/schedule/, (msg) => {
    bot.sendMessage(msg.chat.id, `📅 Расписание эфиров:\nПн–Чт: 20:00 — Отбор\nПт: 20:00 — Битва недели\nСб: 20:00 — Дуэли\nВс: 20:00 — Финал недели`);
});

bot.onText(/\/help/, (msg) => {
    bot.sendMessage(msg.chat.id, `🤖 Команды:\n/start\n/stats\n/schedule\n/help`);
});

console.log('Бот "Скрытые Таланты" запущен!');