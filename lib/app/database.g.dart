// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $TermsTable extends Terms with TableInfo<$TermsTable, TermRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TermsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startMeta = const VerificationMeta('start');
  @override
  late final GeneratedColumn<DateTime> start = GeneratedColumn<DateTime>(
    'start',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endMeta = const VerificationMeta('end');
  @override
  late final GeneratedColumn<DateTime> end = GeneratedColumn<DateTime>(
    'end',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startingBalanceCentsMeta =
      const VerificationMeta('startingBalanceCents');
  @override
  late final GeneratedColumn<int> startingBalanceCents = GeneratedColumn<int>(
    'starting_balance_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<BudgetPeriod, String> period =
      GeneratedColumn<String>(
        'period',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: Constant(BudgetPeriod.semester.name),
      ).withConverter<BudgetPeriod>($TermsTable.$converterperiod);
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    start,
    end,
    startingBalanceCents,
    period,
    archivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'terms';
  @override
  VerificationContext validateIntegrity(
    Insertable<TermRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('start')) {
      context.handle(
        _startMeta,
        start.isAcceptableOrUnknown(data['start']!, _startMeta),
      );
    } else if (isInserting) {
      context.missing(_startMeta);
    }
    if (data.containsKey('end')) {
      context.handle(
        _endMeta,
        end.isAcceptableOrUnknown(data['end']!, _endMeta),
      );
    } else if (isInserting) {
      context.missing(_endMeta);
    }
    if (data.containsKey('starting_balance_cents')) {
      context.handle(
        _startingBalanceCentsMeta,
        startingBalanceCents.isAcceptableOrUnknown(
          data['starting_balance_cents']!,
          _startingBalanceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startingBalanceCentsMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TermRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TermRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      start: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start'],
      )!,
      end: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end'],
      )!,
      startingBalanceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}starting_balance_cents'],
      )!,
      period: $TermsTable.$converterperiod.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}period'],
        )!,
      ),
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
    );
  }

  @override
  $TermsTable createAlias(String alias) {
    return $TermsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BudgetPeriod, String, String> $converterperiod =
      const EnumNameConverter<BudgetPeriod>(BudgetPeriod.values);
}

class TermRow extends DataClass implements Insertable<TermRow> {
  final int id;
  final String name;
  final DateTime start;
  final DateTime end;
  final int startingBalanceCents;

  /// Stored by enum *name* (added in schema 3; older terms are semesters).
  final BudgetPeriod period;

  /// Set when a term is finished; the current term has this null.
  final DateTime? archivedAt;
  const TermRow({
    required this.id,
    required this.name,
    required this.start,
    required this.end,
    required this.startingBalanceCents,
    required this.period,
    this.archivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['start'] = Variable<DateTime>(start);
    map['end'] = Variable<DateTime>(end);
    map['starting_balance_cents'] = Variable<int>(startingBalanceCents);
    {
      map['period'] = Variable<String>(
        $TermsTable.$converterperiod.toSql(period),
      );
    }
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    return map;
  }

  TermsCompanion toCompanion(bool nullToAbsent) {
    return TermsCompanion(
      id: Value(id),
      name: Value(name),
      start: Value(start),
      end: Value(end),
      startingBalanceCents: Value(startingBalanceCents),
      period: Value(period),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
    );
  }

  factory TermRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TermRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      start: serializer.fromJson<DateTime>(json['start']),
      end: serializer.fromJson<DateTime>(json['end']),
      startingBalanceCents: serializer.fromJson<int>(
        json['startingBalanceCents'],
      ),
      period: $TermsTable.$converterperiod.fromJson(
        serializer.fromJson<String>(json['period']),
      ),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'start': serializer.toJson<DateTime>(start),
      'end': serializer.toJson<DateTime>(end),
      'startingBalanceCents': serializer.toJson<int>(startingBalanceCents),
      'period': serializer.toJson<String>(
        $TermsTable.$converterperiod.toJson(period),
      ),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
    };
  }

  TermRow copyWith({
    int? id,
    String? name,
    DateTime? start,
    DateTime? end,
    int? startingBalanceCents,
    BudgetPeriod? period,
    Value<DateTime?> archivedAt = const Value.absent(),
  }) => TermRow(
    id: id ?? this.id,
    name: name ?? this.name,
    start: start ?? this.start,
    end: end ?? this.end,
    startingBalanceCents: startingBalanceCents ?? this.startingBalanceCents,
    period: period ?? this.period,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
  );
  TermRow copyWithCompanion(TermsCompanion data) {
    return TermRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      start: data.start.present ? data.start.value : this.start,
      end: data.end.present ? data.end.value : this.end,
      startingBalanceCents: data.startingBalanceCents.present
          ? data.startingBalanceCents.value
          : this.startingBalanceCents,
      period: data.period.present ? data.period.value : this.period,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TermRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('startingBalanceCents: $startingBalanceCents, ')
          ..write('period: $period, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    start,
    end,
    startingBalanceCents,
    period,
    archivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TermRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.start == this.start &&
          other.end == this.end &&
          other.startingBalanceCents == this.startingBalanceCents &&
          other.period == this.period &&
          other.archivedAt == this.archivedAt);
}

class TermsCompanion extends UpdateCompanion<TermRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> start;
  final Value<DateTime> end;
  final Value<int> startingBalanceCents;
  final Value<BudgetPeriod> period;
  final Value<DateTime?> archivedAt;
  const TermsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.start = const Value.absent(),
    this.end = const Value.absent(),
    this.startingBalanceCents = const Value.absent(),
    this.period = const Value.absent(),
    this.archivedAt = const Value.absent(),
  });
  TermsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime start,
    required DateTime end,
    required int startingBalanceCents,
    this.period = const Value.absent(),
    this.archivedAt = const Value.absent(),
  }) : name = Value(name),
       start = Value(start),
       end = Value(end),
       startingBalanceCents = Value(startingBalanceCents);
  static Insertable<TermRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? start,
    Expression<DateTime>? end,
    Expression<int>? startingBalanceCents,
    Expression<String>? period,
    Expression<DateTime>? archivedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (start != null) 'start': start,
      if (end != null) 'end': end,
      if (startingBalanceCents != null)
        'starting_balance_cents': startingBalanceCents,
      if (period != null) 'period': period,
      if (archivedAt != null) 'archived_at': archivedAt,
    });
  }

  TermsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? start,
    Value<DateTime>? end,
    Value<int>? startingBalanceCents,
    Value<BudgetPeriod>? period,
    Value<DateTime?>? archivedAt,
  }) {
    return TermsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      start: start ?? this.start,
      end: end ?? this.end,
      startingBalanceCents: startingBalanceCents ?? this.startingBalanceCents,
      period: period ?? this.period,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (start.present) {
      map['start'] = Variable<DateTime>(start.value);
    }
    if (end.present) {
      map['end'] = Variable<DateTime>(end.value);
    }
    if (startingBalanceCents.present) {
      map['starting_balance_cents'] = Variable<int>(startingBalanceCents.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(
        $TermsTable.$converterperiod.toSql(period.value),
      );
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TermsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('start: $start, ')
          ..write('end: $end, ')
          ..write('startingBalanceCents: $startingBalanceCents, ')
          ..write('period: $period, ')
          ..write('archivedAt: $archivedAt')
          ..write(')'))
        .toString();
  }
}

class $CustomCategoriesTable extends CustomCategories
    with TableInfo<$CustomCategoriesTable, CustomCategoryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CustomCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    emoji,
    name,
    createdAt,
    lastUsedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'custom_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<CustomCategoryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CustomCategoryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CustomCategoryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      ),
    );
  }

  @override
  $CustomCategoriesTable createAlias(String alias) {
    return $CustomCategoriesTable(attachedDatabase, alias);
  }
}

class CustomCategoryRow extends DataClass
    implements Insertable<CustomCategoryRow> {
  final String id;
  final String emoji;
  final String name;
  final DateTime createdAt;

  /// Last time an expense was logged in it; the picker shows these first.
  final DateTime? lastUsedAt;
  const CustomCategoryRow({
    required this.id,
    required this.emoji,
    required this.name,
    required this.createdAt,
    this.lastUsedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['emoji'] = Variable<String>(emoji);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    return map;
  }

  CustomCategoriesCompanion toCompanion(bool nullToAbsent) {
    return CustomCategoriesCompanion(
      id: Value(id),
      emoji: Value(emoji),
      name: Value(name),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
    );
  }

  factory CustomCategoryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CustomCategoryRow(
      id: serializer.fromJson<String>(json['id']),
      emoji: serializer.fromJson<String>(json['emoji']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'emoji': serializer.toJson<String>(emoji),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
    };
  }

  CustomCategoryRow copyWith({
    String? id,
    String? emoji,
    String? name,
    DateTime? createdAt,
    Value<DateTime?> lastUsedAt = const Value.absent(),
  }) => CustomCategoryRow(
    id: id ?? this.id,
    emoji: emoji ?? this.emoji,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
  );
  CustomCategoryRow copyWithCompanion(CustomCategoriesCompanion data) {
    return CustomCategoryRow(
      id: data.id.present ? data.id.value : this.id,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CustomCategoryRow(')
          ..write('id: $id, ')
          ..write('emoji: $emoji, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, emoji, name, createdAt, lastUsedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CustomCategoryRow &&
          other.id == this.id &&
          other.emoji == this.emoji &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt);
}

class CustomCategoriesCompanion extends UpdateCompanion<CustomCategoryRow> {
  final Value<String> id;
  final Value<String> emoji;
  final Value<String> name;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int> rowid;
  const CustomCategoriesCompanion({
    this.id = const Value.absent(),
    this.emoji = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CustomCategoriesCompanion.insert({
    required String id,
    required String emoji,
    required String name,
    required DateTime createdAt,
    this.lastUsedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       emoji = Value(emoji),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<CustomCategoryRow> custom({
    Expression<String>? id,
    Expression<String>? emoji,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (emoji != null) 'emoji': emoji,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CustomCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? emoji,
    Value<String>? name,
    Value<DateTime>? createdAt,
    Value<DateTime?>? lastUsedAt,
    Value<int>? rowid,
  }) {
    return CustomCategoriesCompanion(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CustomCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('emoji: $emoji, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExpensesTable extends Expenses
    with TableInfo<$ExpensesTable, ExpenseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExpensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _termIdMeta = const VerificationMeta('termId');
  @override
  late final GeneratedColumn<int> termId = GeneratedColumn<int>(
    'term_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES terms (id)',
    ),
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ExpenseCategory, String>
  category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ExpenseCategory>($ExpensesTable.$convertercategory);
  static const VerificationMeta _isNeedMeta = const VerificationMeta('isNeed');
  @override
  late final GeneratedColumn<bool> isNeed = GeneratedColumn<bool>(
    'is_need',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_need" IN (0, 1))',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isPlannedMeta = const VerificationMeta(
    'isPlanned',
  );
  @override
  late final GeneratedColumn<bool> isPlanned = GeneratedColumn<bool>(
    'is_planned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_planned" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _customCategoryIdMeta = const VerificationMeta(
    'customCategoryId',
  );
  @override
  late final GeneratedColumn<String> customCategoryId = GeneratedColumn<String>(
    'custom_category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES custom_categories (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    termId,
    amountCents,
    category,
    isNeed,
    note,
    createdAt,
    isPlanned,
    deletedAt,
    customCategoryId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'expenses';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExpenseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('term_id')) {
      context.handle(
        _termIdMeta,
        termId.isAcceptableOrUnknown(data['term_id']!, _termIdMeta),
      );
    } else if (isInserting) {
      context.missing(_termIdMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('is_need')) {
      context.handle(
        _isNeedMeta,
        isNeed.isAcceptableOrUnknown(data['is_need']!, _isNeedMeta),
      );
    } else if (isInserting) {
      context.missing(_isNeedMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('is_planned')) {
      context.handle(
        _isPlannedMeta,
        isPlanned.isAcceptableOrUnknown(data['is_planned']!, _isPlannedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('custom_category_id')) {
      context.handle(
        _customCategoryIdMeta,
        customCategoryId.isAcceptableOrUnknown(
          data['custom_category_id']!,
          _customCategoryIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExpenseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExpenseRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      termId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}term_id'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      category: $ExpensesTable.$convertercategory.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}category'],
        )!,
      ),
      isNeed: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_need'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isPlanned: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_planned'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      customCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}custom_category_id'],
      ),
    );
  }

  @override
  $ExpensesTable createAlias(String alias) {
    return $ExpensesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ExpenseCategory, String, String>
  $convertercategory = const EnumNameConverter<ExpenseCategory>(
    ExpenseCategory.values,
  );
}

class ExpenseRow extends DataClass implements Insertable<ExpenseRow> {
  final String id;
  final int termId;
  final int amountCents;

  /// Stored by enum *name* — rename values only together with a migration.
  final ExpenseCategory category;
  final bool isNeed;
  final String? note;
  final DateTime createdAt;

  /// Paid from a reserved upcoming cost (added in schema 2).
  final bool isPlanned;

  /// Soft delete, so a future "Undo" can bring it back.
  final DateTime? deletedAt;

  /// The person's own category (added in schema 5); [category] is then
  /// `other`, which is where the expense stays if the category is deleted.
  final String? customCategoryId;
  const ExpenseRow({
    required this.id,
    required this.termId,
    required this.amountCents,
    required this.category,
    required this.isNeed,
    this.note,
    required this.createdAt,
    required this.isPlanned,
    this.deletedAt,
    this.customCategoryId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['term_id'] = Variable<int>(termId);
    map['amount_cents'] = Variable<int>(amountCents);
    {
      map['category'] = Variable<String>(
        $ExpensesTable.$convertercategory.toSql(category),
      );
    }
    map['is_need'] = Variable<bool>(isNeed);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_planned'] = Variable<bool>(isPlanned);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || customCategoryId != null) {
      map['custom_category_id'] = Variable<String>(customCategoryId);
    }
    return map;
  }

  ExpensesCompanion toCompanion(bool nullToAbsent) {
    return ExpensesCompanion(
      id: Value(id),
      termId: Value(termId),
      amountCents: Value(amountCents),
      category: Value(category),
      isNeed: Value(isNeed),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
      isPlanned: Value(isPlanned),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      customCategoryId: customCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(customCategoryId),
    );
  }

  factory ExpenseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExpenseRow(
      id: serializer.fromJson<String>(json['id']),
      termId: serializer.fromJson<int>(json['termId']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      category: $ExpensesTable.$convertercategory.fromJson(
        serializer.fromJson<String>(json['category']),
      ),
      isNeed: serializer.fromJson<bool>(json['isNeed']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isPlanned: serializer.fromJson<bool>(json['isPlanned']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      customCategoryId: serializer.fromJson<String?>(json['customCategoryId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'termId': serializer.toJson<int>(termId),
      'amountCents': serializer.toJson<int>(amountCents),
      'category': serializer.toJson<String>(
        $ExpensesTable.$convertercategory.toJson(category),
      ),
      'isNeed': serializer.toJson<bool>(isNeed),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isPlanned': serializer.toJson<bool>(isPlanned),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'customCategoryId': serializer.toJson<String?>(customCategoryId),
    };
  }

  ExpenseRow copyWith({
    String? id,
    int? termId,
    int? amountCents,
    ExpenseCategory? category,
    bool? isNeed,
    Value<String?> note = const Value.absent(),
    DateTime? createdAt,
    bool? isPlanned,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> customCategoryId = const Value.absent(),
  }) => ExpenseRow(
    id: id ?? this.id,
    termId: termId ?? this.termId,
    amountCents: amountCents ?? this.amountCents,
    category: category ?? this.category,
    isNeed: isNeed ?? this.isNeed,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
    isPlanned: isPlanned ?? this.isPlanned,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    customCategoryId: customCategoryId.present
        ? customCategoryId.value
        : this.customCategoryId,
  );
  ExpenseRow copyWithCompanion(ExpensesCompanion data) {
    return ExpenseRow(
      id: data.id.present ? data.id.value : this.id,
      termId: data.termId.present ? data.termId.value : this.termId,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      category: data.category.present ? data.category.value : this.category,
      isNeed: data.isNeed.present ? data.isNeed.value : this.isNeed,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isPlanned: data.isPlanned.present ? data.isPlanned.value : this.isPlanned,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      customCategoryId: data.customCategoryId.present
          ? data.customCategoryId.value
          : this.customCategoryId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExpenseRow(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('amountCents: $amountCents, ')
          ..write('category: $category, ')
          ..write('isNeed: $isNeed, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('isPlanned: $isPlanned, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('customCategoryId: $customCategoryId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    termId,
    amountCents,
    category,
    isNeed,
    note,
    createdAt,
    isPlanned,
    deletedAt,
    customCategoryId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExpenseRow &&
          other.id == this.id &&
          other.termId == this.termId &&
          other.amountCents == this.amountCents &&
          other.category == this.category &&
          other.isNeed == this.isNeed &&
          other.note == this.note &&
          other.createdAt == this.createdAt &&
          other.isPlanned == this.isPlanned &&
          other.deletedAt == this.deletedAt &&
          other.customCategoryId == this.customCategoryId);
}

class ExpensesCompanion extends UpdateCompanion<ExpenseRow> {
  final Value<String> id;
  final Value<int> termId;
  final Value<int> amountCents;
  final Value<ExpenseCategory> category;
  final Value<bool> isNeed;
  final Value<String?> note;
  final Value<DateTime> createdAt;
  final Value<bool> isPlanned;
  final Value<DateTime?> deletedAt;
  final Value<String?> customCategoryId;
  final Value<int> rowid;
  const ExpensesCompanion({
    this.id = const Value.absent(),
    this.termId = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.category = const Value.absent(),
    this.isNeed = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isPlanned = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.customCategoryId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExpensesCompanion.insert({
    required String id,
    required int termId,
    required int amountCents,
    required ExpenseCategory category,
    required bool isNeed,
    this.note = const Value.absent(),
    required DateTime createdAt,
    this.isPlanned = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.customCategoryId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       termId = Value(termId),
       amountCents = Value(amountCents),
       category = Value(category),
       isNeed = Value(isNeed),
       createdAt = Value(createdAt);
  static Insertable<ExpenseRow> custom({
    Expression<String>? id,
    Expression<int>? termId,
    Expression<int>? amountCents,
    Expression<String>? category,
    Expression<bool>? isNeed,
    Expression<String>? note,
    Expression<DateTime>? createdAt,
    Expression<bool>? isPlanned,
    Expression<DateTime>? deletedAt,
    Expression<String>? customCategoryId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (termId != null) 'term_id': termId,
      if (amountCents != null) 'amount_cents': amountCents,
      if (category != null) 'category': category,
      if (isNeed != null) 'is_need': isNeed,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (isPlanned != null) 'is_planned': isPlanned,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (customCategoryId != null) 'custom_category_id': customCategoryId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExpensesCompanion copyWith({
    Value<String>? id,
    Value<int>? termId,
    Value<int>? amountCents,
    Value<ExpenseCategory>? category,
    Value<bool>? isNeed,
    Value<String?>? note,
    Value<DateTime>? createdAt,
    Value<bool>? isPlanned,
    Value<DateTime?>? deletedAt,
    Value<String?>? customCategoryId,
    Value<int>? rowid,
  }) {
    return ExpensesCompanion(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      amountCents: amountCents ?? this.amountCents,
      category: category ?? this.category,
      isNeed: isNeed ?? this.isNeed,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      isPlanned: isPlanned ?? this.isPlanned,
      deletedAt: deletedAt ?? this.deletedAt,
      customCategoryId: customCategoryId ?? this.customCategoryId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (termId.present) {
      map['term_id'] = Variable<int>(termId.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(
        $ExpensesTable.$convertercategory.toSql(category.value),
      );
    }
    if (isNeed.present) {
      map['is_need'] = Variable<bool>(isNeed.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isPlanned.present) {
      map['is_planned'] = Variable<bool>(isPlanned.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (customCategoryId.present) {
      map['custom_category_id'] = Variable<String>(customCategoryId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExpensesCompanion(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('amountCents: $amountCents, ')
          ..write('category: $category, ')
          ..write('isNeed: $isNeed, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('isPlanned: $isPlanned, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('customCategoryId: $customCategoryId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RepeatingBillsTable extends RepeatingBills
    with TableInfo<$RepeatingBillsTable, RepeatingBillRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RepeatingBillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstDueMeta = const VerificationMeta(
    'firstDue',
  );
  @override
  late final GeneratedColumn<DateTime> firstDue = GeneratedColumn<DateTime>(
    'first_due',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    emoji,
    name,
    amountCents,
    firstDue,
    createdAt,
    endedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'repeating_bills';
  @override
  VerificationContext validateIntegrity(
    Insertable<RepeatingBillRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('first_due')) {
      context.handle(
        _firstDueMeta,
        firstDue.isAcceptableOrUnknown(data['first_due']!, _firstDueMeta),
      );
    } else if (isInserting) {
      context.missing(_firstDueMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RepeatingBillRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RepeatingBillRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      firstDue: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_due'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
    );
  }

  @override
  $RepeatingBillsTable createAlias(String alias) {
    return $RepeatingBillsTable(attachedDatabase, alias);
  }
}

class RepeatingBillRow extends DataClass
    implements Insertable<RepeatingBillRow> {
  final String id;
  final String emoji;
  final String name;
  final int amountCents;
  final DateTime firstDue;
  final DateTime createdAt;

  /// Set when the bill is stopped; no more months are reserved after it.
  final DateTime? endedAt;
  const RepeatingBillRow({
    required this.id,
    required this.emoji,
    required this.name,
    required this.amountCents,
    required this.firstDue,
    required this.createdAt,
    this.endedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['emoji'] = Variable<String>(emoji);
    map['name'] = Variable<String>(name);
    map['amount_cents'] = Variable<int>(amountCents);
    map['first_due'] = Variable<DateTime>(firstDue);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    return map;
  }

  RepeatingBillsCompanion toCompanion(bool nullToAbsent) {
    return RepeatingBillsCompanion(
      id: Value(id),
      emoji: Value(emoji),
      name: Value(name),
      amountCents: Value(amountCents),
      firstDue: Value(firstDue),
      createdAt: Value(createdAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
    );
  }

  factory RepeatingBillRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RepeatingBillRow(
      id: serializer.fromJson<String>(json['id']),
      emoji: serializer.fromJson<String>(json['emoji']),
      name: serializer.fromJson<String>(json['name']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      firstDue: serializer.fromJson<DateTime>(json['firstDue']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'emoji': serializer.toJson<String>(emoji),
      'name': serializer.toJson<String>(name),
      'amountCents': serializer.toJson<int>(amountCents),
      'firstDue': serializer.toJson<DateTime>(firstDue),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
    };
  }

  RepeatingBillRow copyWith({
    String? id,
    String? emoji,
    String? name,
    int? amountCents,
    DateTime? firstDue,
    DateTime? createdAt,
    Value<DateTime?> endedAt = const Value.absent(),
  }) => RepeatingBillRow(
    id: id ?? this.id,
    emoji: emoji ?? this.emoji,
    name: name ?? this.name,
    amountCents: amountCents ?? this.amountCents,
    firstDue: firstDue ?? this.firstDue,
    createdAt: createdAt ?? this.createdAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
  );
  RepeatingBillRow copyWithCompanion(RepeatingBillsCompanion data) {
    return RepeatingBillRow(
      id: data.id.present ? data.id.value : this.id,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      name: data.name.present ? data.name.value : this.name,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      firstDue: data.firstDue.present ? data.firstDue.value : this.firstDue,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RepeatingBillRow(')
          ..write('id: $id, ')
          ..write('emoji: $emoji, ')
          ..write('name: $name, ')
          ..write('amountCents: $amountCents, ')
          ..write('firstDue: $firstDue, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, emoji, name, amountCents, firstDue, createdAt, endedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RepeatingBillRow &&
          other.id == this.id &&
          other.emoji == this.emoji &&
          other.name == this.name &&
          other.amountCents == this.amountCents &&
          other.firstDue == this.firstDue &&
          other.createdAt == this.createdAt &&
          other.endedAt == this.endedAt);
}

class RepeatingBillsCompanion extends UpdateCompanion<RepeatingBillRow> {
  final Value<String> id;
  final Value<String> emoji;
  final Value<String> name;
  final Value<int> amountCents;
  final Value<DateTime> firstDue;
  final Value<DateTime> createdAt;
  final Value<DateTime?> endedAt;
  final Value<int> rowid;
  const RepeatingBillsCompanion({
    this.id = const Value.absent(),
    this.emoji = const Value.absent(),
    this.name = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.firstDue = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RepeatingBillsCompanion.insert({
    required String id,
    required String emoji,
    required String name,
    required int amountCents,
    required DateTime firstDue,
    required DateTime createdAt,
    this.endedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       emoji = Value(emoji),
       name = Value(name),
       amountCents = Value(amountCents),
       firstDue = Value(firstDue),
       createdAt = Value(createdAt);
  static Insertable<RepeatingBillRow> custom({
    Expression<String>? id,
    Expression<String>? emoji,
    Expression<String>? name,
    Expression<int>? amountCents,
    Expression<DateTime>? firstDue,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? endedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (emoji != null) 'emoji': emoji,
      if (name != null) 'name': name,
      if (amountCents != null) 'amount_cents': amountCents,
      if (firstDue != null) 'first_due': firstDue,
      if (createdAt != null) 'created_at': createdAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RepeatingBillsCompanion copyWith({
    Value<String>? id,
    Value<String>? emoji,
    Value<String>? name,
    Value<int>? amountCents,
    Value<DateTime>? firstDue,
    Value<DateTime>? createdAt,
    Value<DateTime?>? endedAt,
    Value<int>? rowid,
  }) {
    return RepeatingBillsCompanion(
      id: id ?? this.id,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      firstDue: firstDue ?? this.firstDue,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (firstDue.present) {
      map['first_due'] = Variable<DateTime>(firstDue.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RepeatingBillsCompanion(')
          ..write('id: $id, ')
          ..write('emoji: $emoji, ')
          ..write('name: $name, ')
          ..write('amountCents: $amountCents, ')
          ..write('firstDue: $firstDue, ')
          ..write('createdAt: $createdAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UpcomingCostsTable extends UpcomingCosts
    with TableInfo<$UpcomingCostsTable, UpcomingCostRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UpcomingCostsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _termIdMeta = const VerificationMeta('termId');
  @override
  late final GeneratedColumn<int> termId = GeneratedColumn<int>(
    'term_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES terms (id)',
    ),
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidAtMeta = const VerificationMeta('paidAt');
  @override
  late final GeneratedColumn<DateTime> paidAt = GeneratedColumn<DateTime>(
    'paid_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _billIdMeta = const VerificationMeta('billId');
  @override
  late final GeneratedColumn<String> billId = GeneratedColumn<String>(
    'bill_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES repeating_bills (id)',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    termId,
    emoji,
    name,
    amountCents,
    dueDate,
    paidAt,
    billId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upcoming_costs';
  @override
  VerificationContext validateIntegrity(
    Insertable<UpcomingCostRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('term_id')) {
      context.handle(
        _termIdMeta,
        termId.isAcceptableOrUnknown(data['term_id']!, _termIdMeta),
      );
    } else if (isInserting) {
      context.missing(_termIdMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('paid_at')) {
      context.handle(
        _paidAtMeta,
        paidAt.isAcceptableOrUnknown(data['paid_at']!, _paidAtMeta),
      );
    }
    if (data.containsKey('bill_id')) {
      context.handle(
        _billIdMeta,
        billId.isAcceptableOrUnknown(data['bill_id']!, _billIdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UpcomingCostRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UpcomingCostRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      termId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}term_id'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      paidAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}paid_at'],
      ),
      billId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bill_id'],
      ),
    );
  }

  @override
  $UpcomingCostsTable createAlias(String alias) {
    return $UpcomingCostsTable(attachedDatabase, alias);
  }
}

class UpcomingCostRow extends DataClass implements Insertable<UpcomingCostRow> {
  final String id;
  final int termId;
  final String emoji;
  final String name;
  final int amountCents;
  final DateTime dueDate;
  final DateTime? paidAt;

  /// One month of a repeating bill (added in schema 4); null for one-offs.
  final String? billId;
  const UpcomingCostRow({
    required this.id,
    required this.termId,
    required this.emoji,
    required this.name,
    required this.amountCents,
    required this.dueDate,
    this.paidAt,
    this.billId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['term_id'] = Variable<int>(termId);
    map['emoji'] = Variable<String>(emoji);
    map['name'] = Variable<String>(name);
    map['amount_cents'] = Variable<int>(amountCents);
    map['due_date'] = Variable<DateTime>(dueDate);
    if (!nullToAbsent || paidAt != null) {
      map['paid_at'] = Variable<DateTime>(paidAt);
    }
    if (!nullToAbsent || billId != null) {
      map['bill_id'] = Variable<String>(billId);
    }
    return map;
  }

  UpcomingCostsCompanion toCompanion(bool nullToAbsent) {
    return UpcomingCostsCompanion(
      id: Value(id),
      termId: Value(termId),
      emoji: Value(emoji),
      name: Value(name),
      amountCents: Value(amountCents),
      dueDate: Value(dueDate),
      paidAt: paidAt == null && nullToAbsent
          ? const Value.absent()
          : Value(paidAt),
      billId: billId == null && nullToAbsent
          ? const Value.absent()
          : Value(billId),
    );
  }

  factory UpcomingCostRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UpcomingCostRow(
      id: serializer.fromJson<String>(json['id']),
      termId: serializer.fromJson<int>(json['termId']),
      emoji: serializer.fromJson<String>(json['emoji']),
      name: serializer.fromJson<String>(json['name']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      paidAt: serializer.fromJson<DateTime?>(json['paidAt']),
      billId: serializer.fromJson<String?>(json['billId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'termId': serializer.toJson<int>(termId),
      'emoji': serializer.toJson<String>(emoji),
      'name': serializer.toJson<String>(name),
      'amountCents': serializer.toJson<int>(amountCents),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'paidAt': serializer.toJson<DateTime?>(paidAt),
      'billId': serializer.toJson<String?>(billId),
    };
  }

  UpcomingCostRow copyWith({
    String? id,
    int? termId,
    String? emoji,
    String? name,
    int? amountCents,
    DateTime? dueDate,
    Value<DateTime?> paidAt = const Value.absent(),
    Value<String?> billId = const Value.absent(),
  }) => UpcomingCostRow(
    id: id ?? this.id,
    termId: termId ?? this.termId,
    emoji: emoji ?? this.emoji,
    name: name ?? this.name,
    amountCents: amountCents ?? this.amountCents,
    dueDate: dueDate ?? this.dueDate,
    paidAt: paidAt.present ? paidAt.value : this.paidAt,
    billId: billId.present ? billId.value : this.billId,
  );
  UpcomingCostRow copyWithCompanion(UpcomingCostsCompanion data) {
    return UpcomingCostRow(
      id: data.id.present ? data.id.value : this.id,
      termId: data.termId.present ? data.termId.value : this.termId,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      name: data.name.present ? data.name.value : this.name,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      paidAt: data.paidAt.present ? data.paidAt.value : this.paidAt,
      billId: data.billId.present ? data.billId.value : this.billId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UpcomingCostRow(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('emoji: $emoji, ')
          ..write('name: $name, ')
          ..write('amountCents: $amountCents, ')
          ..write('dueDate: $dueDate, ')
          ..write('paidAt: $paidAt, ')
          ..write('billId: $billId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    termId,
    emoji,
    name,
    amountCents,
    dueDate,
    paidAt,
    billId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpcomingCostRow &&
          other.id == this.id &&
          other.termId == this.termId &&
          other.emoji == this.emoji &&
          other.name == this.name &&
          other.amountCents == this.amountCents &&
          other.dueDate == this.dueDate &&
          other.paidAt == this.paidAt &&
          other.billId == this.billId);
}

class UpcomingCostsCompanion extends UpdateCompanion<UpcomingCostRow> {
  final Value<String> id;
  final Value<int> termId;
  final Value<String> emoji;
  final Value<String> name;
  final Value<int> amountCents;
  final Value<DateTime> dueDate;
  final Value<DateTime?> paidAt;
  final Value<String?> billId;
  final Value<int> rowid;
  const UpcomingCostsCompanion({
    this.id = const Value.absent(),
    this.termId = const Value.absent(),
    this.emoji = const Value.absent(),
    this.name = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.paidAt = const Value.absent(),
    this.billId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UpcomingCostsCompanion.insert({
    required String id,
    required int termId,
    required String emoji,
    required String name,
    required int amountCents,
    required DateTime dueDate,
    this.paidAt = const Value.absent(),
    this.billId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       termId = Value(termId),
       emoji = Value(emoji),
       name = Value(name),
       amountCents = Value(amountCents),
       dueDate = Value(dueDate);
  static Insertable<UpcomingCostRow> custom({
    Expression<String>? id,
    Expression<int>? termId,
    Expression<String>? emoji,
    Expression<String>? name,
    Expression<int>? amountCents,
    Expression<DateTime>? dueDate,
    Expression<DateTime>? paidAt,
    Expression<String>? billId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (termId != null) 'term_id': termId,
      if (emoji != null) 'emoji': emoji,
      if (name != null) 'name': name,
      if (amountCents != null) 'amount_cents': amountCents,
      if (dueDate != null) 'due_date': dueDate,
      if (paidAt != null) 'paid_at': paidAt,
      if (billId != null) 'bill_id': billId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UpcomingCostsCompanion copyWith({
    Value<String>? id,
    Value<int>? termId,
    Value<String>? emoji,
    Value<String>? name,
    Value<int>? amountCents,
    Value<DateTime>? dueDate,
    Value<DateTime?>? paidAt,
    Value<String?>? billId,
    Value<int>? rowid,
  }) {
    return UpcomingCostsCompanion(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      emoji: emoji ?? this.emoji,
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      dueDate: dueDate ?? this.dueDate,
      paidAt: paidAt ?? this.paidAt,
      billId: billId ?? this.billId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (termId.present) {
      map['term_id'] = Variable<int>(termId.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (paidAt.present) {
      map['paid_at'] = Variable<DateTime>(paidAt.value);
    }
    if (billId.present) {
      map['bill_id'] = Variable<String>(billId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UpcomingCostsCompanion(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('emoji: $emoji, ')
          ..write('name: $name, ')
          ..write('amountCents: $amountCents, ')
          ..write('dueDate: $dueDate, ')
          ..write('paidAt: $paidAt, ')
          ..write('billId: $billId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IncomesTable extends Incomes with TableInfo<$IncomesTable, IncomeRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IncomesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _termIdMeta = const VerificationMeta('termId');
  @override
  late final GeneratedColumn<int> termId = GeneratedColumn<int>(
    'term_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES terms (id)',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<IncomeFrequency, String>
  frequency = GeneratedColumn<String>(
    'frequency',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<IncomeFrequency>($IncomesTable.$converterfrequency);
  static const VerificationMeta _firstDateMeta = const VerificationMeta(
    'firstDate',
  );
  @override
  late final GeneratedColumn<DateTime> firstDate = GeneratedColumn<DateTime>(
    'first_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endsOnMeta = const VerificationMeta('endsOn');
  @override
  late final GeneratedColumn<DateTime> endsOn = GeneratedColumn<DateTime>(
    'ends_on',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    termId,
    name,
    amountCents,
    frequency,
    firstDate,
    endsOn,
    createdAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'incomes';
  @override
  VerificationContext validateIntegrity(
    Insertable<IncomeRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('term_id')) {
      context.handle(
        _termIdMeta,
        termId.isAcceptableOrUnknown(data['term_id']!, _termIdMeta),
      );
    } else if (isInserting) {
      context.missing(_termIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('first_date')) {
      context.handle(
        _firstDateMeta,
        firstDate.isAcceptableOrUnknown(data['first_date']!, _firstDateMeta),
      );
    } else if (isInserting) {
      context.missing(_firstDateMeta);
    }
    if (data.containsKey('ends_on')) {
      context.handle(
        _endsOnMeta,
        endsOn.isAcceptableOrUnknown(data['ends_on']!, _endsOnMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  IncomeRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return IncomeRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      termId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}term_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      frequency: $IncomesTable.$converterfrequency.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}frequency'],
        )!,
      ),
      firstDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}first_date'],
      )!,
      endsOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ends_on'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $IncomesTable createAlias(String alias) {
    return $IncomesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<IncomeFrequency, String, String>
  $converterfrequency = const EnumNameConverter<IncomeFrequency>(
    IncomeFrequency.values,
  );
}

class IncomeRow extends DataClass implements Insertable<IncomeRow> {
  final String id;
  final int termId;
  final String name;
  final int amountCents;

  /// Stored by enum *name* — rename values only together with a migration.
  final IncomeFrequency frequency;
  final DateTime firstDate;

  /// Set when a repeating payment is stopped; paydays up to it still count.
  final DateTime? endsOn;
  final DateTime createdAt;

  /// Soft delete: removed by mistake, so none of its payments count.
  final DateTime? deletedAt;
  const IncomeRow({
    required this.id,
    required this.termId,
    required this.name,
    required this.amountCents,
    required this.frequency,
    required this.firstDate,
    this.endsOn,
    required this.createdAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['term_id'] = Variable<int>(termId);
    map['name'] = Variable<String>(name);
    map['amount_cents'] = Variable<int>(amountCents);
    {
      map['frequency'] = Variable<String>(
        $IncomesTable.$converterfrequency.toSql(frequency),
      );
    }
    map['first_date'] = Variable<DateTime>(firstDate);
    if (!nullToAbsent || endsOn != null) {
      map['ends_on'] = Variable<DateTime>(endsOn);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  IncomesCompanion toCompanion(bool nullToAbsent) {
    return IncomesCompanion(
      id: Value(id),
      termId: Value(termId),
      name: Value(name),
      amountCents: Value(amountCents),
      frequency: Value(frequency),
      firstDate: Value(firstDate),
      endsOn: endsOn == null && nullToAbsent
          ? const Value.absent()
          : Value(endsOn),
      createdAt: Value(createdAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory IncomeRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return IncomeRow(
      id: serializer.fromJson<String>(json['id']),
      termId: serializer.fromJson<int>(json['termId']),
      name: serializer.fromJson<String>(json['name']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      frequency: $IncomesTable.$converterfrequency.fromJson(
        serializer.fromJson<String>(json['frequency']),
      ),
      firstDate: serializer.fromJson<DateTime>(json['firstDate']),
      endsOn: serializer.fromJson<DateTime?>(json['endsOn']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'termId': serializer.toJson<int>(termId),
      'name': serializer.toJson<String>(name),
      'amountCents': serializer.toJson<int>(amountCents),
      'frequency': serializer.toJson<String>(
        $IncomesTable.$converterfrequency.toJson(frequency),
      ),
      'firstDate': serializer.toJson<DateTime>(firstDate),
      'endsOn': serializer.toJson<DateTime?>(endsOn),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  IncomeRow copyWith({
    String? id,
    int? termId,
    String? name,
    int? amountCents,
    IncomeFrequency? frequency,
    DateTime? firstDate,
    Value<DateTime?> endsOn = const Value.absent(),
    DateTime? createdAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => IncomeRow(
    id: id ?? this.id,
    termId: termId ?? this.termId,
    name: name ?? this.name,
    amountCents: amountCents ?? this.amountCents,
    frequency: frequency ?? this.frequency,
    firstDate: firstDate ?? this.firstDate,
    endsOn: endsOn.present ? endsOn.value : this.endsOn,
    createdAt: createdAt ?? this.createdAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  IncomeRow copyWithCompanion(IncomesCompanion data) {
    return IncomeRow(
      id: data.id.present ? data.id.value : this.id,
      termId: data.termId.present ? data.termId.value : this.termId,
      name: data.name.present ? data.name.value : this.name,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      frequency: data.frequency.present ? data.frequency.value : this.frequency,
      firstDate: data.firstDate.present ? data.firstDate.value : this.firstDate,
      endsOn: data.endsOn.present ? data.endsOn.value : this.endsOn,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('IncomeRow(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('name: $name, ')
          ..write('amountCents: $amountCents, ')
          ..write('frequency: $frequency, ')
          ..write('firstDate: $firstDate, ')
          ..write('endsOn: $endsOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    termId,
    name,
    amountCents,
    frequency,
    firstDate,
    endsOn,
    createdAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is IncomeRow &&
          other.id == this.id &&
          other.termId == this.termId &&
          other.name == this.name &&
          other.amountCents == this.amountCents &&
          other.frequency == this.frequency &&
          other.firstDate == this.firstDate &&
          other.endsOn == this.endsOn &&
          other.createdAt == this.createdAt &&
          other.deletedAt == this.deletedAt);
}

class IncomesCompanion extends UpdateCompanion<IncomeRow> {
  final Value<String> id;
  final Value<int> termId;
  final Value<String> name;
  final Value<int> amountCents;
  final Value<IncomeFrequency> frequency;
  final Value<DateTime> firstDate;
  final Value<DateTime?> endsOn;
  final Value<DateTime> createdAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const IncomesCompanion({
    this.id = const Value.absent(),
    this.termId = const Value.absent(),
    this.name = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.frequency = const Value.absent(),
    this.firstDate = const Value.absent(),
    this.endsOn = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IncomesCompanion.insert({
    required String id,
    required int termId,
    required String name,
    required int amountCents,
    required IncomeFrequency frequency,
    required DateTime firstDate,
    this.endsOn = const Value.absent(),
    required DateTime createdAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       termId = Value(termId),
       name = Value(name),
       amountCents = Value(amountCents),
       frequency = Value(frequency),
       firstDate = Value(firstDate),
       createdAt = Value(createdAt);
  static Insertable<IncomeRow> custom({
    Expression<String>? id,
    Expression<int>? termId,
    Expression<String>? name,
    Expression<int>? amountCents,
    Expression<String>? frequency,
    Expression<DateTime>? firstDate,
    Expression<DateTime>? endsOn,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (termId != null) 'term_id': termId,
      if (name != null) 'name': name,
      if (amountCents != null) 'amount_cents': amountCents,
      if (frequency != null) 'frequency': frequency,
      if (firstDate != null) 'first_date': firstDate,
      if (endsOn != null) 'ends_on': endsOn,
      if (createdAt != null) 'created_at': createdAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IncomesCompanion copyWith({
    Value<String>? id,
    Value<int>? termId,
    Value<String>? name,
    Value<int>? amountCents,
    Value<IncomeFrequency>? frequency,
    Value<DateTime>? firstDate,
    Value<DateTime?>? endsOn,
    Value<DateTime>? createdAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return IncomesCompanion(
      id: id ?? this.id,
      termId: termId ?? this.termId,
      name: name ?? this.name,
      amountCents: amountCents ?? this.amountCents,
      frequency: frequency ?? this.frequency,
      firstDate: firstDate ?? this.firstDate,
      endsOn: endsOn ?? this.endsOn,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (termId.present) {
      map['term_id'] = Variable<int>(termId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (frequency.present) {
      map['frequency'] = Variable<String>(
        $IncomesTable.$converterfrequency.toSql(frequency.value),
      );
    }
    if (firstDate.present) {
      map['first_date'] = Variable<DateTime>(firstDate.value);
    }
    if (endsOn.present) {
      map['ends_on'] = Variable<DateTime>(endsOn.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IncomesCompanion(')
          ..write('id: $id, ')
          ..write('termId: $termId, ')
          ..write('name: $name, ')
          ..write('amountCents: $amountCents, ')
          ..write('frequency: $frequency, ')
          ..write('firstDate: $firstDate, ')
          ..write('endsOn: $endsOn, ')
          ..write('createdAt: $createdAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BillSplitsTable extends BillSplits
    with TableInfo<$BillSplitsTable, BillSplitRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BillSplitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _personMeta = const VerificationMeta('person');
  @override
  late final GeneratedColumn<String> person = GeneratedColumn<String>(
    'person',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _theyOweYouMeta = const VerificationMeta(
    'theyOweYou',
  );
  @override
  late final GeneratedColumn<bool> theyOweYou = GeneratedColumn<bool>(
    'they_owe_you',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("they_owe_you" IN (0, 1))',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _settledAtMeta = const VerificationMeta(
    'settledAt',
  );
  @override
  late final GeneratedColumn<DateTime> settledAt = GeneratedColumn<DateTime>(
    'settled_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    person,
    amountCents,
    note,
    theyOweYou,
    createdAt,
    settledAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bill_splits';
  @override
  VerificationContext validateIntegrity(
    Insertable<BillSplitRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('person')) {
      context.handle(
        _personMeta,
        person.isAcceptableOrUnknown(data['person']!, _personMeta),
      );
    } else if (isInserting) {
      context.missing(_personMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    if (data.containsKey('they_owe_you')) {
      context.handle(
        _theyOweYouMeta,
        theyOweYou.isAcceptableOrUnknown(
          data['they_owe_you']!,
          _theyOweYouMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_theyOweYouMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('settled_at')) {
      context.handle(
        _settledAtMeta,
        settledAt.isAcceptableOrUnknown(data['settled_at']!, _settledAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BillSplitRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BillSplitRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      person: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}person'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
      theyOweYou: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}they_owe_you'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      settledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}settled_at'],
      ),
    );
  }

  @override
  $BillSplitsTable createAlias(String alias) {
    return $BillSplitsTable(attachedDatabase, alias);
  }
}

class BillSplitRow extends DataClass implements Insertable<BillSplitRow> {
  final String id;
  final String person;
  final int amountCents;
  final String note;
  final bool theyOweYou;
  final DateTime createdAt;

  /// Settled splits are kept for history, just hidden.
  final DateTime? settledAt;
  const BillSplitRow({
    required this.id,
    required this.person,
    required this.amountCents,
    required this.note,
    required this.theyOweYou,
    required this.createdAt,
    this.settledAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['person'] = Variable<String>(person);
    map['amount_cents'] = Variable<int>(amountCents);
    map['note'] = Variable<String>(note);
    map['they_owe_you'] = Variable<bool>(theyOweYou);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || settledAt != null) {
      map['settled_at'] = Variable<DateTime>(settledAt);
    }
    return map;
  }

  BillSplitsCompanion toCompanion(bool nullToAbsent) {
    return BillSplitsCompanion(
      id: Value(id),
      person: Value(person),
      amountCents: Value(amountCents),
      note: Value(note),
      theyOweYou: Value(theyOweYou),
      createdAt: Value(createdAt),
      settledAt: settledAt == null && nullToAbsent
          ? const Value.absent()
          : Value(settledAt),
    );
  }

  factory BillSplitRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BillSplitRow(
      id: serializer.fromJson<String>(json['id']),
      person: serializer.fromJson<String>(json['person']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      note: serializer.fromJson<String>(json['note']),
      theyOweYou: serializer.fromJson<bool>(json['theyOweYou']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      settledAt: serializer.fromJson<DateTime?>(json['settledAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'person': serializer.toJson<String>(person),
      'amountCents': serializer.toJson<int>(amountCents),
      'note': serializer.toJson<String>(note),
      'theyOweYou': serializer.toJson<bool>(theyOweYou),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'settledAt': serializer.toJson<DateTime?>(settledAt),
    };
  }

  BillSplitRow copyWith({
    String? id,
    String? person,
    int? amountCents,
    String? note,
    bool? theyOweYou,
    DateTime? createdAt,
    Value<DateTime?> settledAt = const Value.absent(),
  }) => BillSplitRow(
    id: id ?? this.id,
    person: person ?? this.person,
    amountCents: amountCents ?? this.amountCents,
    note: note ?? this.note,
    theyOweYou: theyOweYou ?? this.theyOweYou,
    createdAt: createdAt ?? this.createdAt,
    settledAt: settledAt.present ? settledAt.value : this.settledAt,
  );
  BillSplitRow copyWithCompanion(BillSplitsCompanion data) {
    return BillSplitRow(
      id: data.id.present ? data.id.value : this.id,
      person: data.person.present ? data.person.value : this.person,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      note: data.note.present ? data.note.value : this.note,
      theyOweYou: data.theyOweYou.present
          ? data.theyOweYou.value
          : this.theyOweYou,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      settledAt: data.settledAt.present ? data.settledAt.value : this.settledAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BillSplitRow(')
          ..write('id: $id, ')
          ..write('person: $person, ')
          ..write('amountCents: $amountCents, ')
          ..write('note: $note, ')
          ..write('theyOweYou: $theyOweYou, ')
          ..write('createdAt: $createdAt, ')
          ..write('settledAt: $settledAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    person,
    amountCents,
    note,
    theyOweYou,
    createdAt,
    settledAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BillSplitRow &&
          other.id == this.id &&
          other.person == this.person &&
          other.amountCents == this.amountCents &&
          other.note == this.note &&
          other.theyOweYou == this.theyOweYou &&
          other.createdAt == this.createdAt &&
          other.settledAt == this.settledAt);
}

class BillSplitsCompanion extends UpdateCompanion<BillSplitRow> {
  final Value<String> id;
  final Value<String> person;
  final Value<int> amountCents;
  final Value<String> note;
  final Value<bool> theyOweYou;
  final Value<DateTime> createdAt;
  final Value<DateTime?> settledAt;
  final Value<int> rowid;
  const BillSplitsCompanion({
    this.id = const Value.absent(),
    this.person = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.note = const Value.absent(),
    this.theyOweYou = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.settledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BillSplitsCompanion.insert({
    required String id,
    required String person,
    required int amountCents,
    required String note,
    required bool theyOweYou,
    required DateTime createdAt,
    this.settledAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       person = Value(person),
       amountCents = Value(amountCents),
       note = Value(note),
       theyOweYou = Value(theyOweYou),
       createdAt = Value(createdAt);
  static Insertable<BillSplitRow> custom({
    Expression<String>? id,
    Expression<String>? person,
    Expression<int>? amountCents,
    Expression<String>? note,
    Expression<bool>? theyOweYou,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? settledAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (person != null) 'person': person,
      if (amountCents != null) 'amount_cents': amountCents,
      if (note != null) 'note': note,
      if (theyOweYou != null) 'they_owe_you': theyOweYou,
      if (createdAt != null) 'created_at': createdAt,
      if (settledAt != null) 'settled_at': settledAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BillSplitsCompanion copyWith({
    Value<String>? id,
    Value<String>? person,
    Value<int>? amountCents,
    Value<String>? note,
    Value<bool>? theyOweYou,
    Value<DateTime>? createdAt,
    Value<DateTime?>? settledAt,
    Value<int>? rowid,
  }) {
    return BillSplitsCompanion(
      id: id ?? this.id,
      person: person ?? this.person,
      amountCents: amountCents ?? this.amountCents,
      note: note ?? this.note,
      theyOweYou: theyOweYou ?? this.theyOweYou,
      createdAt: createdAt ?? this.createdAt,
      settledAt: settledAt ?? this.settledAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (person.present) {
      map['person'] = Variable<String>(person.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (theyOweYou.present) {
      map['they_owe_you'] = Variable<bool>(theyOweYou.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (settledAt.present) {
      map['settled_at'] = Variable<DateTime>(settledAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BillSplitsCompanion(')
          ..write('id: $id, ')
          ..write('person: $person, ')
          ..write('amountCents: $amountCents, ')
          ..write('note: $note, ')
          ..write('theyOweYou: $theyOweYou, ')
          ..write('createdAt: $createdAt, ')
          ..write('settledAt: $settledAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FriendsTable extends Friends with TableInfo<$FriendsTable, FriendRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FriendsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emojiMeta = const VerificationMeta('emoji');
  @override
  late final GeneratedColumn<String> emoji = GeneratedColumn<String>(
    'emoji',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _streakMeta = const VerificationMeta('streak');
  @override
  late final GeneratedColumn<int> streak = GeneratedColumn<int>(
    'streak',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noDeliveryDaysMeta = const VerificationMeta(
    'noDeliveryDays',
  );
  @override
  late final GeneratedColumn<String> noDeliveryDays = GeneratedColumn<String>(
    'no_delivery_days',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    position,
    name,
    emoji,
    streak,
    noDeliveryDays,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'friends';
  @override
  VerificationContext validateIntegrity(
    Insertable<FriendRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('emoji')) {
      context.handle(
        _emojiMeta,
        emoji.isAcceptableOrUnknown(data['emoji']!, _emojiMeta),
      );
    } else if (isInserting) {
      context.missing(_emojiMeta);
    }
    if (data.containsKey('streak')) {
      context.handle(
        _streakMeta,
        streak.isAcceptableOrUnknown(data['streak']!, _streakMeta),
      );
    } else if (isInserting) {
      context.missing(_streakMeta);
    }
    if (data.containsKey('no_delivery_days')) {
      context.handle(
        _noDeliveryDaysMeta,
        noDeliveryDays.isAcceptableOrUnknown(
          data['no_delivery_days']!,
          _noDeliveryDaysMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_noDeliveryDaysMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FriendRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FriendRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      emoji: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}emoji'],
      )!,
      streak: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak'],
      )!,
      noDeliveryDays: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}no_delivery_days'],
      )!,
    );
  }

  @override
  $FriendsTable createAlias(String alias) {
    return $FriendsTable(attachedDatabase, alias);
  }
}

class FriendRow extends DataClass implements Insertable<FriendRow> {
  final String id;
  final int position;
  final String name;
  final String emoji;
  final int streak;

  /// Challenge days as "1101": 1 = stayed delivery-free.
  final String noDeliveryDays;
  const FriendRow({
    required this.id,
    required this.position,
    required this.name,
    required this.emoji,
    required this.streak,
    required this.noDeliveryDays,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['position'] = Variable<int>(position);
    map['name'] = Variable<String>(name);
    map['emoji'] = Variable<String>(emoji);
    map['streak'] = Variable<int>(streak);
    map['no_delivery_days'] = Variable<String>(noDeliveryDays);
    return map;
  }

  FriendsCompanion toCompanion(bool nullToAbsent) {
    return FriendsCompanion(
      id: Value(id),
      position: Value(position),
      name: Value(name),
      emoji: Value(emoji),
      streak: Value(streak),
      noDeliveryDays: Value(noDeliveryDays),
    );
  }

  factory FriendRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FriendRow(
      id: serializer.fromJson<String>(json['id']),
      position: serializer.fromJson<int>(json['position']),
      name: serializer.fromJson<String>(json['name']),
      emoji: serializer.fromJson<String>(json['emoji']),
      streak: serializer.fromJson<int>(json['streak']),
      noDeliveryDays: serializer.fromJson<String>(json['noDeliveryDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'position': serializer.toJson<int>(position),
      'name': serializer.toJson<String>(name),
      'emoji': serializer.toJson<String>(emoji),
      'streak': serializer.toJson<int>(streak),
      'noDeliveryDays': serializer.toJson<String>(noDeliveryDays),
    };
  }

  FriendRow copyWith({
    String? id,
    int? position,
    String? name,
    String? emoji,
    int? streak,
    String? noDeliveryDays,
  }) => FriendRow(
    id: id ?? this.id,
    position: position ?? this.position,
    name: name ?? this.name,
    emoji: emoji ?? this.emoji,
    streak: streak ?? this.streak,
    noDeliveryDays: noDeliveryDays ?? this.noDeliveryDays,
  );
  FriendRow copyWithCompanion(FriendsCompanion data) {
    return FriendRow(
      id: data.id.present ? data.id.value : this.id,
      position: data.position.present ? data.position.value : this.position,
      name: data.name.present ? data.name.value : this.name,
      emoji: data.emoji.present ? data.emoji.value : this.emoji,
      streak: data.streak.present ? data.streak.value : this.streak,
      noDeliveryDays: data.noDeliveryDays.present
          ? data.noDeliveryDays.value
          : this.noDeliveryDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FriendRow(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('streak: $streak, ')
          ..write('noDeliveryDays: $noDeliveryDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, position, name, emoji, streak, noDeliveryDays);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FriendRow &&
          other.id == this.id &&
          other.position == this.position &&
          other.name == this.name &&
          other.emoji == this.emoji &&
          other.streak == this.streak &&
          other.noDeliveryDays == this.noDeliveryDays);
}

class FriendsCompanion extends UpdateCompanion<FriendRow> {
  final Value<String> id;
  final Value<int> position;
  final Value<String> name;
  final Value<String> emoji;
  final Value<int> streak;
  final Value<String> noDeliveryDays;
  final Value<int> rowid;
  const FriendsCompanion({
    this.id = const Value.absent(),
    this.position = const Value.absent(),
    this.name = const Value.absent(),
    this.emoji = const Value.absent(),
    this.streak = const Value.absent(),
    this.noDeliveryDays = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FriendsCompanion.insert({
    required String id,
    required int position,
    required String name,
    required String emoji,
    required int streak,
    required String noDeliveryDays,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       position = Value(position),
       name = Value(name),
       emoji = Value(emoji),
       streak = Value(streak),
       noDeliveryDays = Value(noDeliveryDays);
  static Insertable<FriendRow> custom({
    Expression<String>? id,
    Expression<int>? position,
    Expression<String>? name,
    Expression<String>? emoji,
    Expression<int>? streak,
    Expression<String>? noDeliveryDays,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (position != null) 'position': position,
      if (name != null) 'name': name,
      if (emoji != null) 'emoji': emoji,
      if (streak != null) 'streak': streak,
      if (noDeliveryDays != null) 'no_delivery_days': noDeliveryDays,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FriendsCompanion copyWith({
    Value<String>? id,
    Value<int>? position,
    Value<String>? name,
    Value<String>? emoji,
    Value<int>? streak,
    Value<String>? noDeliveryDays,
    Value<int>? rowid,
  }) {
    return FriendsCompanion(
      id: id ?? this.id,
      position: position ?? this.position,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      streak: streak ?? this.streak,
      noDeliveryDays: noDeliveryDays ?? this.noDeliveryDays,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (emoji.present) {
      map['emoji'] = Variable<String>(emoji.value);
    }
    if (streak.present) {
      map['streak'] = Variable<int>(streak.value);
    }
    if (noDeliveryDays.present) {
      map['no_delivery_days'] = Variable<String>(noDeliveryDays.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FriendsCompanion(')
          ..write('id: $id, ')
          ..write('position: $position, ')
          ..write('name: $name, ')
          ..write('emoji: $emoji, ')
          ..write('streak: $streak, ')
          ..write('noDeliveryDays: $noDeliveryDays, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signedInAtMeta = const VerificationMeta(
    'signedInAt',
  );
  @override
  late final GeneratedColumn<DateTime> signedInAt = GeneratedColumn<DateTime>(
    'signed_in_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, email, signedInAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    } else if (isInserting) {
      context.missing(_emailMeta);
    }
    if (data.containsKey('signed_in_at')) {
      context.handle(
        _signedInAtMeta,
        signedInAt.isAcceptableOrUnknown(
          data['signed_in_at']!,
          _signedInAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_signedInAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      )!,
      signedInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}signed_in_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final int id;
  final String name;
  final String email;
  final DateTime signedInAt;
  const SessionRow({
    required this.id,
    required this.name,
    required this.email,
    required this.signedInAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['email'] = Variable<String>(email);
    map['signed_in_at'] = Variable<DateTime>(signedInAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      name: Value(name),
      email: Value(email),
      signedInAt: Value(signedInAt),
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      email: serializer.fromJson<String>(json['email']),
      signedInAt: serializer.fromJson<DateTime>(json['signedInAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'email': serializer.toJson<String>(email),
      'signedInAt': serializer.toJson<DateTime>(signedInAt),
    };
  }

  SessionRow copyWith({
    int? id,
    String? name,
    String? email,
    DateTime? signedInAt,
  }) => SessionRow(
    id: id ?? this.id,
    name: name ?? this.name,
    email: email ?? this.email,
    signedInAt: signedInAt ?? this.signedInAt,
  );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      email: data.email.present ? data.email.value : this.email,
      signedInAt: data.signedInAt.present
          ? data.signedInAt.value
          : this.signedInAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('signedInAt: $signedInAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, email, signedInAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.email == this.email &&
          other.signedInAt == this.signedInAt);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> email;
  final Value<DateTime> signedInAt;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.email = const Value.absent(),
    this.signedInAt = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String email,
    required DateTime signedInAt,
  }) : name = Value(name),
       email = Value(email),
       signedInAt = Value(signedInAt);
  static Insertable<SessionRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? email,
    Expression<DateTime>? signedInAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (email != null) 'email': email,
      if (signedInAt != null) 'signed_in_at': signedInAt,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? email,
    Value<DateTime>? signedInAt,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      signedInAt: signedInAt ?? this.signedInAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (signedInAt.present) {
      map['signed_in_at'] = Variable<DateTime>(signedInAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('email: $email, ')
          ..write('signedInAt: $signedInAt')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetaCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$RunwayDatabase extends GeneratedDatabase {
  _$RunwayDatabase(QueryExecutor e) : super(e);
  $RunwayDatabaseManager get managers => $RunwayDatabaseManager(this);
  late final $TermsTable terms = $TermsTable(this);
  late final $CustomCategoriesTable customCategories = $CustomCategoriesTable(
    this,
  );
  late final $ExpensesTable expenses = $ExpensesTable(this);
  late final $RepeatingBillsTable repeatingBills = $RepeatingBillsTable(this);
  late final $UpcomingCostsTable upcomingCosts = $UpcomingCostsTable(this);
  late final $IncomesTable incomes = $IncomesTable(this);
  late final $BillSplitsTable billSplits = $BillSplitsTable(this);
  late final $FriendsTable friends = $FriendsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    terms,
    customCategories,
    expenses,
    repeatingBills,
    upcomingCosts,
    incomes,
    billSplits,
    friends,
    sessions,
    meta,
  ];
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$TermsTableCreateCompanionBuilder = TermsCompanion Function({
  Value<int> id,
  required String name,
  required DateTime start,
  required DateTime end,
  required int startingBalanceCents,
  Value<BudgetPeriod> period,
  Value<DateTime?> archivedAt,
});
typedef $$TermsTableUpdateCompanionBuilder = TermsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> start,
  Value<DateTime> end,
  Value<int> startingBalanceCents,
  Value<BudgetPeriod> period,
  Value<DateTime?> archivedAt,
});

final class $$TermsTableReferences
    extends BaseReferences<_$RunwayDatabase, $TermsTable, TermRow> {
  $$TermsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$ExpensesTable, List<ExpenseRow>>
  _expensesRefsTable(_$RunwayDatabase db) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'terms__id__expenses__term_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager(
      $_db,
      $_db.expenses,
    ).filter((f) => f.termId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$UpcomingCostsTable, List<UpcomingCostRow>>
  _upcomingCostsRefsTable(_$RunwayDatabase db) => MultiTypedResultKey.fromTable(
    db.upcomingCosts,
    aliasName: 'terms__id__upcoming_costs__term_id',
  );

  $$UpcomingCostsTableProcessedTableManager get upcomingCostsRefs {
    final manager = $$UpcomingCostsTableTableManager(
      $_db,
      $_db.upcomingCosts,
    ).filter((f) => f.termId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_upcomingCostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$IncomesTable, List<IncomeRow>> _incomesRefsTable(
    _$RunwayDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.incomes,
    aliasName: 'terms__id__incomes__term_id',
  );

  $$IncomesTableProcessedTableManager get incomesRefs {
    final manager = $$IncomesTableTableManager(
      $_db,
      $_db.incomes,
    ).filter((f) => f.termId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_incomesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TermsTableFilterComposer
    extends Composer<_$RunwayDatabase, $TermsTable> {
  $$TermsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startingBalanceCents => $composableBuilder(
    column: $table.startingBalanceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<BudgetPeriod, BudgetPeriod, String>
  get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.termId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> upcomingCostsRefs(
    Expression<bool> Function($$UpcomingCostsTableFilterComposer f) f,
  ) {
    final $$UpcomingCostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.upcomingCosts,
      getReferencedColumn: (t) => t.termId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UpcomingCostsTableFilterComposer(
            $db: $db,
            $table: $db.upcomingCosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> incomesRefs(
    Expression<bool> Function($$IncomesTableFilterComposer f) f,
  ) {
    final $$IncomesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.incomes,
      getReferencedColumn: (t) => t.termId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IncomesTableFilterComposer(
            $db: $db,
            $table: $db.incomes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TermsTableOrderingComposer
    extends Composer<_$RunwayDatabase, $TermsTable> {
  $$TermsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get start => $composableBuilder(
    column: $table.start,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get end => $composableBuilder(
    column: $table.end,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startingBalanceCents => $composableBuilder(
    column: $table.startingBalanceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get period => $composableBuilder(
    column: $table.period,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TermsTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $TermsTable> {
  $$TermsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get start =>
      $composableBuilder(column: $table.start, builder: (column) => column);

  GeneratedColumn<DateTime> get end =>
      $composableBuilder(column: $table.end, builder: (column) => column);

  GeneratedColumn<int> get startingBalanceCents => $composableBuilder(
    column: $table.startingBalanceCents,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<BudgetPeriod, String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.termId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> upcomingCostsRefs<T extends Object>(
    Expression<T> Function($$UpcomingCostsTableAnnotationComposer a) f,
  ) {
    final $$UpcomingCostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.upcomingCosts,
      getReferencedColumn: (t) => t.termId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UpcomingCostsTableAnnotationComposer(
            $db: $db,
            $table: $db.upcomingCosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> incomesRefs<T extends Object>(
    Expression<T> Function($$IncomesTableAnnotationComposer a) f,
  ) {
    final $$IncomesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.incomes,
      getReferencedColumn: (t) => t.termId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IncomesTableAnnotationComposer(
            $db: $db,
            $table: $db.incomes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TermsTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $TermsTable,
          TermRow,
          $$TermsTableFilterComposer,
          $$TermsTableOrderingComposer,
          $$TermsTableAnnotationComposer,
          $$TermsTableCreateCompanionBuilder,
          $$TermsTableUpdateCompanionBuilder,
          (TermRow, $$TermsTableReferences),
          TermRow,
          PrefetchHooks Function({
            bool expensesRefs,
            bool upcomingCostsRefs,
            bool incomesRefs,
          })
        > {
  $$TermsTableTableManager(_$RunwayDatabase db, $TermsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TermsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TermsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TermsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> start = const Value.absent(),
                Value<DateTime> end = const Value.absent(),
                Value<int> startingBalanceCents = const Value.absent(),
                Value<BudgetPeriod> period = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
              }) => TermsCompanion(
                id: id,
                name: name,
                start: start,
                end: end,
                startingBalanceCents: startingBalanceCents,
                period: period,
                archivedAt: archivedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime start,
                required DateTime end,
                required int startingBalanceCents,
                Value<BudgetPeriod> period = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
              }) => TermsCompanion.insert(
                id: id,
                name: name,
                start: start,
                end: end,
                startingBalanceCents: startingBalanceCents,
                period: period,
                archivedAt: archivedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TermsTable, TermRow>(table),
                  $$TermsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                expensesRefs = false,
                upcomingCostsRefs = false,
                incomesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (expensesRefs) db.expenses,
                    if (upcomingCostsRefs) db.upcomingCosts,
                    if (incomesRefs) db.incomes,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (expensesRefs)
                        await $_getPrefetchedData<
                          TermRow,
                          $TermsTable,
                          ExpenseRow
                        >(
                          currentTable: table,
                          referencedTable: $$TermsTableReferences
                              ._expensesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TermsTableReferences(
                                db,
                                table,
                                p0,
                              ).expensesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.termId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (upcomingCostsRefs)
                        await $_getPrefetchedData<
                          TermRow,
                          $TermsTable,
                          UpcomingCostRow
                        >(
                          currentTable: table,
                          referencedTable: $$TermsTableReferences
                              ._upcomingCostsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TermsTableReferences(
                                db,
                                table,
                                p0,
                              ).upcomingCostsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.termId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (incomesRefs)
                        await $_getPrefetchedData<
                          TermRow,
                          $TermsTable,
                          IncomeRow
                        >(
                          currentTable: table,
                          referencedTable: $$TermsTableReferences
                              ._incomesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TermsTableReferences(db, table, p0).incomesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.termId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TermsTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $TermsTable,
      TermRow,
      $$TermsTableFilterComposer,
      $$TermsTableOrderingComposer,
      $$TermsTableAnnotationComposer,
      $$TermsTableCreateCompanionBuilder,
      $$TermsTableUpdateCompanionBuilder,
      (TermRow, $$TermsTableReferences),
      TermRow,
      PrefetchHooks Function({
        bool expensesRefs,
        bool upcomingCostsRefs,
        bool incomesRefs,
      })
    >;
typedef $$CustomCategoriesTableCreateCompanionBuilder =
    CustomCategoriesCompanion Function({
      required String id,
      required String emoji,
      required String name,
      required DateTime createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> rowid,
    });
typedef $$CustomCategoriesTableUpdateCompanionBuilder =
    CustomCategoriesCompanion Function({
      Value<String> id,
      Value<String> emoji,
      Value<String> name,
      Value<DateTime> createdAt,
      Value<DateTime?> lastUsedAt,
      Value<int> rowid,
    });

final class $$CustomCategoriesTableReferences
    extends
        BaseReferences<
          _$RunwayDatabase,
          $CustomCategoriesTable,
          CustomCategoryRow
        > {
  $$CustomCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$ExpensesTable, List<ExpenseRow>>
  _expensesRefsTable(_$RunwayDatabase db) => MultiTypedResultKey.fromTable(
    db.expenses,
    aliasName: 'custom_categories__id__expenses__custom_category_id',
  );

  $$ExpensesTableProcessedTableManager get expensesRefs {
    final manager = $$ExpensesTableTableManager($_db, $_db.expenses).filter(
      (f) => f.customCategoryId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_expensesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CustomCategoriesTableFilterComposer
    extends Composer<_$RunwayDatabase, $CustomCategoriesTable> {
  $$CustomCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> expensesRefs(
    Expression<bool> Function($$ExpensesTableFilterComposer f) f,
  ) {
    final $$ExpensesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.customCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableFilterComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CustomCategoriesTableOrderingComposer
    extends Composer<_$RunwayDatabase, $CustomCategoriesTable> {
  $$CustomCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CustomCategoriesTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $CustomCategoriesTable> {
  $$CustomCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  Expression<T> expensesRefs<T extends Object>(
    Expression<T> Function($$ExpensesTableAnnotationComposer a) f,
  ) {
    final $$ExpensesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.expenses,
      getReferencedColumn: (t) => t.customCategoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ExpensesTableAnnotationComposer(
            $db: $db,
            $table: $db.expenses,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CustomCategoriesTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $CustomCategoriesTable,
          CustomCategoryRow,
          $$CustomCategoriesTableFilterComposer,
          $$CustomCategoriesTableOrderingComposer,
          $$CustomCategoriesTableAnnotationComposer,
          $$CustomCategoriesTableCreateCompanionBuilder,
          $$CustomCategoriesTableUpdateCompanionBuilder,
          (CustomCategoryRow, $$CustomCategoriesTableReferences),
          CustomCategoryRow,
          PrefetchHooks Function({bool expensesRefs})
        > {
  $$CustomCategoriesTableTableManager(
    _$RunwayDatabase db,
    $CustomCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CustomCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CustomCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CustomCategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomCategoriesCompanion(
                id: id,
                emoji: emoji,
                name: name,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String emoji,
                required String name,
                required DateTime createdAt,
                Value<DateTime?> lastUsedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CustomCategoriesCompanion.insert(
                id: id,
                emoji: emoji,
                name: name,
                createdAt: createdAt,
                lastUsedAt: lastUsedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CustomCategoriesTable, CustomCategoryRow>(table),
                  $$CustomCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({expensesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (expensesRefs) db.expenses],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (expensesRefs)
                    await $_getPrefetchedData<
                      CustomCategoryRow,
                      $CustomCategoriesTable,
                      ExpenseRow
                    >(
                      currentTable: table,
                      referencedTable: $$CustomCategoriesTableReferences
                          ._expensesRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$CustomCategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).expensesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.customCategoryId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$CustomCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $CustomCategoriesTable,
      CustomCategoryRow,
      $$CustomCategoriesTableFilterComposer,
      $$CustomCategoriesTableOrderingComposer,
      $$CustomCategoriesTableAnnotationComposer,
      $$CustomCategoriesTableCreateCompanionBuilder,
      $$CustomCategoriesTableUpdateCompanionBuilder,
      (CustomCategoryRow, $$CustomCategoriesTableReferences),
      CustomCategoryRow,
      PrefetchHooks Function({bool expensesRefs})
    >;
typedef $$ExpensesTableCreateCompanionBuilder = ExpensesCompanion Function({
  required String id,
  required int termId,
  required int amountCents,
  required ExpenseCategory category,
  required bool isNeed,
  Value<String?> note,
  required DateTime createdAt,
  Value<bool> isPlanned,
  Value<DateTime?> deletedAt,
  Value<String?> customCategoryId,
  Value<int> rowid,
});
typedef $$ExpensesTableUpdateCompanionBuilder = ExpensesCompanion Function({
  Value<String> id,
  Value<int> termId,
  Value<int> amountCents,
  Value<ExpenseCategory> category,
  Value<bool> isNeed,
  Value<String?> note,
  Value<DateTime> createdAt,
  Value<bool> isPlanned,
  Value<DateTime?> deletedAt,
  Value<String?> customCategoryId,
  Value<int> rowid,
});

final class $$ExpensesTableReferences
    extends BaseReferences<_$RunwayDatabase, $ExpensesTable, ExpenseRow> {
  $$ExpensesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TermsTable _termIdTable(_$RunwayDatabase db) =>
      db.terms.createAlias('expenses__term_id__terms__id');

  $$TermsTableProcessedTableManager get termId {
    final $_column = $_itemColumn<int>('term_id')!;

    final manager = $$TermsTableTableManager(
      $_db,
      $_db.terms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_termIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CustomCategoriesTable _customCategoryIdTable(_$RunwayDatabase db) =>
      db.customCategories.createAlias(
        'expenses__custom_category_id__custom_categories__id',
      );

  $$CustomCategoriesTableProcessedTableManager? get customCategoryId {
    final $_column = $_itemColumn<String>('custom_category_id');
    if ($_column == null) return null;
    final manager = $$CustomCategoriesTableTableManager(
      $_db,
      $_db.customCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customCategoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ExpensesTableFilterComposer
    extends Composer<_$RunwayDatabase, $ExpensesTable> {
  $$ExpensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ExpenseCategory, ExpenseCategory, String>
  get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get isNeed => $composableBuilder(
    column: $table.isNeed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isPlanned => $composableBuilder(
    column: $table.isPlanned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TermsTableFilterComposer get termId {
    final $$TermsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableFilterComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomCategoriesTableFilterComposer get customCategoryId {
    final $$CustomCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customCategoryId,
      referencedTable: $db.customCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.customCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableOrderingComposer
    extends Composer<_$RunwayDatabase, $ExpensesTable> {
  $$ExpensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isNeed => $composableBuilder(
    column: $table.isNeed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isPlanned => $composableBuilder(
    column: $table.isPlanned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TermsTableOrderingComposer get termId {
    final $$TermsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableOrderingComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomCategoriesTableOrderingComposer get customCategoryId {
    final $$CustomCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customCategoryId,
      referencedTable: $db.customCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.customCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $ExpensesTable> {
  $$ExpensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ExpenseCategory, String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get isNeed =>
      $composableBuilder(column: $table.isNeed, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isPlanned =>
      $composableBuilder(column: $table.isPlanned, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$TermsTableAnnotationComposer get termId {
    final $$TermsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableAnnotationComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CustomCategoriesTableAnnotationComposer get customCategoryId {
    final $$CustomCategoriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customCategoryId,
      referencedTable: $db.customCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CustomCategoriesTableAnnotationComposer(
            $db: $db,
            $table: $db.customCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ExpensesTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $ExpensesTable,
          ExpenseRow,
          $$ExpensesTableFilterComposer,
          $$ExpensesTableOrderingComposer,
          $$ExpensesTableAnnotationComposer,
          $$ExpensesTableCreateCompanionBuilder,
          $$ExpensesTableUpdateCompanionBuilder,
          (ExpenseRow, $$ExpensesTableReferences),
          ExpenseRow,
          PrefetchHooks Function({bool termId, bool customCategoryId})
        > {
  $$ExpensesTableTableManager(_$RunwayDatabase db, $ExpensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExpensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExpensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExpensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> termId = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<ExpenseCategory> category = const Value.absent(),
                Value<bool> isNeed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isPlanned = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> customCategoryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion(
                id: id,
                termId: termId,
                amountCents: amountCents,
                category: category,
                isNeed: isNeed,
                note: note,
                createdAt: createdAt,
                isPlanned: isPlanned,
                deletedAt: deletedAt,
                customCategoryId: customCategoryId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int termId,
                required int amountCents,
                required ExpenseCategory category,
                required bool isNeed,
                Value<String?> note = const Value.absent(),
                required DateTime createdAt,
                Value<bool> isPlanned = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> customCategoryId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExpensesCompanion.insert(
                id: id,
                termId: termId,
                amountCents: amountCents,
                category: category,
                isNeed: isNeed,
                note: note,
                createdAt: createdAt,
                isPlanned: isPlanned,
                deletedAt: deletedAt,
                customCategoryId: customCategoryId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ExpensesTable, ExpenseRow>(table),
                  $$ExpensesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({termId = false, customCategoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (termId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.termId,
                        referencedTable: $$ExpensesTableReferences._termIdTable(
                          db,
                        ),
                        referencedColumn: $$ExpensesTableReferences
                            ._termIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (customCategoryId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.customCategoryId,
                        referencedTable: $$ExpensesTableReferences
                            ._customCategoryIdTable(db),
                        referencedColumn: $$ExpensesTableReferences
                            ._customCategoryIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ExpensesTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $ExpensesTable,
      ExpenseRow,
      $$ExpensesTableFilterComposer,
      $$ExpensesTableOrderingComposer,
      $$ExpensesTableAnnotationComposer,
      $$ExpensesTableCreateCompanionBuilder,
      $$ExpensesTableUpdateCompanionBuilder,
      (ExpenseRow, $$ExpensesTableReferences),
      ExpenseRow,
      PrefetchHooks Function({bool termId, bool customCategoryId})
    >;
typedef $$RepeatingBillsTableCreateCompanionBuilder =
    RepeatingBillsCompanion Function({
      required String id,
      required String emoji,
      required String name,
      required int amountCents,
      required DateTime firstDue,
      required DateTime createdAt,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });
typedef $$RepeatingBillsTableUpdateCompanionBuilder =
    RepeatingBillsCompanion Function({
      Value<String> id,
      Value<String> emoji,
      Value<String> name,
      Value<int> amountCents,
      Value<DateTime> firstDue,
      Value<DateTime> createdAt,
      Value<DateTime?> endedAt,
      Value<int> rowid,
    });

final class $$RepeatingBillsTableReferences
    extends
        BaseReferences<
          _$RunwayDatabase,
          $RepeatingBillsTable,
          RepeatingBillRow
        > {
  $$RepeatingBillsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$UpcomingCostsTable, List<UpcomingCostRow>>
  _upcomingCostsRefsTable(_$RunwayDatabase db) => MultiTypedResultKey.fromTable(
    db.upcomingCosts,
    aliasName: 'repeating_bills__id__upcoming_costs__bill_id',
  );

  $$UpcomingCostsTableProcessedTableManager get upcomingCostsRefs {
    final manager = $$UpcomingCostsTableTableManager(
      $_db,
      $_db.upcomingCosts,
    ).filter((f) => f.billId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_upcomingCostsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RepeatingBillsTableFilterComposer
    extends Composer<_$RunwayDatabase, $RepeatingBillsTable> {
  $$RepeatingBillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get firstDue => $composableBuilder(
    column: $table.firstDue,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> upcomingCostsRefs(
    Expression<bool> Function($$UpcomingCostsTableFilterComposer f) f,
  ) {
    final $$UpcomingCostsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.upcomingCosts,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UpcomingCostsTableFilterComposer(
            $db: $db,
            $table: $db.upcomingCosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepeatingBillsTableOrderingComposer
    extends Composer<_$RunwayDatabase, $RepeatingBillsTable> {
  $$RepeatingBillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstDue => $composableBuilder(
    column: $table.firstDue,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RepeatingBillsTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $RepeatingBillsTable> {
  $$RepeatingBillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get firstDue =>
      $composableBuilder(column: $table.firstDue, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  Expression<T> upcomingCostsRefs<T extends Object>(
    Expression<T> Function($$UpcomingCostsTableAnnotationComposer a) f,
  ) {
    final $$UpcomingCostsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.upcomingCosts,
      getReferencedColumn: (t) => t.billId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UpcomingCostsTableAnnotationComposer(
            $db: $db,
            $table: $db.upcomingCosts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RepeatingBillsTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $RepeatingBillsTable,
          RepeatingBillRow,
          $$RepeatingBillsTableFilterComposer,
          $$RepeatingBillsTableOrderingComposer,
          $$RepeatingBillsTableAnnotationComposer,
          $$RepeatingBillsTableCreateCompanionBuilder,
          $$RepeatingBillsTableUpdateCompanionBuilder,
          (RepeatingBillRow, $$RepeatingBillsTableReferences),
          RepeatingBillRow,
          PrefetchHooks Function({bool upcomingCostsRefs})
        > {
  $$RepeatingBillsTableTableManager(
    _$RunwayDatabase db,
    $RepeatingBillsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RepeatingBillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RepeatingBillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RepeatingBillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> firstDue = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepeatingBillsCompanion(
                id: id,
                emoji: emoji,
                name: name,
                amountCents: amountCents,
                firstDue: firstDue,
                createdAt: createdAt,
                endedAt: endedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String emoji,
                required String name,
                required int amountCents,
                required DateTime firstDue,
                required DateTime createdAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RepeatingBillsCompanion.insert(
                id: id,
                emoji: emoji,
                name: name,
                amountCents: amountCents,
                firstDue: firstDue,
                createdAt: createdAt,
                endedAt: endedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RepeatingBillsTable, RepeatingBillRow>(table),
                  $$RepeatingBillsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({upcomingCostsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (upcomingCostsRefs) db.upcomingCosts,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (upcomingCostsRefs)
                    await $_getPrefetchedData<
                      RepeatingBillRow,
                      $RepeatingBillsTable,
                      UpcomingCostRow
                    >(
                      currentTable: table,
                      referencedTable: $$RepeatingBillsTableReferences
                          ._upcomingCostsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$RepeatingBillsTableReferences(
                            db,
                            table,
                            p0,
                          ).upcomingCostsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.billId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$RepeatingBillsTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $RepeatingBillsTable,
      RepeatingBillRow,
      $$RepeatingBillsTableFilterComposer,
      $$RepeatingBillsTableOrderingComposer,
      $$RepeatingBillsTableAnnotationComposer,
      $$RepeatingBillsTableCreateCompanionBuilder,
      $$RepeatingBillsTableUpdateCompanionBuilder,
      (RepeatingBillRow, $$RepeatingBillsTableReferences),
      RepeatingBillRow,
      PrefetchHooks Function({bool upcomingCostsRefs})
    >;
typedef $$UpcomingCostsTableCreateCompanionBuilder =
    UpcomingCostsCompanion Function({
      required String id,
      required int termId,
      required String emoji,
      required String name,
      required int amountCents,
      required DateTime dueDate,
      Value<DateTime?> paidAt,
      Value<String?> billId,
      Value<int> rowid,
    });
typedef $$UpcomingCostsTableUpdateCompanionBuilder =
    UpcomingCostsCompanion Function({
      Value<String> id,
      Value<int> termId,
      Value<String> emoji,
      Value<String> name,
      Value<int> amountCents,
      Value<DateTime> dueDate,
      Value<DateTime?> paidAt,
      Value<String?> billId,
      Value<int> rowid,
    });

final class $$UpcomingCostsTableReferences
    extends
        BaseReferences<_$RunwayDatabase, $UpcomingCostsTable, UpcomingCostRow> {
  $$UpcomingCostsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TermsTable _termIdTable(_$RunwayDatabase db) =>
      db.terms.createAlias('upcoming_costs__term_id__terms__id');

  $$TermsTableProcessedTableManager get termId {
    final $_column = $_itemColumn<int>('term_id')!;

    final manager = $$TermsTableTableManager(
      $_db,
      $_db.terms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_termIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $RepeatingBillsTable _billIdTable(_$RunwayDatabase db) => db
      .repeatingBills
      .createAlias('upcoming_costs__bill_id__repeating_bills__id');

  $$RepeatingBillsTableProcessedTableManager? get billId {
    final $_column = $_itemColumn<String>('bill_id');
    if ($_column == null) return null;
    final manager = $$RepeatingBillsTableTableManager(
      $_db,
      $_db.repeatingBills,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_billIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$UpcomingCostsTableFilterComposer
    extends Composer<_$RunwayDatabase, $UpcomingCostsTable> {
  $$UpcomingCostsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TermsTableFilterComposer get termId {
    final $$TermsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableFilterComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepeatingBillsTableFilterComposer get billId {
    final $$RepeatingBillsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.repeatingBills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepeatingBillsTableFilterComposer(
            $db: $db,
            $table: $db.repeatingBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UpcomingCostsTableOrderingComposer
    extends Composer<_$RunwayDatabase, $UpcomingCostsTable> {
  $$UpcomingCostsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paidAt => $composableBuilder(
    column: $table.paidAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TermsTableOrderingComposer get termId {
    final $$TermsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableOrderingComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepeatingBillsTableOrderingComposer get billId {
    final $$RepeatingBillsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.repeatingBills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepeatingBillsTableOrderingComposer(
            $db: $db,
            $table: $db.repeatingBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UpcomingCostsTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $UpcomingCostsTable> {
  $$UpcomingCostsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<DateTime> get paidAt =>
      $composableBuilder(column: $table.paidAt, builder: (column) => column);

  $$TermsTableAnnotationComposer get termId {
    final $$TermsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableAnnotationComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$RepeatingBillsTableAnnotationComposer get billId {
    final $$RepeatingBillsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.billId,
      referencedTable: $db.repeatingBills,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RepeatingBillsTableAnnotationComposer(
            $db: $db,
            $table: $db.repeatingBills,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$UpcomingCostsTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $UpcomingCostsTable,
          UpcomingCostRow,
          $$UpcomingCostsTableFilterComposer,
          $$UpcomingCostsTableOrderingComposer,
          $$UpcomingCostsTableAnnotationComposer,
          $$UpcomingCostsTableCreateCompanionBuilder,
          $$UpcomingCostsTableUpdateCompanionBuilder,
          (UpcomingCostRow, $$UpcomingCostsTableReferences),
          UpcomingCostRow,
          PrefetchHooks Function({bool termId, bool billId})
        > {
  $$UpcomingCostsTableTableManager(
    _$RunwayDatabase db,
    $UpcomingCostsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UpcomingCostsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UpcomingCostsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UpcomingCostsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> termId = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<DateTime?> paidAt = const Value.absent(),
                Value<String?> billId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UpcomingCostsCompanion(
                id: id,
                termId: termId,
                emoji: emoji,
                name: name,
                amountCents: amountCents,
                dueDate: dueDate,
                paidAt: paidAt,
                billId: billId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int termId,
                required String emoji,
                required String name,
                required int amountCents,
                required DateTime dueDate,
                Value<DateTime?> paidAt = const Value.absent(),
                Value<String?> billId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UpcomingCostsCompanion.insert(
                id: id,
                termId: termId,
                emoji: emoji,
                name: name,
                amountCents: amountCents,
                dueDate: dueDate,
                paidAt: paidAt,
                billId: billId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UpcomingCostsTable, UpcomingCostRow>(table),
                  $$UpcomingCostsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({termId = false, billId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (termId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.termId,
                        referencedTable: $$UpcomingCostsTableReferences
                            ._termIdTable(db),
                        referencedColumn: $$UpcomingCostsTableReferences
                            ._termIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (billId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.billId,
                        referencedTable: $$UpcomingCostsTableReferences
                            ._billIdTable(db),
                        referencedColumn: $$UpcomingCostsTableReferences
                            ._billIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$UpcomingCostsTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $UpcomingCostsTable,
      UpcomingCostRow,
      $$UpcomingCostsTableFilterComposer,
      $$UpcomingCostsTableOrderingComposer,
      $$UpcomingCostsTableAnnotationComposer,
      $$UpcomingCostsTableCreateCompanionBuilder,
      $$UpcomingCostsTableUpdateCompanionBuilder,
      (UpcomingCostRow, $$UpcomingCostsTableReferences),
      UpcomingCostRow,
      PrefetchHooks Function({bool termId, bool billId})
    >;
typedef $$IncomesTableCreateCompanionBuilder = IncomesCompanion Function({
  required String id,
  required int termId,
  required String name,
  required int amountCents,
  required IncomeFrequency frequency,
  required DateTime firstDate,
  Value<DateTime?> endsOn,
  required DateTime createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$IncomesTableUpdateCompanionBuilder = IncomesCompanion Function({
  Value<String> id,
  Value<int> termId,
  Value<String> name,
  Value<int> amountCents,
  Value<IncomeFrequency> frequency,
  Value<DateTime> firstDate,
  Value<DateTime?> endsOn,
  Value<DateTime> createdAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

final class $$IncomesTableReferences
    extends BaseReferences<_$RunwayDatabase, $IncomesTable, IncomeRow> {
  $$IncomesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TermsTable _termIdTable(_$RunwayDatabase db) =>
      db.terms.createAlias('incomes__term_id__terms__id');

  $$TermsTableProcessedTableManager get termId {
    final $_column = $_itemColumn<int>('term_id')!;

    final manager = $$TermsTableTableManager(
      $_db,
      $_db.terms,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_termIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$IncomesTableFilterComposer
    extends Composer<_$RunwayDatabase, $IncomesTable> {
  $$IncomesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<IncomeFrequency, IncomeFrequency, String>
  get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get firstDate => $composableBuilder(
    column: $table.firstDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endsOn => $composableBuilder(
    column: $table.endsOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TermsTableFilterComposer get termId {
    final $$TermsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableFilterComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncomesTableOrderingComposer
    extends Composer<_$RunwayDatabase, $IncomesTable> {
  $$IncomesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get frequency => $composableBuilder(
    column: $table.frequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get firstDate => $composableBuilder(
    column: $table.firstDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endsOn => $composableBuilder(
    column: $table.endsOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TermsTableOrderingComposer get termId {
    final $$TermsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableOrderingComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncomesTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $IncomesTable> {
  $$IncomesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<IncomeFrequency, String> get frequency =>
      $composableBuilder(column: $table.frequency, builder: (column) => column);

  GeneratedColumn<DateTime> get firstDate =>
      $composableBuilder(column: $table.firstDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endsOn =>
      $composableBuilder(column: $table.endsOn, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$TermsTableAnnotationComposer get termId {
    final $$TermsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.termId,
      referencedTable: $db.terms,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TermsTableAnnotationComposer(
            $db: $db,
            $table: $db.terms,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IncomesTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $IncomesTable,
          IncomeRow,
          $$IncomesTableFilterComposer,
          $$IncomesTableOrderingComposer,
          $$IncomesTableAnnotationComposer,
          $$IncomesTableCreateCompanionBuilder,
          $$IncomesTableUpdateCompanionBuilder,
          (IncomeRow, $$IncomesTableReferences),
          IncomeRow,
          PrefetchHooks Function({bool termId})
        > {
  $$IncomesTableTableManager(_$RunwayDatabase db, $IncomesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IncomesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IncomesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IncomesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> termId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<IncomeFrequency> frequency = const Value.absent(),
                Value<DateTime> firstDate = const Value.absent(),
                Value<DateTime?> endsOn = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IncomesCompanion(
                id: id,
                termId: termId,
                name: name,
                amountCents: amountCents,
                frequency: frequency,
                firstDate: firstDate,
                endsOn: endsOn,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int termId,
                required String name,
                required int amountCents,
                required IncomeFrequency frequency,
                required DateTime firstDate,
                Value<DateTime?> endsOn = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IncomesCompanion.insert(
                id: id,
                termId: termId,
                name: name,
                amountCents: amountCents,
                frequency: frequency,
                firstDate: firstDate,
                endsOn: endsOn,
                createdAt: createdAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$IncomesTable, IncomeRow>(table),
                  $$IncomesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({termId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (termId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.termId,
                        referencedTable: $$IncomesTableReferences._termIdTable(
                          db,
                        ),
                        referencedColumn: $$IncomesTableReferences
                            ._termIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$IncomesTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $IncomesTable,
      IncomeRow,
      $$IncomesTableFilterComposer,
      $$IncomesTableOrderingComposer,
      $$IncomesTableAnnotationComposer,
      $$IncomesTableCreateCompanionBuilder,
      $$IncomesTableUpdateCompanionBuilder,
      (IncomeRow, $$IncomesTableReferences),
      IncomeRow,
      PrefetchHooks Function({bool termId})
    >;
typedef $$BillSplitsTableCreateCompanionBuilder = BillSplitsCompanion Function({
  required String id,
  required String person,
  required int amountCents,
  required String note,
  required bool theyOweYou,
  required DateTime createdAt,
  Value<DateTime?> settledAt,
  Value<int> rowid,
});
typedef $$BillSplitsTableUpdateCompanionBuilder = BillSplitsCompanion Function({
  Value<String> id,
  Value<String> person,
  Value<int> amountCents,
  Value<String> note,
  Value<bool> theyOweYou,
  Value<DateTime> createdAt,
  Value<DateTime?> settledAt,
  Value<int> rowid,
});

class $$BillSplitsTableFilterComposer
    extends Composer<_$RunwayDatabase, $BillSplitsTable> {
  $$BillSplitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get theyOweYou => $composableBuilder(
    column: $table.theyOweYou,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BillSplitsTableOrderingComposer
    extends Composer<_$RunwayDatabase, $BillSplitsTable> {
  $$BillSplitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get person => $composableBuilder(
    column: $table.person,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get theyOweYou => $composableBuilder(
    column: $table.theyOweYou,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get settledAt => $composableBuilder(
    column: $table.settledAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BillSplitsTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $BillSplitsTable> {
  $$BillSplitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get person =>
      $composableBuilder(column: $table.person, builder: (column) => column);

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get theyOweYou => $composableBuilder(
    column: $table.theyOweYou,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get settledAt =>
      $composableBuilder(column: $table.settledAt, builder: (column) => column);
}

class $$BillSplitsTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $BillSplitsTable,
          BillSplitRow,
          $$BillSplitsTableFilterComposer,
          $$BillSplitsTableOrderingComposer,
          $$BillSplitsTableAnnotationComposer,
          $$BillSplitsTableCreateCompanionBuilder,
          $$BillSplitsTableUpdateCompanionBuilder,
          (
            BillSplitRow,
            BaseReferences<_$RunwayDatabase, $BillSplitsTable, BillSplitRow>,
          ),
          BillSplitRow,
          PrefetchHooks Function()
        > {
  $$BillSplitsTableTableManager(_$RunwayDatabase db, $BillSplitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BillSplitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BillSplitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BillSplitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> person = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<bool> theyOweYou = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> settledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillSplitsCompanion(
                id: id,
                person: person,
                amountCents: amountCents,
                note: note,
                theyOweYou: theyOweYou,
                createdAt: createdAt,
                settledAt: settledAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String person,
                required int amountCents,
                required String note,
                required bool theyOweYou,
                required DateTime createdAt,
                Value<DateTime?> settledAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BillSplitsCompanion.insert(
                id: id,
                person: person,
                amountCents: amountCents,
                note: note,
                theyOweYou: theyOweYou,
                createdAt: createdAt,
                settledAt: settledAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BillSplitsTable, BillSplitRow>(table),
                  BaseReferences<
                    _$RunwayDatabase,
                    $BillSplitsTable,
                    BillSplitRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BillSplitsTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $BillSplitsTable,
      BillSplitRow,
      $$BillSplitsTableFilterComposer,
      $$BillSplitsTableOrderingComposer,
      $$BillSplitsTableAnnotationComposer,
      $$BillSplitsTableCreateCompanionBuilder,
      $$BillSplitsTableUpdateCompanionBuilder,
      (
        BillSplitRow,
        BaseReferences<_$RunwayDatabase, $BillSplitsTable, BillSplitRow>,
      ),
      BillSplitRow,
      PrefetchHooks Function()
    >;
typedef $$FriendsTableCreateCompanionBuilder = FriendsCompanion Function({
  required String id,
  required int position,
  required String name,
  required String emoji,
  required int streak,
  required String noDeliveryDays,
  Value<int> rowid,
});
typedef $$FriendsTableUpdateCompanionBuilder = FriendsCompanion Function({
  Value<String> id,
  Value<int> position,
  Value<String> name,
  Value<String> emoji,
  Value<int> streak,
  Value<String> noDeliveryDays,
  Value<int> rowid,
});

class $$FriendsTableFilterComposer
    extends Composer<_$RunwayDatabase, $FriendsTable> {
  $$FriendsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get noDeliveryDays => $composableBuilder(
    column: $table.noDeliveryDays,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FriendsTableOrderingComposer
    extends Composer<_$RunwayDatabase, $FriendsTable> {
  $$FriendsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get emoji => $composableBuilder(
    column: $table.emoji,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streak => $composableBuilder(
    column: $table.streak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get noDeliveryDays => $composableBuilder(
    column: $table.noDeliveryDays,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FriendsTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $FriendsTable> {
  $$FriendsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get emoji =>
      $composableBuilder(column: $table.emoji, builder: (column) => column);

  GeneratedColumn<int> get streak =>
      $composableBuilder(column: $table.streak, builder: (column) => column);

  GeneratedColumn<String> get noDeliveryDays => $composableBuilder(
    column: $table.noDeliveryDays,
    builder: (column) => column,
  );
}

class $$FriendsTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $FriendsTable,
          FriendRow,
          $$FriendsTableFilterComposer,
          $$FriendsTableOrderingComposer,
          $$FriendsTableAnnotationComposer,
          $$FriendsTableCreateCompanionBuilder,
          $$FriendsTableUpdateCompanionBuilder,
          (
            FriendRow,
            BaseReferences<_$RunwayDatabase, $FriendsTable, FriendRow>,
          ),
          FriendRow,
          PrefetchHooks Function()
        > {
  $$FriendsTableTableManager(_$RunwayDatabase db, $FriendsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FriendsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FriendsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FriendsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> emoji = const Value.absent(),
                Value<int> streak = const Value.absent(),
                Value<String> noDeliveryDays = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FriendsCompanion(
                id: id,
                position: position,
                name: name,
                emoji: emoji,
                streak: streak,
                noDeliveryDays: noDeliveryDays,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int position,
                required String name,
                required String emoji,
                required int streak,
                required String noDeliveryDays,
                Value<int> rowid = const Value.absent(),
              }) => FriendsCompanion.insert(
                id: id,
                position: position,
                name: name,
                emoji: emoji,
                streak: streak,
                noDeliveryDays: noDeliveryDays,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FriendsTable, FriendRow>(table),
                  BaseReferences<_$RunwayDatabase, $FriendsTable, FriendRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FriendsTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $FriendsTable,
      FriendRow,
      $$FriendsTableFilterComposer,
      $$FriendsTableOrderingComposer,
      $$FriendsTableAnnotationComposer,
      $$FriendsTableCreateCompanionBuilder,
      $$FriendsTableUpdateCompanionBuilder,
      (FriendRow, BaseReferences<_$RunwayDatabase, $FriendsTable, FriendRow>),
      FriendRow,
      PrefetchHooks Function()
    >;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  required String name,
  required String email,
  required DateTime signedInAt,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String> email,
  Value<DateTime> signedInAt,
});

class $$SessionsTableFilterComposer
    extends Composer<_$RunwayDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get signedInAt => $composableBuilder(
    column: $table.signedInAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionsTableOrderingComposer
    extends Composer<_$RunwayDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get signedInAt => $composableBuilder(
    column: $table.signedInAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<DateTime> get signedInAt => $composableBuilder(
    column: $table.signedInAt,
    builder: (column) => column,
  );
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $SessionsTable,
          SessionRow,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (
            SessionRow,
            BaseReferences<_$RunwayDatabase, $SessionsTable, SessionRow>,
          ),
          SessionRow,
          PrefetchHooks Function()
        > {
  $$SessionsTableTableManager(_$RunwayDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> email = const Value.absent(),
                Value<DateTime> signedInAt = const Value.absent(),
              }) => SessionsCompanion(
                id: id,
                name: name,
                email: email,
                signedInAt: signedInAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String email,
                required DateTime signedInAt,
              }) => SessionsCompanion.insert(
                id: id,
                name: name,
                email: email,
                signedInAt: signedInAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionsTable, SessionRow>(table),
                  BaseReferences<_$RunwayDatabase, $SessionsTable, SessionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $SessionsTable,
      SessionRow,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (
        SessionRow,
        BaseReferences<_$RunwayDatabase, $SessionsTable, SessionRow>,
      ),
      SessionRow,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder = MetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaTableUpdateCompanionBuilder = MetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaTableFilterComposer extends Composer<_$RunwayDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer
    extends Composer<_$RunwayDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$RunwayDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$RunwayDatabase,
          $MetaTable,
          MetaRow,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$RunwayDatabase, $MetaTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$RunwayDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaTable, MetaRow>(table),
                  BaseReferences<_$RunwayDatabase, $MetaTable, MetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$RunwayDatabase,
      $MetaTable,
      MetaRow,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$RunwayDatabase, $MetaTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;

class $RunwayDatabaseManager {
  final _$RunwayDatabase _db;
  $RunwayDatabaseManager(this._db);
  $$TermsTableTableManager get terms =>
      $$TermsTableTableManager(_db, _db.terms);
  $$CustomCategoriesTableTableManager get customCategories =>
      $$CustomCategoriesTableTableManager(_db, _db.customCategories);
  $$ExpensesTableTableManager get expenses =>
      $$ExpensesTableTableManager(_db, _db.expenses);
  $$RepeatingBillsTableTableManager get repeatingBills =>
      $$RepeatingBillsTableTableManager(_db, _db.repeatingBills);
  $$UpcomingCostsTableTableManager get upcomingCosts =>
      $$UpcomingCostsTableTableManager(_db, _db.upcomingCosts);
  $$IncomesTableTableManager get incomes =>
      $$IncomesTableTableManager(_db, _db.incomes);
  $$BillSplitsTableTableManager get billSplits =>
      $$BillSplitsTableTableManager(_db, _db.billSplits);
  $$FriendsTableTableManager get friends =>
      $$FriendsTableTableManager(_db, _db.friends);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
}
