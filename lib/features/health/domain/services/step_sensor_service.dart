import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

enum StepSensorStatus {
  idle,
  listening,
  permissionDenied,
  permissionPermanentlyDenied,
  unavailable,
  error,
}

class StepSensorService {
  static final StepSensorService instance = StepSensorService._internal();
  StepSensorService._internal();

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  StepSensorStatus _status = StepSensorStatus.idle;
  StepSensorStatus get status => _status;

  int _baseOffset = 0;
  int _lastRawStepCount = 0;
  int _sessionSteps = 0;
  String _pedestrianState = 'unknown';

  final _stepStreamController = StreamController<int>.broadcast();
  Stream<int> get stepStream => _stepStreamController.stream;

  final _statusStreamController = StreamController<StepSensorStatus>.broadcast();
  Stream<StepSensorStatus> get statusStream => _statusStreamController.stream;

  String get pedestrianState => _pedestrianState;

  Future<bool> initSensor({bool autoStart = true}) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _setStatus(StepSensorStatus.unavailable);
      return false;
    }

    try {
      if (Platform.isAndroid) {
        final permStatus = await Permission.activityRecognition.request();
        if (permStatus.isDenied) {
          _setStatus(StepSensorStatus.permissionDenied);
          return false;
        } else if (permStatus.isPermanentlyDenied) {
          _setStatus(StepSensorStatus.permissionPermanentlyDenied);
          return false;
        }
      }

      if (autoStart) {
        startListening();
      }
      return true;
    } catch (e) {
      debugPrint('StepSensorService init error: $e');
      _setStatus(StepSensorStatus.error);
      return false;
    }
  }

  void startListening() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      _setStatus(StepSensorStatus.unavailable);
      return;
    }

    try {
      _stepCountSubscription?.cancel();
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );

      _pedestrianStatusSubscription?.cancel();
      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatusChanged,
        onError: (e) => debugPrint('Pedestrian status error: $e'),
        cancelOnError: false,
      );

      _setStatus(StepSensorStatus.listening);
    } catch (e) {
      debugPrint('Error starting pedometer: $e');
      _setStatus(StepSensorStatus.unavailable);
    }
  }

  void _onStepCount(StepCount event) {
    if (_baseOffset == 0) {
      _baseOffset = event.steps;
    }
    _lastRawStepCount = event.steps;
    _sessionSteps = event.steps - _baseOffset;
    if (_sessionSteps < 0) _sessionSteps = 0;

    _stepStreamController.add(_sessionSteps);
  }

  void _onStepCountError(dynamic error) {
    debugPrint('Pedometer stream error: $error');
    _setStatus(StepSensorStatus.unavailable);
  }

  void _onPedestrianStatusChanged(PedestrianStatus event) {
    _pedestrianState = event.status;
  }

  void _setStatus(StepSensorStatus newStatus) {
    _status = newStatus;
    _statusStreamController.add(newStatus);
  }

  void stopListening() {
    _stepCountSubscription?.cancel();
    _pedestrianStatusSubscription?.cancel();
    _stepCountSubscription = null;
    _pedestrianStatusSubscription = null;
    _setStatus(StepSensorStatus.idle);
  }

  void dispose() {
    stopListening();
    _stepStreamController.close();
    _statusStreamController.close();
  }
}
