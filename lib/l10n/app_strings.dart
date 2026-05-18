import 'package:flutter/widgets.dart';

/// Minimal in-app localization (English / Simplified Chinese). Kept as a
/// plain lookup so the build needs no codegen.
class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static const supported = [Locale('en'), Locale('zh')];

  static AppStrings of(BuildContext context) =>
      Localizations.of<AppStrings>(context, AppStrings) ??
      AppStrings(const Locale('en'));

  String t(String key) {
    final lang = locale.languageCode == 'zh' ? _zh : _en;
    return lang[key] ?? _en[key] ?? key;
  }

  static const _en = {
    'app': 'miniLight',
    'settings': 'Settings',
    'metering_camera': 'Camera',
    'metering_incident': 'Incident (lux)',
    'metering_real': 'Real (sensor data)',
    'source': 'Metering source',
    'hold': 'Hold',
    'live': 'Live',
    'tap_hint': 'Tap the preview to meter that spot',
    'focus_active': 'Tap-to-meter active · pick a mode to reset',
    'compensations': 'Compensations',
    'push_pull': 'Push / Pull (stops)',
    'filter': 'Filter factor (stops)',
    'bellows': 'Bellows (stops)',
    'exp_comp': 'Exposure compensation (EV)',
    'zone': 'Zone placement',
    'camera_body': 'Camera body',
    'films': 'Film stocks',
    'add_film': 'Add custom film',
    'shot_log': 'Shot log',
    'rolls': 'Rolls',
    'new_roll': 'New roll',
    'save_shot': 'Save shot',
    'export_csv': 'Export CSV',
    'language': 'Language',
    'calibrate': 'Calibrate',
    'overexposed': 'Highlights clipping',
    'underexposed': 'Shadows clipping',
  };

  static const _zh = {
    'app': 'miniLight',
    'settings': '设置',
    'metering_camera': '相机测光',
    'metering_incident': '入射式 (lux)',
    'metering_real': '真实测光 (传感器)',
    'source': '测光来源',
    'hold': '锁定',
    'live': '实时',
    'tap_hint': '点击画面对该点测光',
    'focus_active': '触摸测光已开启 · 点测光模式可复位',
    'compensations': '曝光补偿',
    'push_pull': '推拉冲洗（档）',
    'filter': '滤镜系数（档）',
    'bellows': '皮腔补偿（档）',
    'exp_comp': '曝光补偿 (EV)',
    'zone': '区域系统放置',
    'camera_body': '机身',
    'films': '胶片',
    'add_film': '添加自定义胶片',
    'shot_log': '拍摄日志',
    'rolls': '胶卷',
    'new_roll': '新建胶卷',
    'save_shot': '保存此张',
    'export_csv': '导出 CSV',
    'language': '语言',
    'calibrate': '校准',
    'overexposed': '高光溢出',
    'underexposed': '暗部死黑',
  };
}

class AppStringsDelegate extends LocalizationsDelegate<AppStrings> {
  const AppStringsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'zh'].contains(locale.languageCode);

  @override
  Future<AppStrings> load(Locale locale) async => AppStrings(locale);

  @override
  bool shouldReload(AppStringsDelegate old) => false;
}
