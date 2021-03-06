class DataTableFilter {
  int limit = 10;
  int offset = 0;
  String searchString;
  String orderBy;
  String orderDir;
  Map<String, String> stringParams = {};

  DataTableFilter({this.limit = 10, this.offset = 0, this.searchString});

  void clear() {
    limit = 10;
    offset = 0;
    searchString = null;
    orderBy = null;
    orderDir = null;
    stringParams.clear();
  }

  Map<String, String> getParams() {
    if (limit != null && limit != -1) {
      stringParams['limit'] = limit.toString();
    }
    if (offset != null && offset != -1) {
      stringParams['offset'] = offset.toString();
    }
    if (searchString != null) {
      stringParams['search'] = searchString;
    }
    if (orderBy != null) {
      stringParams['orderBy'] = orderBy;
    }
    if (orderDir != null) {
      stringParams['orderDir'] = orderDir;
    }
    return stringParams;
  }

  void addParam(String paramName, String paramValue) {
    if (paramName != null && paramName.isNotEmpty) {
      stringParams[paramName] = paramValue;
    }
  }

  void addParams(Map<String, String> params) {
    stringParams.addAll(params);
  }
}
