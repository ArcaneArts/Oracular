import 'dart:io';

import 'package:interact/interact.dart';

import 'prompt_environment.dart';

/// Text input prompts (strings, numbers, validation)
class InputPrompt {
  /// Ask for a string input with validation
  static Future<String> askString(
    String question, {
    String? defaultValue,
    bool Function(String)? validator,
    String? validationMessage,
  }) async {
    if (PromptEnvironment.useSimplePrompts) {
      return _askSimpleString(
        question,
        defaultValue: defaultValue,
        validator: validator,
        validationMessage: validationMessage,
      );
    }

    try {
      final String result = Input(
        prompt: question,
        defaultValue: defaultValue ?? '',
        validator: validator != null
            ? (String value) {
                if (validator(value)) return true;
                throw ValidationError(validationMessage ?? 'Invalid input');
              }
            : null,
      ).interact();
      return result;
    } on Object {
      return _askSimpleString(
        question,
        defaultValue: defaultValue,
        validator: validator,
        validationMessage: validationMessage,
      );
    }
  }

  /// Ask for a number input
  static Future<int> askInt(
    String question, {
    required int defaultValue,
    int? min,
    int? max,
  }) async {
    if (PromptEnvironment.useSimplePrompts) {
      final String result = _askSimpleString(
        question,
        defaultValue: defaultValue.toString(),
        validator: (String value) =>
            _validateInt(value, min: min, max: max) == null,
        validationMessage: 'Please enter a valid number',
      );
      return int.parse(result);
    }

    try {
      final String result = Input(
        prompt: question,
        defaultValue: defaultValue.toString(),
        validator: (String value) {
          final String? error = _validateInt(value, min: min, max: max);
          if (error != null) {
            throw ValidationError(error);
          }
          return true;
        },
      ).interact();
      return int.parse(result);
    } on Object {
      return defaultValue;
    }
  }

  /// Ask for a double/decimal input
  static Future<double> askDouble(
    String question, {
    required double defaultValue,
    double? min,
    double? max,
  }) async {
    if (PromptEnvironment.useSimplePrompts) {
      final String result = _askSimpleString(
        question,
        defaultValue: defaultValue.toString(),
        validator: (String value) =>
            _validateDouble(value, min: min, max: max) == null,
        validationMessage: 'Please enter a valid number',
      );
      return double.parse(result);
    }

    try {
      final String result = Input(
        prompt: question,
        defaultValue: defaultValue.toString(),
        validator: (String value) {
          final String? error = _validateDouble(value, min: min, max: max);
          if (error != null) {
            throw ValidationError(error);
          }
          return true;
        },
      ).interact();
      return double.parse(result);
    } on Object {
      return defaultValue;
    }
  }

  /// Ask for email input with validation
  static Future<String> askEmail(String question, {String? defaultValue}) async {
    if (PromptEnvironment.useSimplePrompts) {
      return _askSimpleString(
        question,
        defaultValue: defaultValue,
        validator: _isEmail,
        validationMessage: 'Please enter a valid email address',
      );
    }

    try {
      final String result = Input(
        prompt: question,
        defaultValue: defaultValue ?? '',
        validator: (String value) {
          if (_isEmail(value)) return true;
          throw ValidationError('Please enter a valid email address');
        },
      ).interact();
      return result;
    } on Object {
      return defaultValue ?? '';
    }
  }

  /// Ask for URL input with validation
  static Future<String> askUrl(String question, {String? defaultValue}) async {
    if (PromptEnvironment.useSimplePrompts) {
      return _askSimpleString(
        question,
        defaultValue: defaultValue,
        validator: _isUrl,
        validationMessage: 'Please enter a valid URL (http:// or https://)',
      );
    }

    try {
      final String result = Input(
        prompt: question,
        defaultValue: defaultValue ?? '',
        validator: (String value) {
          if (_isUrl(value)) return true;
          throw ValidationError(
            'Please enter a valid URL (http:// or https://)',
          );
        },
      ).interact();
      return result;
    } on Object {
      return defaultValue ?? '';
    }
  }

  static String _askSimpleString(
    String question, {
    String? defaultValue,
    bool Function(String)? validator,
    String? validationMessage,
  }) {
    for (int attempt = 0; attempt < 3; attempt++) {
      final String defaultHint = defaultValue == null ? '' : ' [$defaultValue]';
      stdout.write('$question$defaultHint: ');
      final String value = stdin.readLineSync()?.trim() ?? '';
      final String result = value.isEmpty ? (defaultValue ?? '') : value;

      if (validator == null || validator(result)) {
        return result;
      }

      print(validationMessage ?? 'Invalid input');
    }

    if (defaultValue != null &&
        (validator == null || validator(defaultValue))) {
      return defaultValue;
    }

    throw StateError('No valid input provided for: $question');
  }

  static String? _validateInt(String value, {int? min, int? max}) {
    final int? parsedNum = int.tryParse(value);
    if (parsedNum == null) {
      return 'Please enter a valid number';
    }
    if (min != null && parsedNum < min) {
      return 'Value must be at least $min';
    }
    if (max != null && parsedNum > max) {
      return 'Value must be at most $max';
    }
    return null;
  }

  static String? _validateDouble(String value, {double? min, double? max}) {
    final double? parsedNum = double.tryParse(value);
    if (parsedNum == null) {
      return 'Please enter a valid number';
    }
    if (min != null && parsedNum < min) {
      return 'Value must be at least $min';
    }
    if (max != null && parsedNum > max) {
      return 'Value must be at most $max';
    }
    return null;
  }

  static bool _isEmail(String value) {
    return value.contains('@') && value.contains('.');
  }

  static bool _isUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
