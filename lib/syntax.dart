import './helpers.dart';

class TypeDefinition {
  String type;
  String subtype;
  bool _isPrimitive = false;

  factory TypeDefinition.fromDynamic(dynamic obj) {
    final type = getTypeName(obj);
    if (type == 'List') {
      List<dynamic> list = obj;
      String firstElementType;
      if (list.length > 0) {
        firstElementType = getTypeName(list[0]);
      } else {
        // when array is empty insert Null just to warn the user
        firstElementType = "Null";
      }
      return TypeDefinition(type, subtype: firstElementType);
    }
    return TypeDefinition(type);
  }

  TypeDefinition(this.type, {this.subtype}) {
    if (subtype == null) {
      _isPrimitive = isPrimitiveType(this.type) as bool;
    } else {
      _isPrimitive = isPrimitiveType('$type<$subtype>') as bool;
    }
  }

  bool get isPrimitive => _isPrimitive;

  bool get isPrimitiveList => _isPrimitive && type == 'List';

  operator ==(dynamic other) {
    if (other is TypeDefinition) {
      return type == other.type && subtype == other.subtype;
    }
    return false;
  }

  String _buildParseClass(String expression) {
    final properType = subtype != null ? subtype : type;
    return ' $properType.fromJson($expression)';
  }

  String _buildToJsonClass(String expression) {
    return '$expression.toJson()';
  }

  String jsonParseExpression(String key, bool privateField) {
    final jsonKey = "json['$key']";
    final fieldKey =
        fixFieldName(key, typeDef: this, privateField: privateField);
    if (isPrimitive) {
      if (type == "List") {
        return "bean.$fieldKey = json['$key'].cast<$subtype>();";
      }
      // return "bean.$fieldKey = json['$key']/* as $type */;";
      return "bean.$fieldKey = json['$key'];";
    } else if (type == 'List') {
      // list of class
      return "if (json['$key'] != null) { bean.$fieldKey = <$subtype>[for (final item in json['$key']) $subtype.fromJson(item)]; }";
    } else {
      // class
      return "bean.$fieldKey = json['$key'] != null ? ${_buildParseClass(jsonKey)} : null;";
    }
  }

  String toJsonExpression(String key, bool privateField) {
    final fieldKey = fixFieldName(
      key,
      typeDef: this,
      privateField: privateField,
    );
    final thisKey = 'this.$fieldKey';
    if (isPrimitive) {
      return "data['$key'] = $thisKey;";
    } else if (type == 'List') {
      // class list
      return """if ($thisKey != null) {
      data['$key'] = $thisKey.map((v) => ${_buildToJsonClass('v')}).toList();
    }""";
    } else {
      // class
      return "if ($thisKey != null) { data['$key'] = ${_buildToJsonClass(thisKey)}; }";
    }
  }
}

class Dependency {
  String name;
  final TypeDefinition typeDef;

  Dependency(this.name, this.typeDef);

  String get className => camelCase(name);
}

class ClassDefinition {
  final String _name;
  final bool _privateFields;
  final bool _needConstructor;
  final Map<String, TypeDefinition> fields = Map<String, TypeDefinition>();

  String get name => _name;
  bool get privateFields => _privateFields;
  bool get needConstructor => _needConstructor;

  List<Dependency> get dependencies {
    final dependenciesList = List<Dependency>();
    final keys = fields.keys;
    keys.forEach((k) {
      if (!fields[k].isPrimitive) {
        dependenciesList.add(Dependency(k, fields[k]));
      }
    });
    return dependenciesList;
  }

  ClassDefinition(
    this._name, [
    this._privateFields = false,
    this._needConstructor = false,
  ]);

  hasField(TypeDefinition otherField) {
    return fields.keys.firstWhere(
          (k) => fields[k] == otherField,
          orElse: () => null,
        ) !=
        null;
  }

  addField(String name, TypeDefinition typeDef) {
    fields[name] = typeDef;
  }

  operator ==(dynamic other) {
    if (other is ClassDefinition) {
      if (name != other.name) {
        return false;
      }
      return fields.keys.firstWhere(
              (k) =>
                  other.fields.keys.firstWhere(
                      (ok) => fields[k] == other.fields[ok],
                      orElse: () => null) ==
                  null,
              orElse: () => null) ==
          null;
    }
    return false;
  }

  void _addTypeDef(TypeDefinition typeDef, StringBuffer sb) {
    sb.write('${typeDef.type}');
    if (typeDef.subtype != null) {
      sb.write('<${typeDef.subtype}>');
    }
  }

  String get _fieldList {
    return fields.keys.map((key) {
      final f = fields[key];
      final fieldName =
          fixFieldName(key, typeDef: f, privateField: privateFields);
      final sb = StringBuffer();
      _addTypeDef(f, sb);
      sb.write(' $fieldName;');
      return sb.toString();
    }).join('');
  }

  String get _getters {
    return fields.keys.map((key) {
      final f = fields[key];
      final publicFieldName =
          fixFieldName(key, typeDef: f, privateField: false);
      final privateFieldName =
          fixFieldName(key, typeDef: f, privateField: true);
      final sb = StringBuffer();
      sb.write('');
      _addTypeDef(f, sb);
      sb.write(' get $publicFieldName => $privateFieldName;\n\n');
      return sb.toString();
    }).join('');
  }

  String get _gettersSetters {
    return fields.keys.map((key) {
      final f = fields[key];
      final publicFieldName =
          fixFieldName(key, typeDef: f, privateField: false);
      final privateFieldName =
          fixFieldName(key, typeDef: f, privateField: true);
      final sb = StringBuffer();
      sb.write('');
      _addTypeDef(f, sb);
      sb.write(
          ' get $publicFieldName => $privateFieldName;set $publicFieldName(');
      _addTypeDef(f, sb);
      sb.write(' $publicFieldName) => $privateFieldName = $publicFieldName;');
      return sb.toString();
    }).join('');
  }

  String get _defaultPrivateConstructor {
    final sb = StringBuffer();
    sb.write('$name({');
    fields.keys.forEach((key) {
      final f = fields[key];
      final publicFieldName = fixFieldName(
        key,
        typeDef: f,
        privateField: false,
      );
      _addTypeDef(f, sb);
      sb.write(' $publicFieldName');
      sb.write(', ');
    });
    sb.write('}) {');
    fields.keys.forEach((key) {
      final f = fields[key];
      final publicFieldName =
          fixFieldName(key, typeDef: f, privateField: false);
      final privateFieldName =
          fixFieldName(key, typeDef: f, privateField: true);
      sb.write('$privateFieldName = $publicFieldName;');
    });
    sb.write('}');
    return sb.toString();
  }

  String get _defaultConstructor {
    final sb = StringBuffer();
    sb.write('$name({');
    fields.keys.forEach((key) {
      final f = fields[key];
      final fieldName =
          fixFieldName(key, typeDef: f, privateField: privateFields);
      sb.write('this.$fieldName');
      sb.write(', ');
    });
    sb.write('});');
    return sb.toString();
  }

  String get _jsonParseFunc {
    final sb = StringBuffer();
    sb.write('static $name fromJson(Map<String, dynamic> json) {');
    sb.write('if (json == null) return null;\n');
    sb.write('final bean = $name();');
    fields.keys.forEach((k) {
      sb.write(fields[k].jsonParseExpression(k, privateFields));
    });
    sb.write('return bean; }');
    return sb.toString();
  }

  String get _jsonGenFunc {
    final sb = StringBuffer();
    sb.write(
      'Map<String, dynamic> toJson() {\n return {',
    );
    fields.keys.forEach((k) {
      if (privateFields) {
        sb.write('\'$k\': _$k,');
      } else {
        sb.write('\'$k\': $k,');
      }
    });
    sb.write('};}');
    return sb.toString();
  }

  String get _copyWithFunc {
    final sb = StringBuffer();
    sb.write('$name copyWith({');
    fields.keys.forEach((k) => sb.write('${fields[k].type} $k,'));
    sb.write('}) { return $name(');
    fields.keys.forEach((k) => sb.write('$k: $k ?? this.$k,'));
    sb.write('); }');
    return sb.toString();
  }

  String get _toStringFunc {
    return '@override String toString() {'
        ' return JsonEncoder.withIndent(\'  \').convert(toJson()); '
        '}';
  }

  String get _equalFunc {
    final sb = StringBuffer();
    sb.write(
      '@override bool operator==(Object other) => identical(this, other) || other is $name && runtimeType == other.runtimeType &&',
    );
    for (int i = 0; i < fields.keys.length; i++) {
      final k = fields.keys.toList()[i];
      if (i < fields.keys.length - 1) {
        sb.write('$k == other.$k &&');
      } else {
        sb.write('$k == other.$k;');
      }
    }
    return sb.toString();
  }

  String get _hashCodeFunc {
    final sb = StringBuffer();
    sb.write('@override int get hashCode => ');
    for (int i = 0; i < fields.keys.length; i++) {
      final k = fields.keys.toList()[i];
      if (i < fields.keys.length - 1) {
        sb.write('$k.hashCode ^');
      } else {
        sb.write('$k.hashCode;');
      }
    }
    return sb.toString();
  }

  String toString() {
    if (privateFields) {
      // return 'class $name {\n$_fieldList\n\n$_defaultPrivateConstructor\n\n$_gettersSetters\n\n$_jsonParseFunc\n\n$_jsonGenFunc\n\n$_copyWithFunc\n\n$_equalFunc\n\n$_hashCodeFunc\n\n$_toStringFunc\n}\n';
      return 'class $name {\n$_fieldList\n\n${needConstructor ? _defaultPrivateConstructor : ''}\n\n$_jsonParseFunc\n\n$_jsonGenFunc\n\n$_toStringFunc\n}\n ${privateFields ? 'extension ${name}X on $name { $_getters }' : '' }';
    } else {
      // return 'class $name {\n$_fieldList\n\n$_defaultConstructor\n\n$_jsonParseFunc\n\n$_jsonGenFunc\n\n$_copyWithFunc\n\n$_equalFunc\n\n$_hashCodeFunc\n\n$_toStringFunc\n}\n';
      return 'class $name {\n$_fieldList\n\n${needConstructor ? _defaultConstructor : ''}\n\n$_jsonParseFunc\n\n$_jsonGenFunc\n\n$_toStringFunc\n}\n';
    }
  }
}
