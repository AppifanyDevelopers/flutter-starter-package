import 'package:dartz/dartz.dart';

import '../errors/app_error.dart';

/// Registers this device's push token with the backend
/// (`POST AppEndpoints.deviceTokens`).
abstract class DeviceTokenRepository {
  Future<Either<AppError, Unit>> register(String deviceToken);
}

/// Accepts the token and does nothing, so push works end to end against the
/// fake backend. TODO(swap-backend): replace with a Dio implementation that
/// posts `device_token` (+ `platform`, `token_type`) to `AppEndpoints.deviceTokens`.
class FakeDeviceTokenRepository implements DeviceTokenRepository {
  @override
  Future<Either<AppError, Unit>> register(String deviceToken) async => right(unit);
}
