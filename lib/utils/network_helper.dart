export 'network_helper_stub.dart'
    if (dart.library.io) 'network_helper_mobile.dart'
    if (dart.library.html) 'network_helper_web.dart';
