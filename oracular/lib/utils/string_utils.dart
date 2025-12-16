/// String manipulation utilities for Oracular CLI

/// Convert snake_case to PascalCase
/// Example: "my_app_name" -> "MyAppName"
String snakeToPascal(String snake) {
  if (snake.isEmpty) return snake;
  return snake
      .split('_')
      .map(
        (String word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase(),
      )
      .join();
}

/// Convert snake_case to camelCase
/// Example: "my_app_name" -> "myAppName"
String snakeToCamel(String snake) {
  final String pascal = snakeToPascal(snake);
  if (pascal.isEmpty) return pascal;
  return pascal[0].toLowerCase() + pascal.substring(1);
}

/// Convert PascalCase or camelCase to snake_case
/// Example: "MyAppName" -> "my_app_name"
String toSnakeCase(String input) {
  if (input.isEmpty) return input;
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < input.length; i++) {
    final String char = input[i];
    if (char.toUpperCase() == char && char.toLowerCase() != char) {
      if (i > 0) buffer.write('_');
      buffer.write(char.toLowerCase());
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// Convert to kebab-case
/// Example: "my_app_name" -> "my-app-name"
String toKebabCase(String snake) {
  return snake.replaceAll('_', '-');
}

/// Capitalize first letter
/// Example: "hello" -> "Hello"
String capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

/// Lowercase first letter
/// Example: "Hello" -> "hello"
String lowercaseFirst(String input) {
  if (input.isEmpty) return input;
  return input[0].toLowerCase() + input.substring(1);
}
