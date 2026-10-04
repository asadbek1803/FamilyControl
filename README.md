# FamilyControl

Oilaviy nazorat tizimi: **ota-ona** ilovasi farzand qurilmasini boshqaradi,
**farzand** ilovasi esa xavfsizlik rejimini yoqadi. Muhim hodisalar ota-onaning
Telegram orqali yuboriladi.

## Tuzilma

```
familycontrol/        Django loyihasi (API)
parental_control/     Modellar, view'lar, Telegram integratsiyasi
flutter_app/          Flutter ilovasi (ota-ona + farzand)
```

## Ishga tushirish

### 1. Backend

```bash
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver
```

API manzili: `http://127.0.0.1:8000/api/v1/`

`DATABASE_URL` berilmasa SQLite (`db.sqlite3`) ishlatiladi — mahalliy tez sinash
uchun yetarli.

### 2. PostgreSQL (Neon)

Production uchun SQLite **ishlatilmaydi** (bir nechta device bir vaqtda
yozayotganda buziladi). Neon'da bo'sh ma'lumotbazasi yarating va ulanish
manzilini oling.

`familycontrol/settings.py` `DATABASE_URL` muhit o'zgaruvchisini o'qiadi —
kodga yozilmaydi, shuning uchun parol GitHub'ga tushmaydi.

**Railway:** Variables → `DATABASE_URL` → Neon bergan manzilni yozing →
**Redeploy**.

**Mahalliy:** `.env` fayli yarating (`.env.example` ga qarang):

```
DATABASE_URL=postgresql://USER:PASSWORD@HOST/neondb?sslmode=require&channel_binding=require
```

Keyin:

```bash
python manage.py migrate
```

Manzil **Pooled connection** bo'lishi kerak (`-pooler.` bilan tugaydi) —
Neon boshqacha manzil berishi mumkin.

> ⚠️ `CONN_MAX_AGE` ataylab `0` qilingan: PgBouncer transaction rejimida
> Django ulashni bo'sh qoldirmasligi kerak, aks holda `SET` buyruqlari
> keyingi so'rovga ko'tarilib ketadi. Kengaytirilgan variant kerak bo'lsa
> `CONN_MAX_AGE` muhit o'zgaruvchisi orqali o'zgartiriladi.

### 3. Flutter ilovasi

`flutter_app/lib/core/constants/api_constants.dart` faylidagi `baseUrl` ni
o'zgartiring:

```dart
// Android emulator uchun
static String baseUrl = 'http://10.0.2.2:8000/api/v1';
// Haqiqiy qurilma uchun — kompyuterning mahalliy IP si
// static String baseUrl = 'http://192.168.1.100:8000/api/v1';
```

Keyin:

```bash
cd flutter_app
flutter pub get
flutter run
```

## Server manzilini o'zgartirish

Server ko'chsa, domen yoki port o'zgarsa — ilovalar chiqarilmasdan yangilanishi
mumkin. Buning uchun GitHub'da bitta fayl yetarli.

**1. Repo yarating** (masalan `oilabek/familycontrol`) va uning ichiga
`familycontrol_config.json` faylini joylashtiring:

```json
{ "base_url": "https://api.mening-domainim.uz/api/v1" }
```

**2. Ilovada havolani ko'rsating** —
`flutter_app/lib/core/network/remote_config.dart`:

```dart
static const String sourceUrl =
    'https://raw.githubusercontent.com/oilabek/familycontrol/main/familycontrol_config.json';
```

**3. Qayta build qiling** va tarqating. Keyinchalik server manzili
o'zgarsa — **faqat** GitHub faylini tahrirlash yetarli.

### Qanday ishlaydi

```
Ilova ochiladi
  -> oxirgi tekshiruv 6 soatdan o'tgan bo'lsa, GitHub'dan so'rov
  -> validatsiya: FAQAT https:// (mahalliy ishlash uchun http://10.0.2.2,
     localhost, 127.0.0.1 ruxsat beriladi)
  -> to'g'ri bo'lsa saqlanadi, xato bo'lsa ESKI manzil saqlanib qoladi
```

GitHub ishlamagan, internetsiz yoki fayl noto'g'ri bo'lgan holatda ilova
o'zgarishsiz ishlayveradi — hech qachon "server topilmadi" holatiga tushmaydi.

### Xavfni bilib oling

Bu fayl **imzolanmagan**. Demak:

- Kimdir GitHub akkauntingizga yoki repozitoriyaga kirish huquqiga ega
  bo'lsa, u `base_url` ni **o'z serveriga** almashtirishi mumkin;
- natijada ilovalar o'sha serverga ulanib, ota-ona va farzand
  ma'lumotlarini yuboradi.

Shuning uchun:

- GitHub akkauntiga **2FA** yoqing;
- repozitoriyada ishonchli odamlardan tashqari hech kimga yozish huquqi
  bermang;
- `base_url` ni Telegram yoki boshqa messajer orqali **hech qachon**
  yubormang — ilova bunday xabarlarni qabul qilmaydi.

> Eski mexanizmda (Telegram orqali URL) APK ichida bot tokeni bor edi. APK ni
> ochgan har kim shu yo'l orqali butun tizimni hujumchi serveriga
> yo'naltirishi mumkin edi. Endi hech qanday maxfiy ma'lumot ilovada
> saqlanmaydi — shuning uchun yo'qotilgan APK o'zi hujum uchun qurol
> bo'lmaydi.

## Telegram bildirishnomalari

### Arxitektura

```
Farzand qurilmasi                Server                      Ota-onaning Telegram'i
       |                            |                                |
       |-- POST /devices/events/ -->|                                |
       |                            |-- DeviceEvent (bazaga)         |
       |                            |-- Telegram orqali yuborish --->|
       |                            |   (BOT TOKEN FAQAT SERVERDA)  |
```

**Bot tokeni hech qachon ilovaga (APK) joylashtirilmaydi.** U faqat server
muhit o'zgaruvchisida saqlanadi:

```bash
# PowerShell
$env:TELEGRAM_BOT_TOKEN = "123456789:ABCdefGHIjklMNOpqrsTUVwxyz"

# Linux/macOS
export TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
```

Token `@BotFather` orqali olinadi.

> **Muhim:** ilovada `lib/core/network/telegram_service.dart` fayi bor, lekin u
> **bo'sh**. Unda avval quyidagi xavfli mexanizm bo'lgan: bot tokeni APK ichida
> hardcoded, `checkNewApiUrl()` esa botga kelgan xabarni o'qib, undagi HTTP
> manzilni ilovaning backend URL si sifatida qabul qilardi. APK ni ochgan hujumchi
> shu yo'l orqali **barcha** ota-ona va farzand qurilmalarini o'z serveriga
> yo'naltirishi mumkin edi. Bu mexanizm butunlay olib tashlandi: server manzili
> faqat koddan (`ApiConstants.baseUrl`) olinadi va hech qanday tashqi kanaldan
> o'zgartirilmaydi.

### Sozlash (ota-onaning ilovasida)

1. Botga Telegram orqali `/start` yuboring (aks holda bot xabar yubora olmaydi).
2. Chat ID ni oling: `@userinfobot` yoki `@getidsbot` botlaridan biriga yozing.
3. Ilovada: **Bildirishnoma** tugmasi → Chat ID ni kiriting → **Test xabarini
   yuborish**.

Server chat ID ni `getChat` orqali tekshiradi — shuning uchun "ID to'g'ri" degan
javob ishonchli bo'ladi. Bir chat ID faqat bitta akkauntga ulanadi.

### "Telegram Bot tokeni sozlanmagan" xatosi

Bu xato shuni anglatadi: **serverda** `TELEGRAM_BOT_TOKEN` yo'q. Ilovada emas,
serverda bo'lishi kerak.

**Railway uchun:**

1. Railway dashboard → sizning servisingiz → **Variables**
2. `TELEGRAM_BOT_TOKEN` nomi bilan yangi variable qo'shing
3. Qiymatga @BotFather'dan olgan tokenni yozing
4. **Redeploy** bosing — o'zgarish faqat keyingi deploy'da kuchga kiradi

**Mahalliy kompyuter uchun:** loyiha papkasida `.env` fayli yarating:

```
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz
```

**Tekshirish:**

```bash
python manage.py check_telegram              # token ishlayaptimi?
python manage.py check_telegram 123456789    # ushbu chat ga xabar yuborib sinash
```

> Eslatma: eski token `8887166286:AAH47aar4N0Q_2qZtkr1MNxEyH0Ir7zApDU` allaqach
> APK ichida oshkor bo'lgan. Uni **ishlatmang** — avval @BotFather orqali
> `/revoke` qilib, yangi bot/token yarating.

### Yuboriladigan hodisalar

| Hodisa | Manba |
|---|---|
| Qurilma ulandi | Server (`/devices/pair/`) |
| Qurilma uzildi | Hali implementatsiyada |
| SOS signali | Farzand ilovasi (uzoq bosish) |
| Batareya qullab qolmoqda | `ChildAccessibilityService` (soatda bir marta, 20% dan past) |
| Himoya o'chirildi / yoqildi | `AdminReceiver` (Device Admin) |
| Farzand rejimi yoqildi | Farzand ilovasi (ota-onaga ulangan zahoti) |
| Ilova bloklandi / chiqarildi | Ota-onaning ilovasi (server orqali) |

### Yetkazib bo'lmagan xabarlar

Telegram nosoz bo'lsa, hodisa bazada saqlanib qoladi va keyin qayta
yuboriladi:

```bash
python manage.py send_pending_notifications          # so'nggi 1 kun
python manage.py send_pending_notifications --days 3  # so'nggi 3 kun
```

Cron/Task Scheduler orqali har soatda ishga tushirish tavsiya etiladi.

## Qurilma autentifikatsiyasi

Pairing **ota-onaning** ilovasida amalga oshadi, shuning uchun `device_token`
ota-onaning telefonida qoladi. Farzand qurilmasi esa o'z tokenini oladi:

```
POST /devices/claim/   {"device_identifier": "<uuid>"}
-> {"is_paired": true, "device_id": "...", "device_token": "..."}
```

`device_identifier` — qurilmada UUIDv4 sifatida generatsiya qilinadi va faqat
o'sha qurilmada saqlanadi. Har `claim` eski tokenini bekor qiladi.

Qurilma autentifikatsiyasi bilan (`Authorization: DeviceBearer <id>:<token>`):

- `POST /devices/events/` — hodisa yuborish
- `GET /devices/events/` — hodisa tarixi
- `POST /sync/batch/` — batareya, joylashuv, ilovalar

## Chegara: yashirin kuzatuv

Bu tizim **chat yozishmalari, SMS yoki ekrandagi matnni yig'maydi**.
`ChildAccessibilityService` faqat Sozlamalar va ilova o'rnatish ekranlarini
PIN bilan bloklaydi. Android manifestida `canRetrieveWindowContent="false"`
qo'yilgan.

Ota-onaga yuboriladigan hamma ma'lumot — **ilova va qurilma holati**
(ulandi, bloklandi, batareya, SOS). Boshqa ilovalarning ichki xabarlari bu
tizimga kirmaydi.

## Testlar

```bash
python manage.py test parental_control
cd flutter_app && flutter analyze && flutter test
```

**PostgreSQL bilan:** birinchi marta test bazasi yaratiladi (keyin
o'chirilmaydi — `neondb_test`):

```bash
python manage.py prepare_test_db     # BIR MARTA
python manage.py test parental_control
```

Nega `prepare_test_db` kerak: Neon manzili PgBouncer orqali o'tadi va u
server ulanishlarini o'z havuzida ushlab turadi. Django test oxirida
`DROP DATABASE` bersa, `database is being accessed by other users` xatosi
chiqadi — testlar `OK` bo'lganiga qaramay. `familycontrol/test_runner.py`
buni `--keepdb` orqali hal qiladi.

To'liq qayta qurish:

```bash
python manage.py prepare_test_db --reset
```

SQLite bilan ishlayotgan bo'lsangiz, `prepare_test_db` kerak emas.

## Production oldidan

`familycontrol/settings.py` dagi quyidagilar **albatta** o'zgartirilishi kerak:

- `DEBUG = False`
- `SECRET_KEY` — muhit o'zgaruvchisiga ko'chirilishi kerak
- `ALLOWED_HOSTS = ["*"]` — aniq domenlar ro'yxati
- `CORS_ALLOW_ALL_ORIGINS = True` — false qilinishi kerak
- `DATABASE_URL` — Railway Variables'da (kodga yozilmaydi)
- `TELEGRAM_BOT_TOKEN` — Railway Variables'da