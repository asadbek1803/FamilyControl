/// Carto xarita plitkalari (raster) — bepul, API key talab qilmaydi.
///
/// Nima uchun `google_maps_flutter` emas:
/// Google Maps API key talab qiladi. Key yo'q holatda xarita bo'sh kulrang
/// kvadrat ko'rsatadi — foydalanuvchi "ishlaydi" deb o'ylab, aslida hech
/// narsani ko'rmaydi. Bu "ishlamayotgan" holatdan ko'ra xavfliroq, chunki
/// foydalanuvchi noto'g'ri xulosa chiqaradi.
///
/// Carto kaliti **ochiq (public)** bo'lib, APK ichida saqlanishi
/// mo'ljallangan — shuning uchun uni serverga yashirishning ma'nosi yo'q.
/// Hali ham maxfiy deb hisoblanadigan narsa (bot token, DB paroli) APK ichida
/// saqlanmaydi.
///
/// Manba: <https://carto.com/basemaps/apikey/> — "One key covers the raster
/// and vector basemaps".
library;

import 'dart:ui' show Color;

/// Carto API kaliti (public).
///
/// Bu kalit plitka so'rovlarini anonim ravishda yuborish uchun mo'ljallangan
/// — ya'ni APK ichida bo'lishi normal holat. Uni `build.yaml` orqali
/// yashirishning ma'nosi yo'q; olib tashlash esa xaritani buzadi.
const String cartoApiKey = 'cb1_47sc_1_3b214a8c6cb5a56646f2cf46';

/// "Voyager" uslubidagi plitka shabloni.
///
/// `{z}`, `{x}`, `{y}` ni `flutter_map` har bir plitka uchun **almashtiradi** —
/// shuning uchun shablon to'liq holda saqlanishi SHART. Agar bu yerda
/// `voyagerTileUrl(13, 0, 0)` kabi chaqirsak, joylashuvlar `0/0` ga bog'lanib
/// qoladi va butun xarita bir xil plitka bo'lib chiqadi.
const String voyagerTileTemplate =
    'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png'
    '?key=$cartoApiKey';

/// "Light" uslubidagi plitka shabloni — kulrang, matn bilan kam to'qnashadi.
///
/// Biror narsa ustiga marker qo'yilganda (`CircleLayer` yorqin rangda
/// chiziladi) marker ko'proq ko'rinadi. Shuning uchun zona tanlash
/// rejimida shu uslub ishlatiladi.
const String lightTileTemplate =
    'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png'
    '?key=$cartoApiKey';

/// Plitka yuklanib bo'lmagan joyda ko'rinadigan rang.
///
/// `flutter_map` standart "shox" chizig'ini chizadi. Ota-onalik ilovasida bu
/// chalkash ko'rinadi (oddiy ro'yxat chizig'i bilan aralashib ketadi),
/// shuning uchun biz o'zimiz tinch rang beramiz.
const Color cartoPlaceholderColor = Color(0xFFECEFF1);

/// Internet yo'q holatda xaritaga tushuntirish qo'yiladigan matn.
const String cartoOfflineHint =
    'Xarita yuklanmadi. Internet yo\'q — plitkalar serverdan olinadi.';

/// Kartografiya atributi.
///
/// Carto va OpenStreetMap shartlariga muvofiq **ko'rsatilishi shart**.
const String cartoAttribution = '© OpenStreetMap · © CARTO';
