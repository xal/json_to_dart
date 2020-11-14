import 'package:dart_style/dart_style.dart';

import './helpers.dart';
import './syntax.dart';

class ModelGenerator {
  final String _rootClassName;
  final bool _privateFields;
  final bool _needConstructor;
  List<ClassDefinition> allClasses = List<ClassDefinition>();

  ModelGenerator(
    this._rootClassName, [
    this._privateFields = true,
    this._needConstructor = false,
  ]);

  _generateClassDefinition(String className, Map<String, dynamic> jsonRawData) {
    if (jsonRawData is List) {
      // if first element is an array, start in the first element.
      _generateClassDefinition(
        className,
        jsonRawData[0] as Map<String, dynamic>,
      );
    } else {
      final keys = jsonRawData.keys;
      final classDefinition = ClassDefinition(
        className,
        _privateFields,
        _needConstructor,
      );
      keys.forEach((key) {
        final typeDef = TypeDefinition.fromDynamic(jsonRawData[key]);
        if (typeDef.type == 'Class') {
          typeDef.type = camelCase(key);
        }
        if (typeDef.subtype != null && typeDef.subtype == 'Class') {
          typeDef.subtype = camelCase(key);
        }
        classDefinition.addField(key, typeDef);
      });
      if (allClasses.firstWhere((cd) => cd == classDefinition,
              orElse: () => null) ==
          null) {
        allClasses.add(classDefinition);
      }
      final dependencies = classDefinition.dependencies;
      dependencies.forEach((dependency) {
        if (dependency.typeDef.type == 'List') {
          if (jsonRawData[dependency.name].length as int > 0) {
            // only generate dependency class if the array is not empty
            _generateClassDefinition(dependency.className,
                jsonRawData[dependency.name][0] as Map<String, dynamic>);
          }
        } else {
          _generateClassDefinition(dependency.className,
              jsonRawData[dependency.name] as Map<String, dynamic>);
        }
      });
    }
  }

  /// generateDartClasses will generate all classes and append one after another
  /// in a single string. The [rawJson] param is assumed to be a properly
  /// formatted JSON string. If the generated dart is invalid it will throw an error.
  String generateDartClasses(String rawJson) {
    final Map<String, dynamic> jsonRawData = decodeJSON(rawJson);
    _generateClassDefinition(_rootClassName, jsonRawData);
    final unsafeDart = allClasses.map((c) => c.toString()).join('\n');
    final formatter = DartFormatter();
    return formatter.format(unsafeDart);
  }
}
