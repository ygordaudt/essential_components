import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:essential_components/src/data_table/response_list.dart';
//import 'package:http/browser_client.dart';
import 'uri_mu_proto.dart';
import 'map_serialization.dart';
import 'rest_response.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../simple_dialog/simple_dialog.dart';

class RestClientGeneric<T> {
  final Map<Type, Function> factories; // = <Type, Function>{};
  //ex: DiskCache<Agenda>(factories: {Agenda: (x) => Agenda.fromJson(x)});

  //cache duration
  Duration cacheValidDuration = Duration(minutes: 30);
  //disabilita o cache
  bool _disableAllCache = true;

  isQuotaExceeded() {
    try {
      window.localStorage["QUOTA_EXCEEDED_ERR"] = "QUOTA_EXCEEDED_ERR";
      return false;
    } catch (e) {
      print("isQuotaExceeded ${e}");
      /*if (e.code == 22) {
        //code: 1014,
        //name: 'NS_ERROR_DOM_QUOTA_REACHED',
        //message: 'Persistent storage maximum size reached',
        // Storage full, maybe notify user or do some clean-up
      }*/
      return true;
    }
  }

  fillLocalStorage({int sizeMB = 5}) {
    var i = 0;
    try {
      // Test up to 5 MB
      for (var i = 0; i <= (sizeMB * 1000); i += 250) {
        window.localStorage['test'] = List((i * 1024) + 1).join('a');
      }
    } catch (e) {
      print("fillLocalStorage ${e}");
      // localStorage.removeItem('test');
      print('size ${i != null ? i - 250 : 0}');
    }
  }

  get disableAllCache {
    return _disableAllCache;
  }

  set disableAllCache(bool disable) {
    _disableAllCache = disable;
  }

  //check if is update the cache
  bool isShouldRefresh(String key) {
    return (isInLocalStorage(key) == false ||
        _getLastFetchTime(key) == null ||
        _getLastFetchTime(key).isBefore(DateTime.now().subtract(cacheValidDuration)));
  }

  http.Client client;
  static UriMuProtoType protocol;
  static String host;
  static int port;
  static String basePath = "";
  static String defaultHost = "local.riodasostras.rj.gov.br";
  //unauthorizedAccess
  static bool showDialogUnauthorizedAccess = false;
  static String dialogUnauthorizedMessage = 'Acesso não autorizado!';

  static Map<String, String> headersDefault = {
    'Content-type': 'application/json',
    'Accept': 'application/json',
    "Authorization": "Bearer " + window.sessionStorage["YWNjZXNzX3Rva2Vu"].toString()
  };

  RestClientGeneric({this.factories}) {
    client = http.Client(); //BrowserClient();
    UriMuProto.basePath = basePath;
    UriMuProto.host = host;
    UriMuProto.port = port;
    UriMuProto.protoType = protocol;
    UriMuProto.defaultHost = defaultHost;
  }

  /// Todo implementar
  Future<RestResponseGeneric<T>> getAllT<T>(String apiEndPoint,
      {bool forceRefresh = false, String topNode, Map<String, String> headers, Map<String, String> queryParameters}) {
    throw UnimplementedError('This feature is not implemented yet.');
    return null;
  }

  Future<RestResponseGeneric<T>> uploadFiles(String apiEndPoint, List<File> files,
      {String topNode,
      Map<String, String> headers,
      Map<String, dynamic> body,
      Map<String, String> queryParameters,
      String protocol,
      String host,
      int port,
      String basePath}) async {
    Uri url = UriMuProto.uri(apiEndPoint, queryParameters, basePath, protocol, host, port);

    try {
      if (queryParameters != null) {
        url = UriMuProto.uri(apiEndPoint, queryParameters, basePath, protocol, host, port);
      }

      Map<String, String> headersDefault = {
        //'Content-type': 'application/json',
        // 'Accept': 'application/json',
        "Authorization": "Bearer " + window.sessionStorage["YWNjZXNzX3Rva2Vu"].toString()
      };
      var request = http.MultipartRequest("POST", url);

      if (headers != null) {
        request.headers.addAll(headers);
      } else {
        request.headers.addAll(headersDefault);
      }

      if (body != null) {
        request.fields["data"] = jsonEncode(body);
      }

      if (files != null) {
        FileReader reader = FileReader();
        for (File file in files) {
          reader.readAsArrayBuffer(file);
          await reader.onLoadEnd.first;
          request.files.add(await http.MultipartFile.fromBytes('file[]', reader.result,
              contentType: MediaType('application', 'octet-stream'), filename: file.name));
        }
      }

      //fields.forEach((k, v) => request.fields[k] = v);
      var streamedResponse = await request.send();
      var resp = await http.Response.fromStream(streamedResponse);
      var respJson = jsonDecode(resp.body);

      return RestResponseGeneric<T>(
        headers: resp.headers,
        data: respJson,
        message: 'Sucesso',
        status: RestStatus.SUCCESS,
        statusCode: 200,
      );
    } catch (e, stacktrace) {
      print("RestClientGeneric@upload exception: ${e} stacktrace: ${stacktrace}");
      return RestResponseGeneric(message: 'Erro ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }

  Future<RestResponseGeneric<T>> getAll(String apiEndPoint, 
      {bool forceRefresh = false,
      String topNode,RestClientMethod method, Map<String, dynamic> body,
      Map<String, String> headers,
      Map<String, String> queryParameters}) async {
    Uri url = UriMuProto.uri(apiEndPoint);

    try {
      if (queryParameters != null) {
        url = UriMuProto.uri(apiEndPoint, queryParameters);
      }

      if (headers == null) {
        headers = headersDefault;
      }

      //Obtem da REST API se o cache estiver vazio, vencido ou desativado
      if (isShouldRefresh(url.toString()) || forceRefresh || disableAllCache) {
        //var resp = await client.get(url, headers: headers);
        http.Response resp;
        if (method == null) {
          resp = await client.get(url, headers: headers);
        } else if (method == RestClientMethod.POST) {
          resp = await client.post(url, headers: headers, body: jsonEncode(body));
        } else {
          resp = await client.get(url, headers: headers);
        }

        var totalReH = resp.headers.containsKey('total-records') ? resp.headers['total-records'] : null;
        var totalRecords = totalReH != null ? int.tryParse(totalReH) : 0;
        var message = '${resp.body}';
        var exception = '${resp.body}';
        var jsonDecoded = jsonDecode(resp.body);
        //print("from API");
        if (resp.statusCode == 200) {
          //coloca no cache
          if (disableAllCache == false) {
            _setToLocalStorage(url.toString(), resp.body, headers: resp.headers);
          }

          RList<T> list = RList<T>();
          list.totalRecords = totalRecords;
          if (topNode != null) {
            jsonDecoded[topNode].forEach((item) {
              list.add(factories[T](item));
            });
          } else {
            jsonDecoded.forEach((item) {
              list.add(factories[T](item));
            });
          }

          return RestResponseGeneric<T>(
              headers: resp.headers,
              totalRecords: totalRecords,
              message: 'Sucesso',
              status: RestStatus.SUCCESS,
              dataTypedList: list,
              statusCode: resp.statusCode);
        }
        //exibe mensagem se de erro de não autorizado
        if (resp.statusCode == 401) {
          var jsonDecoded = jsonDecode(resp.body);
          if (jsonDecoded is Map) {
            if (jsonDecoded.containsKey('message')) {
              dialogUnauthorizedMessage = jsonDecoded['message'];
              message = jsonDecoded['message'];
            }
            if (jsonDecoded.containsKey('exception')) {
              exception = jsonDecoded['exception'];
            }
          }
          if (showDialogUnauthorizedAccess) {
            SimpleDialogComponent.showFullScreenAlert(dialogUnauthorizedMessage);
          }
          return RestResponseGeneric<T>(
              message: message, exception: exception, status: RestStatus.UNAUTHORIZED, statusCode: resp.statusCode);
        }
        //um item ja cadastrado
        if (resp.statusCode == 409) {
          var jsonDecoded = jsonDecode(resp.body);
          if (jsonDecoded is Map) {
            if (jsonDecoded.containsKey('message')) {
              dialogUnauthorizedMessage = jsonDecoded['message'];
              message = jsonDecoded['message'];
            }
            if (jsonDecoded.containsKey('exception')) {
              exception = jsonDecoded['exception'];
            }
          }
          return RestResponseGeneric<T>(
              message: message, exception: exception, status: RestStatus.CONFLICT, statusCode: resp.statusCode);
        }
        //204 no content tabela vazia ou nenhum item correspondente
        else if (resp.statusCode == 204) {
          return RestResponseGeneric<T>(
              message: 'no content found',
              exception: exception,
              status: RestStatus.NOCONTENT,
              statusCode: resp.statusCode);
        }

        //
        else {
          return RestResponseGeneric<T>(
              message: message, exception: exception, status: RestStatus.DANGER, statusCode: resp.statusCode);
        }
      }

      //print("from Cache");

      Map result = _getAllFromCache(url.toString());
      RList list = result['data'];
      var totalRecords;
      if (result['headers'].containsKey('total-records')) {
        totalRecords = int.tryParse(result['headers']['total-records']);
        list.totalRecords = totalRecords;
      }

      return RestResponseGeneric<T>(
          headers: result['headers'],
          totalRecords: totalRecords,
          message: 'Sucesso',
          status: RestStatus.SUCCESS,
          dataTypedList: list,
          statusCode: 200);
    } catch (e) {
      print("RestClientGeneric@getAll ${e}");

      return RestResponseGeneric(message: 'Erro ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }

  Future<RestResponseGeneric<T>> get(String apiEndPoint,
      {bool forceRefresh = false,
      String topNode,
      RestClientMethod method,
      Map<String, dynamic> body,
      Map<String, String> headers,
      Map<String, String> queryParameters}) async {
    Uri url = UriMuProto.uri(apiEndPoint);

    try {
      if (queryParameters != null) {
        url = UriMuProto.uri(apiEndPoint, queryParameters);
      }

      if (headers == null) {
        headers = headersDefault;
      }

      //Obtem da REST API se o cache estivar vazio ou vencido
      if (isShouldRefresh(url.toString()) || forceRefresh || disableAllCache) {
        //var resp = await client.get(url, headers: headers);
        http.Response resp;
        if (method == null) {
          resp = await client.get(url, headers: headers);
        } else if (method == RestClientMethod.POST) {
          resp = await client.post(url, headers: headers, body: jsonEncode(body));
        } else {
          resp = await client.get(url, headers: headers);
        }

        var message = '${resp.body}';
        var exception = '${resp.body}';
        var totalReH = resp.headers.containsKey('total-records') ? resp.headers['total-records'] : null;
        var totalRecords = totalReH != null ? int.tryParse(totalReH) : 0;
        //se ouver sucesso
        if (resp.statusCode == 200) {
          //coloca no cache
          if (disableAllCache) {
            _setToLocalStorage(url.toString(), resp.body, headers: resp.headers);
          }

          var result;
          var parsedJson = jsonDecode(resp.body);
          if (topNode != null) {
            result = factories[T](parsedJson[topNode]);
          } else {
            result = factories[T](parsedJson); // Empenho.fromJson(json);
          }

          return RestResponseGeneric<T>(
              totalRecords: totalRecords,
              message: 'Sucesso',
              status: RestStatus.SUCCESS,
              dataTyped: result,
              statusCode: resp.statusCode);
        }
        //exibe mensagem se de erro não autorizado
        else if (resp.statusCode == 401) {
          var jsonDecoded = jsonDecode(resp.body);
          if (jsonDecoded is Map) {
            if (jsonDecoded.containsKey('message')) {
              dialogUnauthorizedMessage = jsonDecoded['message'];
              message = jsonDecoded['message'];
            }
            if (jsonDecoded.containsKey('exception')) {
              exception = jsonDecoded['exception'];
            }
          }
          if (showDialogUnauthorizedAccess) {
            SimpleDialogComponent.showFullScreenAlert(dialogUnauthorizedMessage);
          }
          return RestResponseGeneric<T>(
              message: message, exception: exception, status: RestStatus.UNAUTHORIZED, statusCode: resp.statusCode);
        }
        //um item ja cadastrado
        if (resp.statusCode == 409) {
          var jsonDecoded = jsonDecode(resp.body);
          if (jsonDecoded is Map) {
            if (jsonDecoded.containsKey('message')) {
              dialogUnauthorizedMessage = jsonDecoded['message'];
              message = jsonDecoded['message'];
            }
            if (jsonDecoded.containsKey('exception')) {
              exception = jsonDecoded['exception'];
            }
          }
          return RestResponseGeneric<T>(
              message: message, exception: exception, status: RestStatus.CONFLICT, statusCode: resp.statusCode);
        }
        //no content
        else if (resp.statusCode == 204) {
          return RestResponseGeneric<T>(
              message: 'no content found',
              exception: exception,
              status: RestStatus.NOCONTENT,
              statusCode: resp.statusCode);
        } else {
          return RestResponseGeneric<T>(
              message: message, exception: exception, status: RestStatus.DANGER, statusCode: resp.statusCode);
        }
      }

      Map data = _getFromCache(url.toString());
      var result = data['data'];

      return RestResponseGeneric<T>(
          totalRecords: 10, message: 'Sucesso', status: RestStatus.SUCCESS, dataTyped: result, statusCode: 200);
    } catch (e) {
      print("RestClientGeneric@get ${e}");
      return RestResponseGeneric(
          message: 'Erro ${e}', exception: 'Exception ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }

  _putAllObjectsOnCache(String key, List<T> objects) {
    _setLastFetchTime(key, DateTime.now());
    if (objects != null) {
      List<Map> maps = List<Map>();
      for (T obj in objects) {
        var item = obj as MapSerialization;
        maps.add(item.toMap());
      }
      window.localStorage.addAll({key: jsonEncode(maps)});
    }
  }

  _putObjectOnCache(String key, T object) {
    _setLastFetchTime(key, DateTime.now());
    if (object != null) {
      var item = object as MapSerialization;
      window.localStorage.addAll({key: jsonEncode(item.toMap())});
    }
  }

  _getAllFromCache(String key) {
    var obj = _getFromLocalStorage(key);
    if (obj != null) {
      List json = jsonDecode(obj['data']);
      RList<T> list = RList<T>();
      json.forEach((item) {
        list.add(factories[T](item));
      });
      //return list;
      return {"data": list, "headers": obj['headers']};
    } else {
      return null;
    }
  }

  _getFromCache(String key) {
    var obj = _getFromLocalStorage(key);
    if (obj != null) {
      Map map = jsonDecode(obj['data']);
      //return factories[T](map);
      return {"data": factories[T](map), "headers": obj['headers']};
    } else {
      return null;
    }
  }

  _getFromLocalStorage(String key) {
    if (window.localStorage.containsKey(key)) {
      var headers;
      if (window.localStorage.containsKey("headers" + key)) {
        headers = window.localStorage["headers" + key];
      }
      return {"data": window.localStorage[key], "headers": jsonDecode(headers)};
    } else {
      return null;
    }
  }

  bool isInLocalStorage(String key) {
    if (window.localStorage.containsKey(key)) {
      return true;
    } else {
      return false;
    }
  }

  _setToLocalStorage(String key, String value, {Map<String, String> headers}) {
    _setLastFetchTime(key, DateTime.now());
    window.localStorage[key] = value;
    if (headers != null) {
      window.localStorage["headers" + key] = jsonEncode(headers);
    }
  }

  DateTime _getLastFetchTime(String key) {
    if (window.localStorage.containsKey("fetchTime" + key)) {
      return DateTime.parse(window.localStorage["fetchTime" + key]);
    } else {
      return null;
    }
  }

  _setLastFetchTime(String key, DateTime date) {
    window.localStorage["fetchTime" + key] = date.toString();
  }

  Future<RestResponseGeneric> put(String apiEndPoint,
      {Map<String, String> headers, body, Map<String, String> queryParameters, Encoding encoding}) async {
    try {
      Uri url = UriMuProto.uri(apiEndPoint);
      if (queryParameters != null) {
        url = UriMuProto.uri(apiEndPoint, queryParameters);
      }

      if (encoding == null) {
        encoding = Utf8Codec();
      }

      if (headers == null) {
        headers = headersDefault;
      }

      var resp = await client.put(url, body: jsonEncode(body), encoding: encoding, headers: headers);
      var message = '${resp.body}';
      var exception = '${resp.body}';

      if (resp.statusCode == 200) {
        return RestResponseGeneric(
            message: 'Sucesso', status: RestStatus.SUCCESS, data: jsonDecode(resp.body), statusCode: resp.statusCode);
      }
      if (resp.statusCode == 401) {
        var jsonDecoded = jsonDecode(resp.body);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        if (showDialogUnauthorizedAccess) {
          SimpleDialogComponent.showFullScreenAlert(dialogUnauthorizedMessage);
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.UNAUTHORIZED, statusCode: resp.statusCode);
      }
      if (resp.statusCode == 400) {
        var jsonDecoded = jsonDecode(resp.body);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.DANGER, statusCode: resp.statusCode);
      }
      //um item ja cadastrado
      if (resp.statusCode == 409) {
        var jsonDecoded = jsonDecode(resp.body);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.CONFLICT, statusCode: resp.statusCode);
      }

      return RestResponseGeneric(message: message, status: RestStatus.DANGER, statusCode: resp.statusCode);
    } catch (e) {
      print("RestClientGeneric@put ${e}");
      return RestResponseGeneric(
          message: '${e}', exception: 'Exception ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }

  Future<RestResponseGeneric> post(String apiEndPoint,
      {Map<String, String> headers, body, Map<String, String> queryParameters, Encoding encoding}) async {
    try {
      Uri url = UriMuProto.uri(apiEndPoint);
      if (queryParameters != null) {
        url = UriMuProto.uri(apiEndPoint, queryParameters);
      }

      if (headers == null) {
        headers = headersDefault;
      }

      var resp = await client.post(url, body: jsonEncode(body), encoding: Utf8Codec(), headers: headers);
      var message = '${resp.body}';
      var exception = '${resp.body}';

      if (resp.statusCode == 200) {
        return RestResponseGeneric(
            message: 'Sucesso', status: RestStatus.SUCCESS, data: jsonDecode(resp.body), statusCode: resp.statusCode);
      }

      if (resp.statusCode == 401) {
        var jsonDecoded = jsonDecode(resp.body);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        if (showDialogUnauthorizedAccess) {
          SimpleDialogComponent.showFullScreenAlert(dialogUnauthorizedMessage);
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.UNAUTHORIZED, statusCode: resp.statusCode);
      }
      if (resp.statusCode == 400) {
        var jsonDecoded = jsonDecode(resp.body);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.DANGER, statusCode: resp.statusCode);
      }
      //um item ja cadastrado
      if (resp.statusCode == 409) {
        var jsonDecoded = jsonDecode(resp.body);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.CONFLICT, statusCode: resp.statusCode);
      }

      return RestResponseGeneric(message: '${resp.body}', status: RestStatus.DANGER, statusCode: resp.statusCode);
    } catch (e) {
      print("RestClientGeneric@post ${e}");
      return RestResponseGeneric(
          message: '${e}', exception: 'Exception ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }

  Future<RestResponseGeneric> deleteAll(String apiEndPoint,
      {Map<String, String> headers,
      List<Map<String, dynamic>> body,
      Map<String, String> queryParameters,
      Encoding encoding}) async {
    try {
      Uri url = UriMuProto.uri(apiEndPoint);
      if (queryParameters != null) {
        url = UriMuProto.uri(apiEndPoint, queryParameters);
      }

      if (headers == null) {
        headers = headersDefault;
      }

      HttpRequest request = HttpRequest();
      request.open("delete", url.toString());
      if (headers != null) {
        headers.forEach((key, value) {
          request.setRequestHeader(key, value);
        });
      } else {
        request.setRequestHeader('Content-Type', 'application/json');
      }

      request.send(json.encode(body));

      await request.onLoadEnd.first;
      //await request.onReadyStateChange.first;

      var message = '${request.responseText}';
      var exception = '${request.responseText}';
      if (request.status == 200) {
        return RestResponseGeneric(
            message: 'Sucesso',
            status: RestStatus.SUCCESS,
            data: jsonDecode(request.responseText),
            statusCode: request.status);
      }

      if (request.status == 401) {
        var jsonDecoded = jsonDecode(request.responseText);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        if (showDialogUnauthorizedAccess) {
          SimpleDialogComponent.showFullScreenAlert(dialogUnauthorizedMessage);
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.UNAUTHORIZED, statusCode: request.status);
      }
      if (request.status == 400) {
        var jsonDecoded = jsonDecode(request.responseText);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.DANGER, statusCode: request.status);
      }
      //um item ja cadastrado
      if (request.status == 409) {
        var jsonDecoded = jsonDecode(request.responseText);
        if (jsonDecoded is Map) {
          if (jsonDecoded.containsKey('message')) {
            dialogUnauthorizedMessage = jsonDecoded['message'];
            message = jsonDecoded['message'];
          }
          if (jsonDecoded.containsKey('exception')) {
            exception = jsonDecoded['exception'];
          }
        }
        return RestResponseGeneric<T>(
            message: message, exception: exception, status: RestStatus.CONFLICT, statusCode: request.status);
      }

      return RestResponseGeneric(
          message: message, exception: exception, status: RestStatus.DANGER, statusCode: request.status);
    } catch (e) {
      print("RestClientGeneric@deleteAll ${e}");
      return RestResponseGeneric(
          message: '${e}', exception: 'Exception ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }

  Future<RestResponseGeneric> raw(String url, String method,
      {Map<String, String> headers, String body, Encoding encoding}) async {
    try {
      if (headers == null) {
        headers = headersDefault;
      }

      HttpRequest request = HttpRequest();
      request.open(method, url);

      if (headers != null) {
        headers.forEach((key, value) {
          request.setRequestHeader(key, value);
        });
      }

      request.send(body);

      await request.onLoadEnd.first;
      //await request.onReadyStateChange.first;

      if (request.status == 200) {
        return RestResponseGeneric(
            message: 'Sucesso', status: RestStatus.SUCCESS, data: request.responseText, statusCode: request.status);
      }
      return RestResponseGeneric(
          data: request.responseText, message: 'Erro', status: RestStatus.DANGER, statusCode: request.status);
    } catch (e) {
      print("RestClientGeneric@raw ${e}");
      return RestResponseGeneric(
          message: '${e}', exception: 'Exception ${e}', status: RestStatus.DANGER, statusCode: 400);
    }
  }
}
