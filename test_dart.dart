import 'dart:async';

void main() async {
  try {
    String pos = await Future<String>.error("Timeout").catchError((_) => Future<String?>.value(null)) ?? "default";
    print(pos);
  } catch (e) {
    print("Error: $e");
  }
}
