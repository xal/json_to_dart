import 'package:clippy/server.dart' as clippy;
import 'package:colorize/colorize.dart';
import 'package:json_to_dart/model_generator.dart';

void main(List<String> args) async {
  final className = args[0];
  final jsonString = args[1];

  final classGenerator = ModelGenerator(className, true);
  String dartClassString = classGenerator.generateDartClasses(jsonString);

  await clippy.write(dartClassString);
  print(dartClassString);
  print(Colorize('The json string has been copied to the paste board ~')
    ..yellow());
}
