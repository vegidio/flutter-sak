enum LogLevel { none, basic, headers, body }

class LogPolicy {
  final LogLevel logLevel;

  const LogPolicy({this.logLevel = LogLevel.none});
}
