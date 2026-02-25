import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class ApiClient {
  late final Dio dio;
  final String baseUrl;

  ApiClient({this.baseUrl = 'http://localhost:8000/api/v1'}) {
    dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await SecureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            final opts = error.requestOptions;
            final token = await SecureStorage.getAccessToken();
            opts.headers['Authorization'] = 'Bearer $token';
            final response = await dio.fetch(opts);
            handler.resolve(response);
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refresh = await SecureStorage.getRefreshToken();
      if (refresh == null) return false;
      final response = await Dio().post(
        '$baseUrl/auth/refresh/',
        data: {'refresh': refresh},
      );
      await SecureStorage.saveTokens(
        access: response.data['access'],
        refresh: refresh,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<Response> get(String path, {Map<String, dynamic>? params, Map<String, dynamic>? queryParameters}) =>
      dio.get(path, queryParameters: queryParameters ?? params);

  Future<Response> post(String path, {dynamic data}) =>
      dio.post(path, data: data);

  Future<Response> patch(String path, {dynamic data}) =>
      dio.patch(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      dio.put(path, data: data);

  Future<Response> delete(String path) => dio.delete(path);
}
