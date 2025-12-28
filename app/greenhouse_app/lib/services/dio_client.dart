import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:path_provider/path_provider.dart';

class DioClient {
  static final DioClient _instance = DioClient._internal();

  late Dio dio;
  late PersistCookieJar cookieJar;

  factory DioClient() {
    return _instance;
  }

  DioClient._internal();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    cookieJar = PersistCookieJar(storage: FileStorage('${dir.path}/cookies'));
    dio = Dio();
    dio.interceptors.add(CookieManager(cookieJar));
  }

  PersistCookieJar getCookieJar() => cookieJar;
}
