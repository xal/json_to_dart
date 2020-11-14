import 'package:args/args.dart';
import 'package:clippy/server.dart' as clippy;
import 'package:colorize/colorize.dart';
import 'package:json_to_dart/model_generator.dart';

void main(List<String> args) async {
  final parser = ArgParser()
    ..addFlag('private', abbr: 'p', defaultsTo: true)
    ..addFlag('constructor', abbr: 'c', defaultsTo: false);

  final parsedArgs = parser.parse(args);

  final className = parsedArgs.arguments[0];
  final jsonString = parsedArgs.arguments[1];
  final private = parsedArgs['private'];
  final constructor = parsedArgs['constructor'];

  final classGenerator = ModelGenerator(className, private, constructor);
  String dartClassString = classGenerator.generateDartClasses(jsonString);

  await clippy.write(dartClassString);
  print(dartClassString);
  print(Colorize('The json string has been copied to the paste board ~')
    ..yellow());
}
