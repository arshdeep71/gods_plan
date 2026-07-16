import 'dart:html' as html;

Future<bool> checkInternetConnection() async {
  try {
    return html.window.navigator.onLine ?? false;
  } catch (_) {
    return true;
  }
}
