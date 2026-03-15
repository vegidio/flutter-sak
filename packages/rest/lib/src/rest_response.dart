class RestResponse<T> {
  final T body;
  final int statusCode;
  final Map<String, List<String>> headers;

  const RestResponse({required this.body, required this.statusCode, required this.headers});
}
