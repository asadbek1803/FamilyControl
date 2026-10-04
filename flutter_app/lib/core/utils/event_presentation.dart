import 'package:flutter/material.dart';

import '../../models/device_event.dart';

/// Hodisa turiga qarab ikona va rang.
///
/// Nima uchun alohida fayl: bir xil mapping boshqaruv panelida
/// (`dashboard_screen.dart`) va hodisa tarixi ekranida
/// (`events_screen.dart`) kerak. Mappingni panel faylida yozsa, hodisa
/// ekrani butun panel ekranini import qilishga majbur bo'lardi.

IconData iconForEventType(String eventType) {
  switch (eventType) {
    case DeviceEvent.typePaired:
      return Icons.link;
    case DeviceEvent.typeUnpaired:
      return Icons.link_off;
    case DeviceEvent.typeSos:
      return Icons.sos;
    case DeviceEvent.typeBatteryLow:
      return Icons.battery_alert;
    case DeviceEvent.typeAdminDisabled:
      return Icons.gpp_bad;
    case DeviceEvent.typeAdminEnabled:
      return Icons.gpp_good;
    case DeviceEvent.typeChildModeEnabled:
      return Icons.child_care;
    case DeviceEvent.typeZoneExit:
      return Icons.shield;
    case DeviceEvent.typeAppBlocked:
      return Icons.block;
    case DeviceEvent.typeAppUnblocked:
      return Icons.check_circle;
    default:
      return Icons.info;
  }
}

/// Urgent hodisalar (yordam signali, himoya o'chirilgan, batareya) qizil
/// ajratiladi — ota-ona ularni darhol ko'rishi kerak.
Color colorForEvent(DeviceEvent event) {
  switch (event.eventType) {
    case DeviceEvent.typeSos:
    case DeviceEvent.typeAdminDisabled:
      return Colors.red;
    case DeviceEvent.typeBatteryLow:
    case DeviceEvent.typeZoneExit:
      return Colors.orange;
    case DeviceEvent.typeUnpaired:
      return Colors.grey;
    case DeviceEvent.typePaired:
    case DeviceEvent.typeAdminEnabled:
    case DeviceEvent.typeChildModeEnabled:
    case DeviceEvent.typeAppUnblocked:
      return Colors.green;
    default:
      return Colors.blue;
  }
}

/// Hodisa turini o'zbekcha nomga tarjima qilish (filtr chip'lari uchun).
///
/// Bo'lmagan tur (`default`) — server yangi hodisa qo'shganda ilova
/// buzilmasligi uchun `null` qaytaradi va chip sifatida ko'rsatilmaydi.
String? labelForEventType(String eventType) {
  switch (eventType) {
    case DeviceEvent.typePaired:
      return 'Ulangan';
    case DeviceEvent.typeUnpaired:
      return 'Uzilgan';
    case DeviceEvent.typeSos:
      return 'SOS';
    case DeviceEvent.typeBatteryLow:
      return 'Batareya';
    case DeviceEvent.typeAdminDisabled:
      return 'Himoya o\'chirilgan';
    case DeviceEvent.typeAdminEnabled:
      return 'Himoya yoqilgan';
    case DeviceEvent.typeChildModeEnabled:
      return 'Bola rejimi';
    case DeviceEvent.typeZoneExit:
      return 'Zonadan chiqdi';
    case DeviceEvent.typeAppBlocked:
      return 'Ilova bloklandi';
    case DeviceEvent.typeAppUnblocked:
      return 'Ilova ochildi';
    default:
      return null;
  }
}
