# LineOfBots — документация по написанию модов (для ИИ-агентов)

> **Версия мод-лоадера:** v24.6 · **Версия кита:** 2 · **Скрипт:** `lineofgui2.lua` (лежит рядом в этой папке)
> **Читатель этого документа:** ИИ-агент, которому поручили написать мод для LineOfBots.
> Документ описывает РЕАЛЬНЫЙ, реализованный API. Всё, что здесь написано, существует
> в коде скрипта. Ничего не выдумывай: если API нет в этом документе — его нет.
>
> **Дополнение v24.5–v24.6:** новый API (`api.hint`, `api.ability`, `api.say`, `api.version`),
> гарантии отказоустойчивости и масштабный багфикс мод-лоадера описаны в
> **MODDING_KIT_ADDENDUM_v24.6.md** (лежит рядом; читай после этого документа).

---

## 0. Правила для ИИ-агента (прочти первым)

1. **Формат ответа:** один самодостаточный `.lua`-файл. Без внешних зависимостей
   (если нужна библиотека — либо напиши её внутри мода, либо см. §6.11 про `LineOfBots/libs`).
2. **Пользователь сам установит мод:** сохранит файл в папку `LineOfBots/mods`
   (она появится рядом с инжектором после первого запуска LineOfBots) и перезайдёт в игру.
   Это и есть «установка» — других действий не нужно.
3. **Имена функций и событий бери ТОЛЬКО из этого документа.** Событие/метод из
   фантазии = мод не сработает (а обращение к nil-полю = ошибка в журнале).
4. **Скрипт — Roblox executor окружение:** доступны `game`, `workspace`, `Players`,
   `task.*`, `Instance`, `Vector3`, `CFrame`, `Color3`, `UDim2`, `Enum`, executor-функции
   (`readfile`, `writefile`, `listfiles`, `isfile`, `isfolder`, `makefolder`,
   `loadstring`, `hookfunction`/`hookfunc`, `setfenv`, `getfenv`), `HttpClient`/`request`.
   Это Lua 5.1-совместимый Luau: `continue` и `goto` в модах НЕ используй.
5. **Любая ошибка мода не крашит бота** (см. §3), но портит впечатление — пиши код так,
   будто каждая внешняя сущность может быть nil: проверяй `if x then ... end`.
6. Перед выдачей ответа прогони мод мысленно по **чеклисту §13**.

---

## 1. Состав комплекта

| Файл | Что это |
|---|---|
| `MODDING_FOR_AI.md` | этот документ |
| `MODDING_KIT_ADDENDUM_v24.6.md` | дополнение: новый API v24.5–v24.6, багфикс лоадера — читать вторым |
| `lineofgui2.lua` | полный исходник LineOfBots (~19.5 тыс. строк) — истина в последней инстанции |
| `mods_examples/example_mod.lua` | встроенный пример (скрипт сам создаёт его копию в `mods/`) |
| `mods_examples/mod_chat_stats.lua` | образец: события + своя вкладка + хранилище |
| `mods_examples/mod_prompt_rules.lua` | образец: хук промпта + свой `[DO:тег]` + фолбэк |
| `mods_examples/mod_gui_style.lua` | образец: замена текстов GUI + своя тема |

**Как искать истину в `lineofgui2.lua`:** в шапке файла есть карта §-маркеров,
а сами маркеры расставлены по коду (`§CHAT_SEND`, `§SYSPROMPT`, `§MODLOADER`, …).
Полная карта — в §11 этого документа. Лоадер модов — блок `§MODLOADER` (~строка 11680).

---

## 2. Папка LineOfBots (файловая система инжектора)

Корень = папка самого инжектора. Скрипт создаёт структуру сам при каждом запуске:

```
<папка инжектора>/
└── LineOfBots/
    ├── configs/                  настройки и служебные файлы
    │   ├── lob_settings.txt      ClientSettings (сериализованный Lua-таблицей)
    │   ├── lob_apikey.txt / lob_apikey2.txt / lob_apikey3.txt   Groq-ключи
    │   ├── lob_geminikey.txt / lob_deepseekkey.txt              ключи провайдеров
    │   ├── lob_customprompt.txt  дополнительный системный промпт
    │   ├── lob_model.txt         выбранная модель
    │   ├── mods_disabled.txt     по строке-имени: какие моды выключены
    │   ├── mods_pending.txt      строки «имя=on/off»: отложенный тоггл («перезайдите»)
    │   ├── mods_meta.txt         кэш меты модов (иконка/название видны даже выключенными)
    │   └── data/                 хранилища модов: data/<имя мода>.data
    ├── mods/                     ← СЮДА КЛАДУТ МОДЫ (.lua / .luau / .lobmod)
    │   └── example_mod.lua       создаётся автоматически, если папка пуста
    └── libs/                     общие библиотеки (.lua), грузятся ДО модов
```

Правила папки `mods`:
- **имя файла = имя мода** (`my_mod.lua` → мод `my_mod`). Два файла с одним базовым
  именем не уживаются: повторная загрузка выгружает предыдущую версию.
- файл, начинающийся с `_`, игнорируется (способ «выключить без удаления»).
- порядок загрузки — алфавитный (по полному пути, `table.sort`).
- библиотеки из `libs/` грузятся раньше модов и доступны всем через `api.lib("имя файла")`.
- файлы `mods_disabled.txt`/`mods_pending.txt`/`mods_meta.txt` в `mods/` модами не считаются.

---

## 3. Жизненный цикл и защита от краша

```
запуск LineOfBots → createInterface() (GUI собран) → LOB_MODS.init()
  → ждёт 0.6с → loadAll():
      1) главный тумблер ClientSettings.ModLoader выключен? → лоадер молчит (§6.3)
      2) инжектор без readfile+listfiles? → уведомление «моды недоступны», выход
      3) создать папки, выгрузить прежние моды, загрузить libs/
      4) список файлов mods/ (алфавитно) → для каждого:
           • выключен (есть в mods_disabled.txt)? → зарегистрировать «отключён»,
             мета берётся из кэша mods_meta.txt — карточка с иконкой всё равно видна
           • иначе → loadOne():
               a) readfile → loadstring(код)  ← КОМПИЛЯЦИЯ ДО ЗАПУСКА
                  синтаксическая ошибка → мод помечен «ошибка синтаксиса», текст ошибки
                  в карточке и журнале, КОД НЕ ИСПОЛНЯЕТСЯ. Бот продолжает работать.
               b) создать API (makeAPI), окружение мода:
                  setfenv(chunk, setmetatable({lob=api, api=api},
                        {__index = _G, __newindex = запись в _G}))
                  → мод ВИДИТ все глобалы скрипта; необъявленная переменная в моде
                    со значением `X = 1` ПЕРЕЗАПИШЕТ ГЛОБАЛ СКРИПТА — не создавай
                    глобалы с «общими» именами (api, lob, x, temp…), юзай `local`!
               c) pcall(chunk, api) — runtime-ошибка → мод «ошибка», текст в журнале,
                  всё созданное им до ошибки остаётся зарегистрированным и убирается
                  при выключении тогглом.
               d) мод вернул таблицу? → берутся onUnload/onUIRebuild/meta
               e) событие modLoaded, уведомление, обновление вкладки «Моды»
      5) очистить mods_pending.txt, лог «загружено модов: N», событие modsLoaded
```

**Мгновенный тоггл в GUI «Моды»:**
- **выключить** (мод instant): `setDisabled(имя, true)` → `unloadOne(имя)` (авто-уборка,
  см. §5) → регистрируется заглушка «отключён» (карточка и мета остаются видны).
- **включить**: `setDisabled(имя, false)` → `loadOne(путь)` заново.
- **выключить/включить (мод требует перезапуск)**: пишется `mods_pending.txt`
  (`имя=off`/`имя=on`), в карточке статус «перезайдите…», применяется при следующем
  запуске, файл pending очищается.

**Что unloadOne чистит автоматически (при мгновенной выгрузке):**
`onUnload()` мода → таймеры (`api.every/delay`) → соединения (`api.connect`) →
хуки `hookfunction` (откат в обратном порядке) → свои `[DO:теги]` и их подсказки
в промпте → патчи глобалов (`api.patch/override`) → заменённые тексты GUI
(`api.ui.setTexts`, откат v24.2) → инстансы UI → свои вкладки.

---

## 4. Каркас мода (используй как шаблон)

```lua
--[[ <Название мода> для LineOfBots (v24.6) — краткое описание ]]

local api = lob            -- API мода. Эквивалент: local api = (...)

-- 1) МЕТА — как мод выглядит во вкладке «Моды» (см. §5)
lob.meta{
    title       = "Название",
    icon        = "🧩",              -- эмодзи ИЛИ "rbxassetid://ID"
    description = "что делает",
    instant     = true,              -- см. §5 про тоггл
}

-- 2) СОСТОЯНИЕ — только local! (глобал из мода попадёт в _G скрипта)
local enabled = true

-- 3) ЛОГИКА
api.on("chat", function(player, msg)
    if not enabled then return end   -- тоггл-гейт
end)

-- 4) UI (см. §6.7)
api.ui.ensureTab("Мой мод", "🧩")
api.ui.addToggle("Мой мод", "Опции", "Включено", "описание", true, function(on)
    enabled = on
end)

-- 5) УБОРКА (мгновенный тоггл зовёт сам; таймеры/коннекты/UI чистятся и без тебя)
api.onUnload(function()
    api.saveData()
end)
```

Альтернативная точка входа: последней строкой файла `return { meta = {...},
onUnload = function() end, onUIRebuild = function() end }` — таблица опциональна.

---

## 5. Мета и логика тоггла «вкл/выкл»

`lob.meta{ ... }` (алиас `api.meta{ ... }`) принимает:

| Поле | Тип | Смысл |
|---|---|---|
| `title` | string | название в карточке (по умолчанию — имя файла) |
| `icon` | string | эмодзи (приклеится к названию) или `"rbxassetid://ID"` / `http(s)`-URL (вставится картинкой) |
| `description` | string | подпись в статусной строке карточки |
| `instant` | bool | `true`/nil → тоггл работает мгновенно; `false` → нужен перезапуск |
| `requiresRejoin` | bool | `true` → то же, что `instant=false` (для активации тоже нужен перезапуск) |

**Как выбрать `instant`:** если всё, что делает мод, завязано на события/таймеры/
`api.hook`/`api.patch`/UI — оставляй мгновенный тоггл (лоадер всё откатит сам).
Ставь `instant = false` (или `requiresRejoin = true`), только если мод меняет то,
что нельзя корректно откатить на живую: значения, прочитанные кем-то один раз при
старте, замыкания, удерживающие старые ссылки, и т.п.

Тексты, которые увидит пользователь:
- мгновенно выключается: статус «выключен»;
- требует перезапуска: «перезайдите, чтобы можно было его отключить (сейчас ещё работает)»
  либо «перезайдите, чтобы можно было его включить».

Мета кэшируется в `configs/mods_meta.txt` — иконка/название видны, даже когда мод выключен.

---

## 6. Полный API мода (`lob` == `api` == первый аргумент чанка)

### 6.1 Информация

| Поле | Тип | Значение |
|---|---|---|
| `api.name` | string | имя мода (= имя файла без расширения) |
| `api.folder` | string | путь к папке модов (`LineOfBots/mods`) |
| `api.version` | string | версия лоадера (`v24.6`) |
| `api.loader` | table | живая ссылка на `LOB_MODS` (можно чинить сам лоадер) |
| `api.core` | table | мост к ядру скрипта (§6.10) |
| `api.settings` | table | прямая ссылка на `ClientSettings` (§6.3) |

### 6.2 Глобалы скрипта: `get / set / override / patch / restore`

Работают **только с именными глобалами** (`_G`): `ClientSettings`, `LOB_CORE`,
`LOB_MODS`, `LOB_UI`, `_smartWalk`, `_SW`, `_rel`, `_lastChatAt`, `CurrentGui`,
`NotifyHost`, `_guiScale` и т.п. Локали главного чанка (а это почти все функции
скрипта) так НЕ достать — для них §6.8 `api.hook`.

| Вызов | Что делает |
|---|---|
| `api.get(name)` | прочитать глобал `name` |
| `api.set(name, value)` | записать глобал `name` |
| `api.patch(name, wrapper)` | обернуть глобал-функцию: `wrapper(old, ...)` должен вернуть результат; старое значение сохраняется в стек |
| `api.override(name, fn)` | заменить глобал-функцию целиком; старое сохраняется в стек |
| `api.restore(name)` | откатить последний patch/override имени |

Патчи откатываются автоматически при выгрузке мода (в обратном порядке).

### 6.3 Настройки бота

| Вызов | Что делает |
|---|---|
| `api.settings` | сама таблица `ClientSettings` — любой ключ читать/писать напрямую |
| `api.getSetting(key)` | `ClientSettings[key]` |
| `api.setSetting(key, value, noSave)` | записать; `noSave=true` — не сохранять на диск сразу |

Полезные ключи `ClientSettings` (объяви их при чтении, если пишешь новые:
`ClientSettings.МойКлюч = ClientSettings.МойКлюч or дефолт`):
`Enabled`, `AutoReply` (бот вообще отвечает), `ActionsEnabled` (исполнение `[DO:...]`),
`MemoryEnabled`, `InventoryEnabled`, `UsePlayerName`, `Theme`, `ModLoader`
(**главный рубильник мод-лоадера**: `false` → моды вообще не грузятся),
`CustomSystemPrompt` (доп. текст в системный промпт — фолбэк для хука промпта),
`Models` (таблица выбранной модели по провайдерам), `UI` (`WindowWidth/WindowHeight`).
Полный список и дефолты — в скрипте, блок `§SETTINGS` (~262).

### 6.4 События: `api.on(event, fn)`

| Событие | Аргументы fn | Когда срабатывает |
|---|---|---|
| `chat` | `(player, text)` | **в самом начале** `processChatMessage` — для КАЖДОГО сообщения игроков, даже когда бот выключен |
| `botSay` | `(text)` | бот отправляет реплику в чат (в начале `sendChatMessage`) |
| `action` | `(name, player, arg)` | ПОСЛЕ исполнения обработчика `[DO:тег]` |
| `playerJoin` | `(player)` | `Players.PlayerAdded` |
| `playerLeave` | `(player)` | `Players.PlayerRemoving` |
| `tick` | `(dt)` | каждый кадр (`RunService.Heartbeat`) |
| `modsLoaded` | `()` | в конце `loadAll()` — все моды загружены |
| `modLoaded` | `(name)` | после успешной загрузки мода (в т.ч. мгновенного включения) |
| `libLoaded` | `(name)` | библиотека из `libs/` загружена |
| `libDefined` | `(name)` | какой-то мод сделал `api.defineLib(name, …)` |
| `modExport` | `(name)` | какой-то мод сделал `api.export{…}` |
| `uiRebuild` | `()` | интерфейс пересобран (смена темы, `api.ui.rebuild()`) |

Ошибки колбэков ловятся и пишутся в журнал; обработчики мёртвого мода не вызываются.

### 6.5 Таймеры и соединения

| Вызов | Что делает |
|---|---|
| `api.every(sec, fn)` | цикл с интервалом `sec` (мин. 0.05); сам остановится при выгрузке мода |
| `api.delay(sec, fn)` | однократный отложенный вызов; отменяется при выгрузке |
| `api.connect(signal, fn)` | `signal:Connect(fn)` с автосоединением при выгрузке (для RBXScriptSignal) |

### 6.6 Хранилище: `api.data() / api.saveData()`

- `api.data()` при первом вызове читает `LineOfBots/configs/data/<имя мода>.data`
  (это Lua-файл вида `return {...}`) и возвращает таблицу (пустую, если файла нет).
- `api.saveData()` сериализует таблицу и пишет в тот же файл.
- **Формат:** строки, числа, булевы, вложенные таблицы (глубина ≤ 8). Функции,
  userdata, Roblox-инстансы, циклические ссылки — НЕЛЬЗЯ (сохранятся как nil/обрежутся).
- Переживает перезапуск игры и перезаход.

```lua
local d = api.data()
d.count = (d.count or 0) + 1
api.saveData()
```

### 6.7 Свой UI: `api.ui.*`

Секции внутри вкладок создаются автоматически при добавлении элементов.
Синтаксическая защита: ошибки колбэков тогглов/слайдеров/дропдаунов ловятся в журнал.

| Вызов | Что делает |
|---|---|
| `ui.ensureTab(tabName, icon?)` | создать свою вкладку (кнопка внизу сайдбара) ИЛИ вернуть скролл уже существующей. **Родные вкладки можно дополнять, только если они списочные:** «Основное», «Поведение», «Восприятие», «Настройки», «Information», «Моды»; для остальных вернёт nil и напишет в журнал «создай свою» |
| `ui.addSection(tabName, title, subtitle?)` | секция-карточка с заголовком; возвращает Content-фрейм |
| `ui.addLabel(tabName, text)` | строка текста; возвращает TextLabel |
| `ui.addToggle(tabName, sectionTitle, label, desc, initial, cb)` | тоггл; `cb(v)` получает bool; возвращает строку-ряд |
| `ui.addButton(tabName, sectionTitle, text, cb)` | кнопка; возвращает кнопку |
| `ui.addSlider(tabName, sectionTitle, label, desc, min, max, value, cb)` | слайдер; `cb(v)` — число |
| `ui.addDropdown(tabName, sectionTitle, label, desc, values, default, cb)` | дропдаун; `cb(v)` — выбранная строка |
| `ui.addTextbox(tabName, sectionTitle, label, desc, placeholder, cb)` | поле ввода; `cb(text)` на FocusLost |
| `ui.removeRow(rowInstance)` | удалить конкретный элемент |
| `ui.removeTab(tabName)` | удалить СВОЮ вкладку (родные защищены) |
| `ui.renameTab(old, new)` | переименовать СВОЮ вкладку |
| `ui.switchTab(tabName)` | открыть вкладку в GUI |
| `ui.tabExists(tabName)` | bool — вкладка существует |
| `ui.getTabFrame(tabName)` | сырой фрейм вкладки — парь туда ЛЮБЫЕ Roblox-элементы (`Instance.new(...)`) |
| `ui.bridge()` | вся таблица `LOB_UI` (§8) |
| `ui.walk(fn)` | обойти КАЖДЫЙ элемент интерфейса: `fn(instance)` |
| `ui.findText(str)` | массив всех TextLabel/TextButton/TextBox, чей `.Text` содержит `str` |
| `ui.setTexts{ {old=…, new=…}, … }` | массовая замена текстов родного GUI; ПЕРЕЖИВАЕТ пересборку GUI; при выгрузке мода откатывается автоматически |
| `ui.applyTexts()` | повторно применить замены (после пересборки оно и так применяется) |
| `ui.setThemeColor(key, color)` | поменять один цвет активной темы (THEME.Accent и т.д.) |
| `ui.addTheme(name, tbl)` | добавить целую тему в реестр `Themes` — появится в селекте тем |
| `ui.rebuild()` | пересобрать весь интерфейс (как смена темы) — подхватит твою тему/тексты |

Первые два аргумента всех `add*` — это «в какую вкладку» и «в какую секцию».

### 6.8 Замена поведения функций: `api.hook` — ГЛАВНЫЙ ИНСТРУМЕНТ

Почти всё ядро скрипта — **локальные функции главного чанка**, по имени они
недоступны. `api.hook(объектФункции, replacement)` работает даже по локалям —
через `hookfunction` инжектора — на ВСЕХ точках вызова:

```lua
-- replacement получает (old, ...оригинальные аргументы) и должна вернуть результат old(...)
local orig = api.hook(LOB_CORE.makeSystemPrompt, function(old, settings)
    local prompt = old(settings)
    return prompt .. "\n- новое правило"
end)
```

- Требует `hookfunction`/`hookfunc` у инжектора. Нет такого — вернёт nil и напишет
  в журнал; **обязательны фолбэки** (пример: `ClientSettings.CustomSystemPrompt`
  вместо хука промпта — см. `mods_examples/mod_prompt_rules.lua`).
- Откат при выгрузке мода — автоматический, в обратном порядке.
- Несколько модов хукают одну функцию: каждый хук оборачивает предыдущий.
- Хук можно ставить и на любые чужие/свои функции, на которые у тебя есть ссылка.

Что хукать (объекты берутся из `api.core`, §6.10): `makeSystemPrompt(settings)`,
`sendChat(text)`, `processChat(player, msg)`, `saveSettings()`, обработчики
`ACTION_HANDLERS[тег]`.

### 6.9 Свой `[DO:тег]`: `api.action(name, handler, hint?)`

```lua
api.action("spin2", function(p, arg)
    -- p — SourcePlayer (кто «виновник» тега), arg — аргумент из тега
end, "кратко: КОГДА ИИ использовать тег")
```

- Регистрирует `ACTION_HANDLERS[name]` (обёрнуто в pcall) и добавляет подсказку
  `"[DO:name] hint"` в системный промпт → **ИИ сам начнёт использовать тег**.
- Подсказки убираются при выгрузке мода, промпт пересобирается.
- `name` — латиницей/цифрами, без пробелов (это часть тега `[DO:name]`).
- Заменить родной тег: `api.core.ACTION_HANDLERS["wave"] = function(p, arg) ... end`
  (сигнатура `function(p, arg)`, при выгрузке мода родной тег НЕ восстанавливается —
  сохраняй и восстанавливай сам в `onUnload`, либо юзай `api.action` только для новых имён).

### 6.10 Мост к ядру: `api.core` (== глобал `LOB_CORE`)

| Поле | Что это (место в скрипте) |
|---|---|
| `core.ACTION_HANDLERS` | таблица `[тег] → function(p, arg)` — все 67 действий бота (`§ACTIONS_TABLE` ~3731) |
| `core.sendChat(text)` | отправить сообщение в чат **от имени бота** (`§CHAT_SEND`) |
| `core.processChat(player, msg)` | обработать сообщение, как будто его написал игрок (`§PROCESS_MSG`) |
| `core.notify(title, body)` | уведомление в GUI |
| `core.makeSystemPrompt(settings)` | сборка системного промпта ИИ (`§SYSPROMPT`) |
| `core.saveSettings()` | сохранить ClientSettings на диск (`§SAVE`) |
| `core.smartWalk` | таблица-состояние умной ходьбы `_smartWalk` (см. ниже) |
| `core.SW` | параметры умной ходьбы `_SW` — полная таблица в §10 |
| `core.rel` | память знакомств за сессию `_rel[UserId]` (`§RELATIONS` ~6909) |
| `core.lastChatAt` | `[UserId] = os.clock()` — когда игрок последний раз писал |
| `core.Themes` | реестр тем (`§UI_THEMES` ~3994); базовая тема — `core.Themes.LineOfBots` |

`core.smartWalk` (меняй осознанно — это живой state-machine): `active`, `target`,
`state` (`"wander"/"approach"/"visit"/"social"/"winddown"`), `leaveAt`, `stayLockUid`,
`stayLockUntil`, `botReplyAt`, `arrivedAt`, `lastSwitchAt`, `socialSince`, `sessionChats`,
`avoid[UserId]` (метка времени «не подходить до»), `windUntil`.

### 6.11 Библиотеки и связь модов

| Вызов | Что делает |
|---|---|
| `api.lib(name)` | вернуть библиотеку `LineOfBots/libs/<name>.lua` (файл делает `return {...}`); лениво догрузит; синтаксическая ошибка библиотеки не роняет ничего |
| `api.defineLib(name, tbl)` | зарегистрировать общую библиотеку из кода мода |
| `api.export{ ... }` | опубликовать свой API другим модам |
| `api.require(modName)` | получить `api.export` мода `modName` (мод должен грузиться раньше — см. алфавитный порядок, или подпишись на `modExport`) |

### 6.12 Лог и уведомления

| Вызов | Что делает |
|---|---|
| `api.log(...)` | строка в журнал мод-лоадера (вкладка «Моды» → Журнал) + `print` |
| `api.notify(title, body)` | всплывающее уведомление GUI |

---

## 7. ГЛАВНОЕ ПРАВИЛО: глобалы vs локали

| Что-то | Доступ из мода |
|---|---|
| `ClientSettings`, `LOB_CORE`, `LOB_MODS`, `LOB_UI`, `_smartWalk`, `_SW`, `_rel` | **глобалы** → видно напрямую, `api.get/set/patch/override` работают |
| `sendChatMessage`, `processChatMessage`, `makeSystemPrompt`, `saveSettings`, `pushNotification`, `createInterface`, `ACTION_HANDLERS` (локал!), `Themes` (локал!), почти все `lob*-функции` | **локали** → по имени НЕДОСТУПНЫ; только через `api.core.*` / `api.core.Themes` / `api.ui.bridge()` / `api.hook(объект, …)` |

⇒ Алгоритм: нашёл функцию в `api.core`/`LOB_UI` — юзай её; не нашёл, но она глобал —
`api.patch`; иначе — либо хукай объект из мостов, либо воспроизводи логику у себя.

**Осторожно с окружением:** необъявленное присваивание в моде (`foo = 1`) пишет в `_G`
скрипта и может затереть глобал бота. Все внутренние переменные мода — только `local`.

---

## 8. LOB_UI — сырой мост интерфейса (для продвинутых)

`api.ui.bridge()` / глобал `LOB_UI` (публикуется в конце `createInterface`, `§UI_CREATE`):

| Поле | Смысл |
|---|---|
| `gui` | корневой ScreenGui `LineOfBotsUI` |
| `contentArea` | контейнер вкладок |
| `tabFrames` | `[имя] → фрейм вкладки` (родные и модовые) |
| `tabButtons` | `[имя] → кнопка в сайдбаре` |
| `switchTab(name)` | открыть вкладку |
| `currentTabFn()` | имя открытой вкладки |
| `makeSectionCard(scroll, title, sub)` | карточка-секция → `{HeaderRow, Content, …}` |
| `makeToggleRow(parent, label, desc, initial, cb)` | строка-тоггл |
| `makeSliderRow(parent, label, min, max, value, cb)` | строка-слайдер |
| `makeRightControlRow(parent, label, desc, ctrlW)` | строка с местом под контрол справа |
| `makeDropdown(parent, values, default, cb)` | дропдаун → `{Frame, …}` |
| `makeButton(parent, text)` | кнопка |
| `makeTextBox(parent, placeholder)` | поле ввода |
| `makeTextLabel(parent, text, size, weight)` | текст (`weight`: `"bold"/"semibold"/"medium"`) |
| `makeKeybindRow`, `makeScrollingTextBox`, `makeTabButton` | прочие конструкторы |
| `refreshMods()` | перерисовать список во вкладке «Моды» |
| `guiScaleFn()` | текущий масштаб GUI (для расчёта размеров) |
| `rebuildInterface()` | пересобрать всё окно |

Меняешь что-то напрямую через мост — **не забудь про пересборку GUI** (смена темы
уничтожит твои сырые элементы; вкладки и `setTexts` лоадер восстановит, сырую
лапшу — нет; подписывайся на `api.onUIRebuild`/событие `uiRebuild` и пересоздавай).

---

## 9. Кулинарная книга (рецепты)

### 9.1 Тоггл-гейт: «тумблер вкл → функция работает, выкл → не работает»
```lua
local enabled = true
api.ui.addToggle("Мой мод", "Опции", "Фича", "", true, function(on) enabled = on end)
api.on("chat", function(player, msg)
    if not enabled then return end
    -- ...
end)
```

### 9.2 Управлять родной функцией бота своим тумблером
```lua
api.ui.addToggle("Мой мод", "Опции", "Автоответы", "штатная настройка бота",
    api.getSetting("AutoReply") ~= false, function(on)
    api.setSetting("AutoReply", on)     -- меняет поведение ВСЕХ функций, читающих ключ
end)
```

### 9.3 Свой `[DO:тег]`, который ИИ начнёт использовать сам
```lua
api.action("compliment", function(p, arg)
    api.core.sendChat((p and (p.Name .. ", ") or "") .. "ты крут!")
end, "сделать комплимент собеседнику — при дружелюбном общении")
```

### 9.4 Дописать правило в промпт ИИ (с фолбэком)
```lua
local rule = "Всегда отвечай коротко."
if type(hookfunction) == "function" or type(hookfunc) == "function" then
    api.hook(LOB_CORE.makeSystemPrompt, function(old, settings)
        return old(settings) .. "\n- " .. rule
    end)
else
    api.setSetting("CustomSystemPrompt", rule)
end
```

### 9.5 Полностью запретить боту реагировать на кого-то
```lua
api.hook(LOB_CORE.processChat, function(old, player, msg)
    if player and player.Name == "Обидчик" then return end  -- молча игнор
    return old(player, msg)
end)
```

### 9.6 Перехват/модификация реплик бота
```lua
api.hook(LOB_CORE.sendChat, function(old, text)
    return old(tostring(text) .. " :3")
end)
```

### 9.7 Переименовать тексты родного GUI (переживает пересборку, откат при выгрузке)
```lua
api.ui.setTexts{
    { old = "Основное",  new = "🏠 Главное" },
    { old = "Настройки", new = "⚙ Параметры" },
}
```

### 9.8 Своя тема
```lua
local base = api.core.Themes.LineOfBots or {}
local my = {}; for k, v in pairs(base) do my[k] = v end
my.Accent = Color3.fromRGB(0, 255, 170)
api.ui.addTheme("МояТема", my)
api.setSetting("Theme", "МояТема"); api.ui.rebuild()
```

### 9.9 Подкрутить умную ходьбу
```lua
api.core.SW.MAX_STAY = 60          -- уходить от молчунов быстрее
api.core.SW.RETURN_CD_TALK = 240   -- дольше не возвращаться после живого разговора
```

### 9.10 Реагировать на вход игрока
```lua
api.on("playerJoin", function(plr)
    api.notify("Мой мод", plr.Name .. " зашёл")
end)
```

### 9.11 Мод-библиотека (общий код для других модов)
Файл `LineOfBots/libs/mylib.lua`: `return { double = function(n) return n * 2 end }`
Мод: `local mylib = api.lib("mylib")`.

### 9.12 Свой сервисный тик
```lua
api.every(5, function()
    -- каждые 5 секунд; при выгрузке остановится само
end)
```

### 9.13 Хук глобальной функции
```lua
api.patch("имяГлобальнойФункции", function(old, ...) 
    -- до
    local res = old(...)
    -- после
    return res
end)
```

---

## 10. Параметры умной ходьбы `api.core.SW` (дефолты v24.2)

| Ключ | Дефолт | Смысл |
|---|---|---|
| `AVOID_SEC` | 60 | не подходить после «уйди» |
| `REACH_FAIL_SEC` | 45 | цель считается недостижимой |
| `STOP_DIST` / `RESUME_DIST` | 7 / 12 | дистанция остановки / возобновления |
| `FACE_CD` / `WAVE_CD` | 5 / 90 | разворот к собеседнику / кулдаун приветствия |
| `DEAD_WAIT` | 20 | ждать ли респавн цели |
| `MIN_STAY` / `MAX_STAY` | 20 / 150 | границы визита (молчунов не держим) |
| `MAX_TARGET_DIST` / `FRESH_CHAT` | 250 / 20 | не идти к далёкому молчуну / но свежую реплику догоняем |
| `CHAT_EXTEND` | 45 | продление визита за свежую реплику |
| `WIND_DOWN` | 2.5 | пауза-прощание перед уходом |
| `FAREWELL_CD` | 90 | не прощаемся чаще |
| `RETURN_CD` / `RETURN_CD_TALK` | 30 / 180 | анти-пинг-понг «пока → привет» |
| `WANDER_PAUSE` и `WANDER_PAUSE_MIN/MAX` | 0.12 / 0.8–2.0 | редкие остановки-осмотры |
| `WANDER_ENEMY_R` / `OTHER_ENEMY_R` | 25 / 18 | блуждание вне врагов |
| `NUDGE_T1/T2/T3`, `NUDGE_LEAVE` | 40 / 80 / 120 / 90 | «ты тут?» → «почему молчишь?» → «я пойду» |
| `REVISIT_MIN/MAX` | 60 / 150 | когда вернуться к знакомому |
| `STUCK_LIMIT` / `APPROACH_MAX` | 3 / 10 | антизастревание |
| `WANDER_MIN/MAX` | 25 / 90 | длительность блуждания |
| `OFFSET` / `REPATH_MOVE` | 2.5 / 8 | не вставать в лицо; пересчёт пути |
| `CATCHUP` и связанные | false | спринт-догон выключен (ходит как живой) |
| `GIVEUP_SPEED` / `GIVEUP_DIST` | 26 / 60 | не гонимся за убегающими |
| `TRAVEL_MAX` / `STAY_LOCK_SEC` | 20 / 120 | лимит добирания; `[DO:stay]` |
| `CROWD_RADIUS` / `CROWD_PENALTY` | 7 / 140 | не лезть в толпу |
| `LEASH` | 180 | не уходить далеко от «дома» |
| `STUCK_ZONE_SEC` / `STUCK_ZONE_R` | 90 / 10 | память о месте застревания |
| `THREAT_RADIUS` / `FLEE_RADIUS` / `FLEE_DIST` | 26 / 24 / 34 | реакция на врагов |
| `SWD_*` | см. код | собственное чувство опасности умной ходьбы |

---

## 11. Карта `lineofgui2.lua` (координаты по v24.2; после багфикса v24.6 строки сдвинулись вниз — ищи по `§ИМЯ`)

| Маркер / якорь | строка | Содержимое |
|---|---|---|
| `§SAVE` | 285 | saveSettings / loadSettings |
| `§EMOTE_API` | 544 | API эмоций |
| `§SETTINGS` / `ClientSettings = {` | 703 / 704 | все ключи настроек и дефолты |
| `§PERSONALITIES` | 864 | личности/промпты |
| `§HTTP` | 1190 | postJson — HTTP для executor |
| `§GROQ` | 1342 | Groq-провайдер, ротация 3 ключей |
| `§WEBSEARCH` | 1447 | веб-поиск |
| `§GEMINI` | 1760 | Gemini-провайдер |
| `§ROUTER` | 1963 | выбор провайдера |
| `§OLLAMA` | 2029 | локальные модели |
| `§CHAT_SEND` / `sendChatMessage` | 2341 / 2342 | отправка реплики (событие `botSay`) |
| `§SYSPROMPT` / `makeSystemPrompt` | 2503 / 2504 | системный промпт ИИ |
| `§HELPERS` / `§SPLIT` | 2714 / 2820 | выбор модели, UTF-8 |
| `§EMOTES_DATA` / `§PLAY_EMOTE` | 3000 / 3323 | эмоции и анимации |
| `§MOVEMENT` / `§JUMP` / `§SPIN` | 3453 / 3610 / 3691 | движение, прыжки, кружение |
| `§ACTIONS_TABLE` / `ACTION_HANDLERS` | 3731 / 3732 | 67 тегов `[DO:...]` |
| `§PARSE_ACTION` | 3888 | разбор `[DO:...]` |
| `§PLACE` | 4626 | информация о плейсе |
| `§BEHAVIOR` / `§NEARBY` / `§CAM_LOOK` | 5513 / 5623 / 6153 | монитор поведения, осведомлённость, взгляд |
| `§HISTORY` / `§LINE_OF_MEMORY` | 6236 / 6247 | история чата, долговременная память |
| `§LANG` | 6501 | детект RU/EN |
| `_smartWalk` / `_SW` / `_rel` | 6592 / 6617 / 6913 | умная ходьба: состояние / параметры / знакомства |
| `§RELATIONS` | 6909 | память знакомств за сессию |
| `§SW_DANGER` / `§SW_FEAR` | 7024 / 7193 | чувство опасности, страх/доверие |
| `§HANDLE_CHAT` | 8828 | ЯДРО: сообщение → ответ ИИ |
| `§RUN_QUEUE` / `§WATCHDOG` / `§WORLD_REACT` | 9865 / 9904 / 9926 | очереди, watchdog, реакции на мир |
| `§PROCESS_MSG` / `processChatMessage` | 10118 / 10127 | входящее сообщение (событие `chat`) |
| `§CHAT_HANDLERS` / `§CHAT_LISTEN` | 10350 / 10481 | подключение к чату Roblox |
| `Themes` (локал) | 10546 | реестр тем (мост: `api.core.Themes`) |
| `§FOLLOW_MGR` | 11170 | UI кнопка следования |
| `§MODLOADER` / `LOB_CORE` / `LOB_MODS` | 11682 / 11740 / 11755 | **весь мод-лоадер**: мост ядра → лоадер |
| `LOB_MODS.makeAPI` / `loadOne` | 12157 / 12555 | API мода / загрузка мода |
| `§UI_CREATE` / `createInterface` | 12938 / 12939 | сборка всего GUI |
| `groqModels` | 14713 | список моделей |
| `LOB_UI` | 19456 | мост UI (публикация локалей) |
| `§LAUNCH` | 19548 | вызов createInterface + запуск лоадера (19551) |

§UI_HELPERS и §MODELS упомянуты только в шапке файла (твини/хелперы ~4208, модели ~6741).

---

## 12. Отладка и типовые ошибки

Инструменты: вкладка **«Моды» → Журнал** (последние 80 строк, всё что `api.log`),
`api.notify`, `print` (в консоль инжектора). Перезагрузка модов — перезаход.

| Симптом | Причина / лечение |
|---|---|
| «ошибка синтаксиса» в карточке мода | Lua-ошибка компиляции; текст ошибки в журнале и в карточке. Часто: `continue`/`goto` (нельзя), несовпадение `end`, оператор `//` |
| «ошибка» в карточке | runtime-ошибка при старте; см. журнал. Обычно nil-поле — добавь проверок |
| мод не появляется | файл не `.lua/.luau/.lobmod`; начинается с `_`; лежит не в `LineOfBots/mods`; `ClientSettings.ModLoader = false`; инжектор без `readfile+listfiles` |
| тоггл пишет «перезайдите…» | у мода `instant=false`/`requiresRejoin=true` — так и задумано |
| `api.patch("X", …)` не сработал | X — локаль; юзай `api.hook(объект, …)` |
| `api.hook` вернул nil | инжектор без `hookfunction`; сделай фолбэк |
| добавление в родную вкладку вернуло nil | вкладка не списочная; создай свою `ensureTab` |
| данные не сохраняются | в `api.data()` попала функция/инстанс/цикл; храни только строки/числа/bool/таблицы |
| мод-сосед не видит мой `export` | порядок алфавитный; подписывайся на `modExport` или `modsLoaded` |
| после выгрузки пропали тексты/тема, которые менял не через API | так и есть: сырые правки GUI не отслеживаются — юзай `setTexts`/`addTheme` или восстанавливай в `onUnload` |

---

## 13. Чеклист перед выдачей мода

- [ ] все вызовы API существуют в этом документе (§6, §8);
- [ ] все `local` внутри мода; нет случайной записи в глобалы;
- [ ] `lob.meta{…}` заполнен (title, icon, description, корректный `instant`);
- [ ] каждая подписка/функция переживает отсутствие сущностей (`if x then`);
- [ ] для `api.hook` есть фолбэк на случай отсутствия `hookfunction`;
- [ ] нет `continue`/`goto`; файл — валидный Lua 5.1/Luau;
- [ ] состояние для сохранения — только строки/числа/bool/таблицы;
- [ ] код самодостаточен (один файл), кодировка UTF-8;
- [ ] в `onUnload` — только своя уборка (остальное лоадер чистит сам).

---

## 14. История API мод-лоадера

- **v24.0** — лоадер: папка `LineOfBots/`, вкладка «Моды», компиляция до запуска,
  pcall-изоляция, мгновенный тоггл / «перезайдите», мосты `LOB_CORE`/`LOB_UI`.
- **v24.1** — `api.action` (подсказки `[DO:тегов]` в промпт), библиотеки `libs/`,
  `export/require`, кэш меты выключенных модов, `setTexts` переживает пересборку,
  дополнение родных списочных вкладок, свои `[DO:теги]` и хуки с автооткатом.
- **v24.2** — `core.sendChat/processChat/notify` в мосте; автооткат замен текстов GUI
  при выгрузке мода (`uiRevertTexts`); пример мода дополнен корректными паттернами.
- **v24.5** — `api.hint`/`api.removeHint`, `api.ability`/`api.removeAbility`, `api.say`,
  `api.version`; fail-safe хуки (ошибка мода снимает хук, а не ломает промпт);
  ошибки конвейера ответа видны в GUI; текст в промпт — через hint/ability, не хук.
- **v24.6** — масштабный багфикс лоадера: `loadChunk` (loadstring→load→журнал),
  табы-призраки при выгрузке, утечка подписок `api.on`, сохранение родных `[DO:тегов]`,
  fail-safe `api.patch`/`api.override`/`api.connect`, `loadAll` под pcall.
  Полные описания и чеклист приёмки — в `MODDING_KIT_ADDENDUM_v24.6.md`.

*Документ сгенерирован по исходному коду `lineofgui2.lua` v24.2 и дополнен до v24.6
(кит v2, см. `MODDING_KIT_ADDENDUM_v24.6.md`); при расхождении источником считается код скрипта.*
