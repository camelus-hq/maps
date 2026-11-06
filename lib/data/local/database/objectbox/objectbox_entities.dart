import 'package:objectbox/objectbox.dart';

/// ObjectBox entity for one settings key/value pair.
///
/// [json] is the JSON-encoded value; the typed helpers in
/// `../app_database_values.dart` own the encoding. The unique index on [key]
/// makes a lookup constant-time and prevents duplicates.
@Entity()
class DbSettingEntity {
  DbSettingEntity({this.key = '', this.json = ''});

  @Id()
  int id = 0;

  @Unique()
  String key;

  String json;
}

/// ObjectBox entity for one recorded metric event.
///
/// [recordedAt] is milliseconds since the Unix epoch and is indexed (newest
/// first is the common read), as is [name] for name-filtered reads. [labels] is
/// the JSON-encoded label map.
@Entity()
class DbMetricEntity {
  DbMetricEntity({
    this.name = '',
    this.recordedAt = 0,
    this.value,
    this.labels = '{}',
  });

  @Id()
  int id = 0;

  @Index()
  String name;

  @Index()
  int recordedAt;

  double? value;

  String labels;
}
