/// Android 13 cannot distinguish first use from denial: remember the first ask.
Future<bool> requestPushPermissionOnce({
  required Future<bool> Function() isAuthorized,
  required bool Function() wasRequested,
  required Future<void> Function() markRequested,
  required Future<bool> Function() request,
}) async {
  if (await isAuthorized()) return true;
  if (wasRequested()) return false;
  await markRequested();
  return request();
}
