import 'package:hive/hive.dart';

part 'config.g.dart';

@HiveType(typeId: 1)
class Config {
  @HiveField(0)
  String name;

  @HiveField(1)
  String username;

  @HiveField(2)
  String host;

  @HiveField(3)
  String password;

  @HiveField(4)
  int port;

  Config({
    required this.name,
    required this.username,
    required this.host,
    required this.password,
    required this.port,
  });

  @override
  String toString() => "Config($name, $username, $host, $password, $port)";
}
