# Runway

Semester-based budgeting for college students. Plans by term, not month;
manual entry only (no bank linking).

## Run

```sh
flutter run -d macos   # debug: shows the app inside an iPhone 16 Pro Max frame
flutter test
```

Gemini (later): pass `--dart-define=GEMINI_API_KEY=...` and implement
`AffordabilityCoach` in `lib/app/coach.dart`, sending `CoachGrounding.toJson()`
as context.

## Layout

- `lib/app` — theme + motion tokens, models, pure runway maths, coach, repository, `AppState`
- `lib/widgets` — glass cards, pressable, aurora, rolling numbers, Mochi
- `lib/screens` — shell/nav, Home, Coach, Squad, Quick Add sheet
