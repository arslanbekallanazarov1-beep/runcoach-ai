import 'package:flutter/widgets.dart';

class AppStrings {
  const AppStrings._(this.isRussian);

  factory AppStrings.of(BuildContext context) {
    return AppStrings._(Localizations.localeOf(context).languageCode == 'ru');
  }

  final bool isRussian;

  String get appName => 'RunCoach';
  String get language => isRussian ? 'Язык' : 'Language';
  String get switchToLight =>
      isRussian ? 'Включить светлую тему' : 'Switch to light mode';
  String get switchToDark =>
      isRussian ? 'Включить тёмную тему' : 'Switch to dark mode';
  String get tagline => isRussian
      ? 'Небольшой прогресс с каждой пробежкой.'
      : 'A little progress, every run.';
  String get runDetails => isRussian ? 'Параметры пробежки' : 'Run details';
  String get formIntro => isRussian
      ? 'Добавьте показатели и получите следующий шаг.'
      : 'Add your stats and get a clear next step.';
  String get distance => isRussian ? 'Расстояние' : 'Distance';
  String get duration => isRussian ? 'Время' : 'Duration';
  String get minutes => isRussian ? 'мин' : 'min';
  String get averageHeartRate =>
      isRussian ? 'Средний пульс' : 'Average heart rate';
  String get effort => isRussian ? 'Усилие (RPE)' : 'Effort (RPE)';
  String get effortHelper => isRussian
      ? '1 = очень легко · 10 = максимум'
      : '1 = very easy · 10 = maximum effort';
  String get analyzeRun => isRussian ? 'Анализ пробежки' : 'Analyze Run';
  String get analyzingRun => isRussian ? 'Анализируем…' : 'Analyzing run…';
  String get recentRuns => isRussian ? 'Недавние пробежки' : 'Recent runs';
  String get noRuns => isRussian
      ? 'Здесь появятся проанализированные пробежки.'
      : 'Your analyzed workouts will show up here.';
  String runTitle(double distanceKm) => isRussian
      ? '${distanceKm.toStringAsFixed(1)} км пробежка'
      : '${distanceKm.toStringAsFixed(1)} km run';
  String get runAnalysis => isRussian ? 'Анализ пробежки' : 'Your run analysis';
  String get pace => isRussian ? 'Темп' : 'Pace';
  String get intensity => isRussian ? 'Интенсивность' : 'Intensity';
  String get trainingLoad =>
      isRussian ? 'Тренировочная нагрузка' : 'Training load';
  String get nextWorkout => isRussian ? 'Следующая тренировка' : 'Next workout';
  String get coachNote =>
      isRussian ? 'Совет тренера' : 'A note from your coach';
  String get shareRun => isRussian ? 'Поделиться пробежкой' : 'Share run';
  String get shareRunCard =>
      isRussian ? 'Поделиться карточкой' : 'Share run card';
  String get downloadRunCard =>
      isRussian ? 'Скачать карточку' : 'Download share card';
  String get preparingCard =>
      isRussian ? 'Подготовка карточки…' : 'Preparing card…';
  String get cardShared =>
      isRussian ? 'Карточка отправлена.' : 'Run card shared.';
  String get cardDownloaded =>
      isRussian ? 'Карточка скачана.' : 'Run card downloaded.';
  String get sharingCancelled =>
      isRussian ? 'Отправка отменена.' : 'Sharing cancelled.';
  String get shareResultUnknown => isRussian
      ? 'Окно отправки закрыто, результат не подтверждён.'
      : 'The share sheet opened, but the result could not be confirmed.';
  String get exportFailed => isRussian
      ? 'Не удалось экспортировать карточку'
      : 'Could not export run card';
  String get runCoachServerUnavailable => isRussian
      ? 'Не удалось связаться с сервером RunCoach. Проверьте, что сервер запущен и устройство может к нему подключиться.'
      : 'Could not reach the RunCoach server. Check that it is running and your device can connect.';
  String get historyServerUnavailable => isRussian
      ? 'Не удалось загрузить недавние пробежки. Проверьте, что сервер RunCoach запущен.'
      : 'Could not load recent runs. Check that the RunCoach server is running.';
  String get retry => isRussian ? 'Повторить' : 'Retry';
  String get serverAnalyzeFailed => isRussian
      ? 'Сервер не смог проанализировать пробежку (HTTP {status}). Проверьте данные и попробуйте ещё раз.'
      : 'The server could not analyze this run (HTTP {status}). Check the run details and try again.';
  String get serverHistoryFailed => isRussian
      ? 'Сервер не смог загрузить историю пробежек (HTTP {status}).'
      : 'The server could not load run history (HTTP {status}).';
  String get unexpectedAnalysisResponse => isRussian
      ? 'Сервер вернул неожиданный ответ анализа.'
      : 'The server returned an unexpected analysis response.';
  String get unexpectedHistoryResponse => isRussian
      ? 'Сервер вернул неожиданный ответ истории пробежек.'
      : 'The server returned an unexpected run history response.';
  String get invalidDistance => isRussian
      ? 'Введите расстояние больше 0.'
      : 'Enter a distance greater than 0.';
  String get invalidDuration =>
      isRussian ? 'Введите время больше 0.' : 'Enter a time greater than 0.';
  String get invalidHeartRate => isRussian
      ? 'Введите пульс больше 0.'
      : 'Enter a heart rate greater than 0.';
  String get sleepHours => isRussian ? 'Сон прошлой ночью' : 'Sleep last night';
  String get restingHeartRate =>
      isRussian ? 'Пульс в покое' : 'Resting heart rate';
  String get recoveryMetrics =>
      isRussian ? 'Показатели восстановления' : 'Recovery metrics (optional)';
  String get hoursUnit => isRussian ? 'ч' : 'hr';
  String get invalidSleepHours => isRussian
      ? 'Введите продолжительность сна от 0 до 24 часов.'
      : 'Enter sleep duration between 0 and 24 hours.';
  String get invalidRestingHeartRate => isRussian
      ? 'Введите пульс в покое от 30 до 240 уд/мин.'
      : 'Enter a resting heart rate between 30 and 240 bpm.';
  String get kilometersOfProgress =>
      isRussian ? 'КИЛОМЕТРЫ ПРОГРЕССА' : 'KILOMETERS OF PROGRESS';
  String get kilometersShort => isRussian ? 'км' : 'km';
  String get calories => isRussian ? 'КАЛОРИИ' : 'CALORIES';
  String get calorieDisclaimer => isRussian
      ? '*Примерная оценка калорий · маршрут показан для иллюстрации'
      : '*Estimated calories · route graphic is illustrative';
  String get metricsDisclaimer => isRussian
      ? 'Показатели рассчитываются по правилам RunCoach.'
      : 'Your training metrics are calculated by RunCoach rules.';
  String get trainingPlan => isRussian ? 'План тренировок' : 'Training plan';
  String get planGoal => isRussian ? 'Цель' : 'Goal';
  String get goalHint =>
      isRussian ? 'Например, полумарафон Алматы' : 'e.g. Almaty Half Marathon';
  String get fitnessLevel => isRussian ? 'Уровень подготовки' : 'Fitness level';
  String get beginner => isRussian ? 'Начинающий' : 'Beginner';
  String get intermediate => isRussian ? 'Средний' : 'Intermediate';
  String get advanced => isRussian ? 'Продвинутый' : 'Advanced';
  String get timeline => isRussian ? 'Срок (недели)' : 'Timeline (weeks)';
  String get generatePlan => isRussian ? 'Составить план' : 'Generate plan';
  String get generatingPlan =>
      isRussian ? 'Составляем план…' : 'Generating plan…';
  String get planIntro => isRussian
      ? 'Расскажите о цели и сроке — тренер составит недельное расписание.'
      : 'Set your goal and timeline to get a week-by-week training schedule.';
  String get planOverview => isRussian ? 'О плане' : 'Plan overview';
  String week(int number) => isRussian ? 'Неделя $number' : 'Week $number';
  String get weekFocus => isRussian ? 'Фокус недели' : 'Weekly focus';
  String get minutesUnit => isRussian ? 'мин' : 'min';
  String get planGenerationFailed => isRussian
      ? 'Не удалось составить план. Проверьте подключение и попробуйте ещё раз.'
      : 'Could not generate a plan. Check your connection and try again.';
  String get planProviderNotConfigured => isRussian
      ? 'Создание плана не настроено на сервере. Обратитесь к администратору.'
      : 'Plan generation is not configured on the server. Contact the administrator.';
  String get planProviderTimeout => isRussian
      ? 'Сервис планов не успел ответить. Попробуйте ещё раз.'
      : 'The plan service took too long to respond. Please try again.';
  String get planProviderUnavailable => isRussian
      ? 'Сервис планов временно недоступен. Попробуйте позже.'
      : 'The plan service is temporarily unavailable. Please try again later.';
  String get planInvalidResponse => isRussian
      ? 'Сервис планов вернул некорректный план. Попробуйте ещё раз.'
      : 'The plan service returned an invalid plan. Please try again.';
  String get planServerRequestFailed => isRussian
      ? 'Не удалось выполнить запрос плана (HTTP {status}).'
      : 'The plan request failed (HTTP {status}).';
  String get enterGoal => isRussian ? 'Введите цель.' : 'Enter a goal.';
  String get invalidWeeks => isRussian
      ? 'Введите срок от 1 до 52 недель.'
      : 'Enter a timeline between 1 and 52 weeks.';
  String get trainingNav => isRussian ? 'Тренировки' : 'Runs';
  String get planNav => isRussian ? 'План' : 'Plan';
  String get shoesNav => isRussian ? 'Обувь' : 'Shoes';
  String get shoesTitle => isRussian ? 'Мои кроссовки' : 'My running shoes';
  String get shoesIntro => isRussian
      ? 'Выберите пару для пробежки — километраж будет учитываться автоматически.'
      : 'Choose the pair used for a run; mileage is tracked automatically.';
  String get shoeName => isRussian ? 'Название пары' : 'Shoe name';
  String get shoeNameHint =>
      isRussian ? 'Например, Daily trainers' : 'e.g. Daily trainers';
  String get startingMileage =>
      isRussian ? 'Текущий пробег (км)' : 'Current mileage (km)';
  String get addShoe => isRussian ? 'Добавить пару' : 'Add shoes';
  String get noShoes => isRussian
      ? 'Добавьте первую пару кроссовок.'
      : 'Add your first pair of shoes.';
  String get selectShoes =>
      isRussian ? 'Кроссовки для этой пробежки' : 'Shoes used for this run';
  String get noShoeSelected => isRussian ? 'Не выбраны' : 'None selected';
  String get addShoesToSelect => isRussian
      ? 'Добавьте пару на вкладке «Обувь».'
      : 'Add a pair in the Shoes tab.';
  String get mileage => isRussian ? 'Пробег' : 'Mileage';
  String get replaceShoes =>
      isRussian ? 'Пора заменить кроссовки' : 'Time to replace shoes';
  String get gearStorageFailed => isRussian
      ? 'Не удалось сохранить данные об обуви.'
      : 'Could not save shoe data.';
  String get racePredictor =>
      isRussian ? 'Прогноз результата' : 'Race time predictor';
  String get predictionBasedOn => isRussian
      ? 'Оценка по последней пробежке'
      : 'Estimate based on your latest run';
  String get halfMarathon => isRussian ? 'Полумарафон' : 'Half marathon';
  String get marathon => isRussian ? 'Марафон' : 'Marathon';
  String get audioCoach => isRussian ? 'Озвучить совет' : 'Read coach tip';
  String get stopAudio =>
      isRussian ? 'Остановить озвучивание' : 'Stop speaking';
  String get speechUnavailable => isRussian
      ? 'Не удалось запустить голосовой тренер на этом устройстве.'
      : 'Text-to-speech is unavailable on this device.';
  String audioCoachSummary(
    String pace,
    String recommendation,
    String feedback,
  ) =>
      isRussian
          ? 'Темп: $pace на километр. Следующая тренировка: $recommendation. $feedback'
          : 'Pace: $pace per kilometer. Next workout: $recommendation. $feedback';
  String audioWeatherSummary({
    required String temperature,
    required String description,
    required String clothing,
    required String pace,
    required String plan,
  }) =>
      isRussian
          ? 'Погода: $temperature, $description. Совет по одежде: $clothing '
              'Темп: $pace на километр. План на сегодня: $plan.'
          : 'Weather: $temperature, $description. Clothing tip: $clothing '
              'Pace guidance: $pace per kilometer. Today’s plan: $plan.';
  String morningBriefing({
    required String temperature,
    required String description,
    required String clothing,
    required String plan,
  }) =>
      isRussian
          ? 'Доброе утро! Сегодня на улице $temperature, $description. '
              'Мы рекомендуем выбрать $clothing для максимальной свободы движений. '
              'Не забудьте взять с собой немного воды, чтобы поддерживать водный '
              'баланс на дистанции. План на сегодня: $plan. Желаем вам '
              'продуктивного забега и отличного настроения на весь день.'
          : 'Good morning! Outside today it is $temperature, $description. '
              'We recommend choosing $clothing for maximum freedom of movement. '
              'Do not forget to bring some water to stay hydrated on your run. '
              'Today’s plan: $plan. We wish you a productive run and a great mood '
              'all day long.';
  String get mileageRecorded =>
      isRussian ? 'Пробег кроссовок обновлён.' : 'Shoe mileage updated.';
  String get shoeNameRequired =>
      isRussian ? 'Введите название пары.' : 'Enter a shoe name.';
  String get invalidMileage => isRussian
      ? 'Введите корректный пробег от 0 км.'
      : 'Enter valid mileage of 0 km or more.';
  String get deleteShoe => isRussian ? 'Удалить пару' : 'Remove shoes';
  String get shoeStorageUnavailable => isRussian
      ? 'Не удалось загрузить данные об обуви. Повторите попытку.'
      : 'Could not load shoe data. Please retry.';
  String raceDistance(double distanceKm) => switch (distanceKm) {
        5 => '5K',
        10 => '10K',
        21.0975 => halfMarathon,
        _ => marathon,
      };
  String get recoverySafety => isRussian
      ? 'Увеличивайте нагрузку постепенно и отдыхайте при боли.'
      : 'Build gradually and rest if you experience pain.';
  String get authLogin => isRussian ? 'Войти' : 'Log in';
  String get authSignUp => isRussian ? 'Создать аккаунт' : 'Create an account';
  String get authCreateAccount => isRussian ? 'Зарегистрироваться' : 'Sign up';
  String get authNeedAccount => isRussian
      ? 'Нет аккаунта? Зарегистрируйтесь'
      : 'New here? Create an account';
  String get authHaveAccount => isRussian
      ? 'Уже есть аккаунт? Войдите'
      : 'Already have an account? Log in';
  String get authEmail => isRussian ? 'Электронная почта' : 'Email';
  String get authPassword => isRussian ? 'Пароль' : 'Password';
  String get authFirstName => isRussian ? 'Имя' : 'First name';
  String get authLastName => isRussian ? 'Фамилия' : 'Last name';
  String get authPasswordHint =>
      isRussian ? 'Не менее 8 символов' : 'At least 8 characters';
  String get authRequired =>
      isRussian ? 'Обязательное поле.' : 'This field is required.';
  String get authInvalidEmail =>
      isRussian ? 'Введите корректную почту.' : 'Enter a valid email address.';
  String get authPasswordInvalid => isRussian
      ? 'Пароль должен содержать не менее 8 символов.'
      : 'Password must contain at least 8 characters.';
  String get authInvalidCredentials => isRussian
      ? 'Почта или пароль неверны.'
      : 'Email or password is incorrect.';
  String get authEmailAlreadyRegistered => isRussian
      ? 'Аккаунт с такой почтой уже существует.'
      : 'An account with this email already exists.';
  String get authRequestFailed => isRussian
      ? 'Не удалось выполнить вход. Проверьте данные и повторите попытку.'
      : 'Could not authenticate. Check your details and try again.';
  String get authSessionLoadFailed => isRussian
      ? 'Не удалось загрузить сессию. Повторите запуск приложения.'
      : 'Could not restore your session. Please restart the app.';
  String get authContinueToLogin =>
      isRussian ? 'Перейти ко входу' : 'Continue to sign in';
  String get authLogout => isRussian ? 'Выйти' : 'Log out';
  String get authLogoutConfirm => isRussian
      ? 'Вы уверены, что хотите выйти?'
      : 'Are you sure you want to log out?';
  String get cancel => isRussian ? 'Отмена' : 'Cancel';
  String get profile => isRussian ? 'Профиль' : 'Profile';
  String get addWorkout => isRussian ? 'Добавить тренировку' : 'Add workout';
  String get deleteWorkout => isRussian ? 'Удалить' : 'Delete';
  String get deleteWorkoutConfirm =>
      isRussian ? 'Удалить эту тренировку?' : 'Delete this workout?';
  String get historyDeleteFailed => isRussian
      ? 'Не удалось удалить пробежку. Попробуйте ещё раз.'
      : 'Could not delete the run. Please try again.';
  String get runDeleteFailed => isRussian
      ? 'Не удалось связаться с сервером для удаления пробежки.'
      : 'Could not reach the server to delete this run.';
  String get serverRunDeleteFailed => isRussian
      ? 'Сервер не смог удалить пробежку (HTTP {status}).'
      : 'The server could not delete this run (HTTP {status}).';
  String get totalDistance => isRussian ? 'Общая дистанция' : 'Total distance';
  String get totalTime => isRussian ? 'Общее время' : 'Total time';
  String get avgPace => isRussian ? 'Средний темп' : 'Average pace';
  String get authLogoutFailed =>
      isRussian ? 'Не удалось завершить сессию.' : 'Could not end the session.';
  String get weatherNav => isRussian ? 'Погода' : 'Weather';
  String get weatherTitle =>
      isRussian ? 'Погода и экипировка' : 'Weather & gear';
  String get weatherIntro => isRussian
      ? 'Прогноз и совет по одежде для вашей пробежки.'
      : 'Get the forecast and a clothing tip for your run.';
  String get weatherLocation => isRussian ? 'Местоположение' : 'Location';
  String get currentLocation =>
      isRussian ? 'Текущее местоположение' : 'Current location';
  String get locating =>
      isRussian ? 'Определяем местоположение…' : 'Finding your location…';
  String get locationFallback => isRussian
      ? 'Местоположение недоступно. Выберите город.'
      : 'Location is unavailable. Choose a city.';
  String get cityAlmaty => isRussian ? 'Алматы' : 'Almaty';
  String get cityAstana => isRussian ? 'Астана' : 'Astana';
  String get cityShymkent => isRussian ? 'Шымкент' : 'Shymkent';
  String get cityKaraganda => isRussian ? 'Караганда' : 'Karaganda';
  String get cityAktau => isRussian ? 'Актау' : 'Aktau';
  String get latitude => isRussian ? 'Широта' : 'Latitude';
  String get longitude => isRussian ? 'Долгота' : 'Longitude';
  String get loadWeather => isRussian ? 'Узнать погоду' : 'Get weather';
  String get loadingWeather =>
      isRussian ? 'Загружаем прогноз…' : 'Loading forecast…';
  String get currentConditions => isRussian ? 'Сейчас' : 'Current conditions';
  String get todayForecast =>
      isRussian ? 'Прогноз на сегодня' : 'Today’s forecast';
  String get feelsLike => isRussian ? 'Ощущается как' : 'Feels like';
  String get windSpeed => isRussian ? 'Ветер' : 'Wind';
  String get precipitationChance =>
      isRussian ? 'Вероятность осадков' : 'Precipitation chance';
  String get clothingAdvice =>
      isRussian ? 'Совет по экипировке' : 'What to wear';
  String get todayPlan => isRussian ? 'План на сегодня' : 'Today’s plan';
  String get todayPlanHint =>
      isRussian ? 'Например, лёгкий бег 30 минут' : 'e.g. easy 30-minute run';
  String get defaultTodayPlan => isRussian
      ? 'Лёгкий бег в разговорном темпе'
      : 'Easy run at a conversational pace';
  String get comfortablePace => isRussian ? 'Комфортный' : 'Comfortable';
  String get humidity => isRussian ? 'Влажность' : 'Humidity';
  String get sendMorningBriefing =>
      isRussian ? 'Отправить утреннее сообщение' : 'Send morning briefing';
  String get notificationSent =>
      isRussian ? 'Утреннее сообщение отправлено.' : 'Morning briefing sent.';
  String get notificationUnavailable => isRussian
      ? 'Не удалось отправить уведомление. Разрешите уведомления и повторите попытку.'
      : 'Could not send notification. Allow notifications and try again.';
  String get weatherLoadFailed => isRussian
      ? 'Не удалось получить прогноз. Проверьте подключение и попробуйте ещё раз.'
      : 'Could not load weather. Check your connection and try again.';
  String temperatureC(double value) => '${value.round()}°C';
  String get challengesNav => isRussian ? 'Вызовы' : 'Challenges';
  String get challengesTitle =>
      isRussian ? 'Вызовы и темп' : 'Challenges & pace';
  String get challengesIntro => isRussian
      ? 'Локальные идеи для мотивации. Соревнования и GPS-трекинг пока не включены.'
      : 'Local motivation ideas. Competitions and GPS tracking are not enabled.';
  String get localChallenge =>
      isRussian ? 'Локальные вызовы' : 'Local challenges';
  String get consistencyChallenge => isRussian
      ? 'Регулярность: три пробежки за неделю'
      : 'Consistency: three runs this week';
  String get distanceChallenge =>
      isRussian ? 'Наберите 10 км за неделю' : 'Run 10 km this week';
  String get challengeRuns => isRussian ? 'пробежки' : 'runs';
  String get virtualPacemakerDuel =>
      isRussian ? 'Дуэль с виртуальным пейсмейкером' : 'Virtual pacemaker duel';
  String get pacemakerPlaceholder => isRussian
      ? 'Скоро: задайте темп и сравните результат с виртуальным пейсмейкером.'
      : 'Coming soon: set a pace and compare your run with a virtual pacemaker.';
  String get previewOnly =>
      isRussian ? 'Предварительный просмотр' : 'Preview only';
  String get heartRateZones =>
      isRussian ? 'Пульсовые зоны' : 'Heart rate zones';
  String get maximumHeartRate => isRussian ? 'Макс. пульс' : 'Max HR';
  String get age => isRussian ? 'Возраст' : 'Age';
  String get years => isRussian ? 'лет' : 'years';
  String get zoneRange => isRussian ? 'Диапазон' : 'Range';
  String get bpm => isRussian ? 'уд/мин' : 'bpm';
  String get saveProfile => isRussian ? 'Сохранить профиль' : 'Save profile';
  String get savingProfile => isRussian ? 'Сохраняем…' : 'Saving…';
  String get profileSaved =>
      isRussian ? 'Профиль обновлён.' : 'Profile updated.';
  String get profileSaveFailed =>
      isRussian ? 'Не удалось обновить профиль.' : 'Could not update profile.';
  String get invalidMaxHeartRate => isRussian
      ? 'Максимальный пульс должен быть от 120 до 240 уд/мин.'
      : 'Maximum heart rate must be between 120 and 240 bpm.';
  String get invalidAge => isRussian
      ? 'Возраст должен быть от 10 до 120 лет.'
      : 'Age must be between 10 and 120.';
  String get setMaxHeartRateForZones => isRussian
      ? 'Укажите максимальный пульс, чтобы увидеть тренировочные зоны.'
      : 'Set your maximum heart rate to see your training zones.';
  String get heartRateZonesLoadFailed => isRussian
      ? 'Не удалось загрузить пульсовые зоны.'
      : 'Could not load heart rate zones.';
}
