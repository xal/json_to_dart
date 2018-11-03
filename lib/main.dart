import 'package:json_to_dart/model_generator.dart';

void main(List<String> args) {
  final className = args[0];
  final jsonString = args[1];

  final classGenerator = ModelGenerator(className);
  String dartClassString = classGenerator.generateDartClasses(jsonString);
  print(dartClassString);
}
