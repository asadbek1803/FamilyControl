// Modellarning server javobi bilan MUTANOSABAT testlari.
//
// Nima uchun bu muhim: `GeoZone`, `AppTimeLimit`, `Contact` modellari server
// bilan mos kelmasdi — `json['device_id'] as String` kabi `null`ga cast
// qilingan qiymat TypeError berardi. Xato `DeviceRepository` ichidagi `try`
// blokida yutilar edi, ya'ni foydalanuvchi ekranda faqat "bo'sh ro'yxat"
// ko'rardi va nima uchunligini tushunmasdi. Xatolar sekin va jim qoldi.
//
// Bu testlar haqiqiy server JSON shaklini yozadi: agar backend maydon
// nomini o'zgartirsa yoki model qaytarsa, test darhol qizil bo'ladi.
import 'package:family_control_app/models/app_time_limit.dart';
import 'package:family_control_app/models/child_device.dart';
import 'package:family_control_app/models/contact.dart';
import 'package:family_control_app/models/device_event.dart';
import 'package:family_control_app/models/geo_zone.dart';
import 'package:family_control_app/models/parent_dashboard.dart';
import 'package:family_control_app/models/sos_alert.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeoZone', () {
    // `GeoZoneSerializer.Meta.fields` bilan bir xil.
    final json = {
      'id': '3f2a1b4c-0000-4000-8000-000000000001',
      'name': 'Maktab',
      'latitude': 41.31108,
      'longitude': 69.24056,
      'radius_meters': 250.0,
      'created_at': '2026-03-01T10:00:00Z',
    };

    test('server javobini to\'g\'ri o\'qiydi', () {
      final zone = GeoZone.fromJson(json);
      expect(zone.id, json['id']);
      expect(zone.name, 'Maktab');
      expect(zone.latitude, closeTo(41.31108, 0.0001));
      expect(zone.longitude, closeTo(69.24056, 0.0001));
      expect(zone.radiusMeters, 250.0);
    });

    test('radius butun son bo\'lsa ham ishlaydi', () {
      // Bazada `radius_meters` FloatField -> JSON da `250.0`, lekin
      // `FractionalTypedData` kelishi mumkin. `as num` cast kerak.
      final zone = GeoZone.fromJson({...json, 'latitude': 41, 'radius_meters': 250});
      expect(zone.latitude, 41.0);
      expect(zone.radiusMeters, 250.0);
    });

    test('to\'liq bo\'sh maydonlar crash qilmaydi', () {
      // `is_blocked`/`latitude` kabi maydonlar null kelishi mumkin
      // (eski qatorlar). `as num` cast qilish TypeError berardi.
      final zone = GeoZone.fromJson({
        'id': 'x',
        'name': null,
        'latitude': null,
        'longitude': null,
        'radius_meters': null,
        'created_at': null,
      });
      expect(zone.name, '');
      expect(zone.latitude, 0.0);
      expect(zone.radiusMeters, 0.0);
    });
  });

  group('AppTimeLimit', () {
    // `AppTimeLimitSerializer.Meta.fields` bilan bir xil.
    final json = {
      'id': '3f2a1b4c-0000-4000-8000-000000000002',
      'package_name': 'com.google.android.youtube',
      'max_daily_minutes': 60,
      'block_after_time': '21:00',
      'is_active': true,
    };

    test('server javobini to\'g\'ri o\'qiydi', () {
      final limit = AppTimeLimit.fromJson(json);
      expect(limit.packageName, 'com.google.android.youtube');
      expect(limit.maxDailyMinutes, 60);
      expect(limit.isActive, isTrue);
      expect(limit.blockAfterTime, '21:00');
    });

    test('eski model kutilgan maydonlarga tayanmasdi', () {
      // Eski model `device_id`, `limit_minutes`, `is_blocked` kutardi —
      // server esa umuman yubormaydi. Bu test regressiya qo'yadi.
      final limit = AppTimeLimit.fromJson(json);
      expect(limit, isNotNull);
      expect(limit.maxDailyMinutes, greaterThan(0));
    });

    test('default qiymatlar to\'g\'ri', () {
      final limit = AppTimeLimit.fromJson({
        'id': 'y',
        'package_name': 'com.game',
        'max_daily_minutes': 30,
      });
      expect(limit.isActive, isTrue, reason: 'is_active kelmasa faol hisoblanadi');
      expect(limit.blockAfterTime, isNull);
    });
  });

  group('Contact', () {
    // `ContactSerializer` server maydonlari: `contact_name`, `is_new`.
    final json = {
      'id': '3f2a1b4c-0000-4000-8000-000000000003',
      'contact_name': 'Do\'st',
      'phone_number': '+998901234567',
      'is_new': true,
      'updated_at': '2026-03-01T10:00:00Z',
    };

    test('server javobini to\'g\'ri o\'qiydi', () {
      final contact = Contact.fromJson(json);
      expect(contact.contactName, 'Do\'st');
      expect(contact.phoneNumber, '+998901234567');
      expect(contact.isNew, isTrue);
    });

    test('eski `name` maydoni bilan ham ishlaydi', () {
      // `name` getter orqali qolgan kod buzilmasligi kerak.
      final contact = Contact.fromJson(json);
      expect(contact.name, contact.contactName);
    });

    test('bo\'sh qiymatlar crash qilmaydi', () {
      final contact = Contact.fromJson({'id': 'z'});
      expect(contact.contactName, '');
      expect(contact.phoneNumber, '');
      expect(contact.isNew, isFalse);
    });
  });

  group('SOSAlert', () {
    final json = {
      'id': '3f2a1b4c-0000-4000-8000-000000000004',
      'latitude': 41.3,
      'longitude': 69.24,
      'resolved': false,
      'created_at': '2026-03-01T10:00:00Z',
    };

    test('server javobini to\'g\'ri o\'qiydi', () {
      final alert = SOSAlert.fromJson(json);
      expect(alert.latitude, closeTo(41.3, 0.0001));
      expect(alert.resolved, isFalse);
    });

    test('copyWith resolved ni o\'zgartiradi', () {
      final alert = SOSAlert.fromJson(json);
      final resolved = alert.copyWith(resolved: true);
      expect(resolved.resolved, isTrue);
      expect(resolved.id, alert.id);
      expect(resolved.latitude, alert.latitude);
      // Asl obyekt o'zgarmasligi kerak.
      expect(alert.resolved, isFalse);
    });

    test('null koordinata crash qilmaydi', () {
      final alert = SOSAlert.fromJson({
        'id': 'a',
        'latitude': null,
        'longitude': null,
      });
      expect(alert.latitude, 0.0);
    });
  });

  group('DeviceEvent', () {
    test('server EVENT_* qiymatlariga mos', () {
      // `DeviceEvent.EVENT_TYPE_CHOICES` bilan mos bo'lishi shart —
      // server `event_type` ni string sifatida saqlaydi.
      expect(DeviceEvent.typePaired, 'paired');
      expect(DeviceEvent.typeUnpaired, 'unpaired');
      expect(DeviceEvent.typeSos, 'sos');
      expect(DeviceEvent.typeBatteryLow, 'battery_low');
      expect(DeviceEvent.typeAdminDisabled, 'admin_disabled');
      expect(DeviceEvent.typeAdminEnabled, 'admin_enabled');
      expect(DeviceEvent.typeChildModeEnabled, 'child_mode_enabled');
      expect(DeviceEvent.typeZoneExit, 'zone_exit');
      expect(DeviceEvent.typeAppBlocked, 'app_blocked');
      expect(DeviceEvent.typeAppUnblocked, 'app_unblocked');
    });

    test('urgent hodisalar ajratiladi', () {
      DeviceEvent build(String type) =>
          DeviceEvent(id: 'i', eventType: type, message: 'm');
      expect(build(DeviceEvent.typeSos).isUrgent, isTrue);
      expect(build(DeviceEvent.typeAdminDisabled).isUrgent, isTrue);
      expect(build(DeviceEvent.typeBatteryLow).isUrgent, isTrue);
      expect(build(DeviceEvent.typePaired).isUrgent, isFalse);
    });

    test('JSON dan o\'qiydi', () {
      final event = DeviceEvent.fromJson({
        'id': 'e1',
        'event_type': 'sos',
        'message': 'Yordam so\'radi',
        'data': {'latitude': 41.3},
        'created_at': '2026-03-01T10:00:00Z',
      });
      expect(event.eventType, 'sos');
      expect(event.data['latitude'], 41.3);
    });

    test('null maydonlar crash qilmaydi', () {
      final event = DeviceEvent.fromJson({'id': 'e2'});
      expect(event.eventType, '');
      expect(event.message, '');
      expect(event.data, isEmpty);
    });
  });

  group('ChildDevice', () {
    final json = {
      'id': '3f2a1b4c-0000-4000-8000-000000000005',
      'device_identifier': 'dev-1',
      'device_name': 'Xiaomi Redmi 12',
      'child_name': 'Alisher',
      'display_child_name': 'Alisher',
      'is_active': true,
      'is_paired': true,
      'battery_level': 78.5,
      'last_seen': '2026-03-01T10:00:00Z',
      'created_at': '2026-01-01T00:00:00Z',
    };

    test('server javobini to\'g\'ri o\'qiydi', () {
      final device = ChildDevice.fromJson(json);
      expect(device.childName, 'Alisher');
      expect(device.isPaired, isTrue);
      expect(device.batteryLevel, closeTo(78.5, 0.01));
      expect(device.displayName, 'Alisher');
    });

    test('nom yo\'q bo\'lsa qurilma nomi ko\'rsatiladi', () {
      final device =
          ChildDevice.fromJson({...json, 'child_name': '', 'is_paired': false});
      expect(device.displayName, 'Xiaomi Redmi 12');
    });

    test('ikkala nom ham yo\'q bo\'lsa identifikatordan foydalaniladi', () {
      final device = ChildDevice.fromJson({
        ...json,
        'child_name': '',
        'device_name': '',
        'is_paired': false,
      });
      expect(device.displayName, 'dev-1');
    });

    test('bo\'sh satr whitespace hisoblanadi', () {
      // `"  "` — `trim().isEmpty` true, ya'ni nom yo'q deb hisoblanishi
      // kerak. Aks holda panelda bo'sh kartalar ko'rinadi.
      final device =
          ChildDevice.fromJson({...json, 'child_name': '   ', 'is_paired': false});
      expect(device.displayName, 'Xiaomi Redmi 12');
    });

    test('null battery crash qilmaydi', () {
      final device =
          ChildDevice.fromJson({...json, 'battery_level': null, 'last_seen': null});
      expect(device.batteryLevel, isNull);
      expect(device.lastSeen, isNull);
    });
  });

  group('ParentDashboard', () {
    // `ParentDashboardSerializer` maydonlari.
    final json = {
      'generated_at': '2026-03-01T10:00:00Z',
      'summary': {
        'children_count': 2,
        'devices_count': 3,
        'online_count': 2,
        'low_battery_count': 1,
        'blocked_apps_count': 4,
        'active_sos_count': 0,
        'today_screen_time_ms': 5400000,
      },
      'children': [
        {
          'child_name': 'Alisher',
          'devices_count': 2,
          'online_count': 1,
          'today_screen_time_ms': 3600000,
          'devices': [
            {
              'id': 'd1',
              'device_name': 'Alisher telefoni',
              'child_name': 'Alisher',
              'is_active': true,
              'is_paired': true,
              'battery_level': 85.0,
              'last_seen': '2026-03-01T10:00:00Z',
              'today_screen_time_ms': 3600000,
              'installed_apps_count': 42,
              'blocked_apps_count': 3,
              'contacts_count': 10,
              'zones_count': 2,
              'active_limits_count': 1,
              'active_sos_count': 0,
              'last_sos_at': null,
              'last_event_type': 'battery_low',
              'last_event_message': 'Batareya 15%',
              'last_event_at': '2026-03-01T09:00:00Z',
            },
          ],
        },
      ],
      'recent_events': [
        {
          'id': 'ev1',
          'event_type': 'sos',
          'message': 'Yordam so\'radi',
          'data': <String, dynamic>{},
          'created_at': '2026-03-01T09:30:00Z',
        },
      ],
    };

    test('to\'liq javobni o\'qiydi', () {
      final dashboard = ParentDashboard.fromJson(json);
      expect(dashboard.hasChildren, isTrue);
      expect(dashboard.hasActiveSos, isFalse);
      expect(dashboard.summary.childrenCount, 2);
      expect(dashboard.summary.todayScreenTimeMs, 5400000);
      expect(dashboard.children.first.childName, 'Alisher');
      expect(dashboard.children.first.devices.single.blockedAppsCount, 3);
      expect(dashboard.recentEvents.single.eventType, 'sos');
    });

    test('bosh panel to\'g\'ri qaytariladi', () {
      final dashboard = ParentDashboard.fromJson({
        'generated_at': '2026-03-01T10:00:00Z',
        'summary': <String, dynamic>{},
        'children': <dynamic>[],
        'recent_events': <dynamic>[],
      });
      expect(dashboard.hasChildren, isFalse);
      expect(dashboard.summary.childrenCount, 0);
      expect(dashboard.children, isEmpty);
    });

    test('bo\'sh summary kalitlari xatosiz 0 ga aylanadi', () {
      // Server nusxasi eskirishi mumkin — ilova crash qilmasligi kerak.
      final dashboard = ParentDashboard.fromJson({'children_count_missing': true});
      expect(dashboard.summary.devicesCount, 0);
      expect(dashboard.hasChildren, isFalse);
    });

    test('DeviceSummary batareya chegarasini qo\'llaydi', () {
      // Server bilan bir xil chegara (20%).
      DeviceSummary build(double? battery) => DeviceSummary.fromJson({
            'id': 'x',
            'device_name': 'n',
            'child_name': 'c',
            'is_active': true,
            'is_paired': true,
            'today_screen_time_ms': 0,
            'installed_apps_count': 0,
            'blocked_apps_count': 0,
            'contacts_count': 0,
            'zones_count': 0,
            'active_limits_count': 0,
            'active_sos_count': 0,
            'battery_level': battery,
          });

      expect(build(15.0).isBatteryLow, isTrue);
      expect(build(20.0).isBatteryLow, isTrue);
      expect(build(20.5).isBatteryLow, isFalse);
      expect(build(null).isBatteryLow, isFalse);
    });

    test('toChildDevice boshqa bo\'limlarga o\'tish uchun mos', () {
      final dashboard = ParentDashboard.fromJson(json);
      final device = dashboard.children.first.devices.first.toChildDevice();
      expect(device.id, 'd1');
      expect(device.childName, 'Alisher');
      expect(device.deviceName, 'Alisher telefoni');
      expect(device.isPaired, isTrue);
      expect(device.batteryLevel, 85.0);
    });
  });
}
