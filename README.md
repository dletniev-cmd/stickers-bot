# Verify Age - Flutter App

Приложение для подтверждения возраста с использованием сканирования лица.

## Сборка

```bash
flutter pub get
flutter build apk --release
```

## GitHub Actions

Для автоматической сборки APK через GitHub Actions используйте workflow из `.github/workflows/build.yml`.

## Структура

- `lib/main.dart` — точка входа, настройка темы
- `lib/theme.dart` — цветовая система (light/dark)
- `lib/screens/home_screen.dart` — главный экран с 3 слайдами
- `lib/widgets/` — переиспользуемые виджеты
- `lib/painters/` — кастомные рисовальщики (кольцо сканера)

## Экраны

1. **Intro** — приветственный экран с фичами и кнопкой "Начать"
2. **Code** — ввод 5-значного кода с кастомной клавиатурой
3. **Verification** — сканирование лица, FAQ, кнопка Telegram
