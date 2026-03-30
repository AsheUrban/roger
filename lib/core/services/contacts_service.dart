import '../models/user.dart';

class ContactsService {
  Future<bool> requestPermission() async => throw UnimplementedError();
  Future<bool> hasPermission() async => throw UnimplementedError();
  Future<List<({String name, String phoneNumber})>> getDeviceContacts() async =>
      throw UnimplementedError();
  String normalizeToE164(String phoneNumber) => throw UnimplementedError();
  String hashPhoneNumber(String e164Number) => throw UnimplementedError();
  Future<List<User>> batchCheckHashes(List<String> hashes) async =>
      throw UnimplementedError();
  Future<User?> onDemandSearch(String query) async => null;
  Future<void> refreshBatchCheck() async {}
}
