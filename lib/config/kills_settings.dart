import 'dart:io';

import 'package:obssource/config/json_fields.dart';

/// Local HTTP integration that shows kill counters sent by an external tool.
class KillsSettings {
  static const defaultAddress = '0.0.0.0';
  static const defaultPort = 4080;
  static const minSeconds = 1;
  static const maxSeconds = 10;

  final bool enabled;

  /// IPv4/IPv6 address to listen on; `0.0.0.0` accepts other computers.
  final String address;
  final int port;
  final int seconds;

  const KillsSettings({
    this.enabled = false,
    this.address = defaultAddress,
    this.port = defaultPort,
    this.seconds = 3,
  });

  factory KillsSettings.fromJson(Map<String, dynamic> json) =>
      KillsSettings(
        enabled: json.boolean('enabled', false),
        address: json.string('address') ?? defaultAddress,
        port: json.integer('port', defaultPort),
        seconds: json.integer('seconds', 3),
      ).normalized();

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'address': address,
    'port': port,
    'seconds': seconds,
  };

  KillsSettings normalized() => copyWith(
    address:
        InternetAddress.tryParse(address.trim()) != null
            ? address.trim()
            : defaultAddress,
    port: port > 0 && port <= 65535 ? port : defaultPort,
    seconds: seconds.clamp(minSeconds, maxSeconds),
  );

  KillsSettings copyWith({
    bool? enabled,
    String? address,
    int? port,
    int? seconds,
  }) => KillsSettings(
    enabled: enabled ?? this.enabled,
    address: address ?? this.address,
    port: port ?? this.port,
    seconds: seconds ?? this.seconds,
  );
}
