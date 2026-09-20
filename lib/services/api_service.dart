import 'dart:io';

import '../models/record.dart';
import '../models/staff.dart';
import 'api/ledgers_ops.dart';
import 'api/meta_ops.dart';
import 'api/mode_dispatch.dart' as mode_dispatch;
import 'api/records_ops.dart';
import 'api/staff_ops.dart';
import 'sync_service.dart';

export 'connection_mode.dart';

/// 对外统一入口：按连接模式分发到 records / ledgers / staff / meta 实现。
///
/// 具体三种模式的实现在 `services/api/` 目录，本类只做门面与同步转发。
class ApiService {
  static Stream<bool> get syncStream => SyncService.syncStream;
  static Stream<void> get syncCompletedStream =>
      SyncService.syncCompletedStream;
  static bool get isConnected => SyncService.isConnected;

  static String serializeDateForBackend(DateTime date) =>
      mode_dispatch.serializeDateForBackend(date);

  // ==================== WebSocket 同步 ====================

  static Future<void> connectWebSocket() => SyncService.connectWebSocket();

  static Future<void> disconnectWebSocket() =>
      SyncService.disconnectWebSocket();

  static Future<void> performIncrementalSync() =>
      SyncService.performIncrementalSync();

  // ==================== 记录操作 ====================

  static Future<List<Record>> getAllRecords() => RecordsOps.getAll();

  static Future<List<Record>> getRecentRecords({int months = 3}) =>
      RecordsOps.getRecent(months: months);

  static Future<List<Record>> searchRecords({
    required DateTime startDate,
    required DateTime endDate,
    String? category,
    String? ledger,
  }) => RecordsOps.search(
    startDate: startDate,
    endDate: endDate,
    category: category,
    ledger: ledger,
  );

  static Future<Record> createRecord(Record record) =>
      RecordsOps.create(record);

  static Future<Record> updateRecord(Record record) =>
      RecordsOps.update(record);

  static Future<void> deleteRecord(String recordId) =>
      RecordsOps.delete(recordId);

  static Future<List<Record>> getDeletedRecords() => RecordsOps.getDeleted();

  static Future<void> restoreRecord(String recordId) =>
      RecordsOps.restore(recordId);

  static Future<void> restoreDeletedRecord(String recordId) =>
      RecordsOps.restore(recordId);

  static Future<void> permanentlyDeleteRecord(String recordId) =>
      RecordsOps.permanentlyDelete(recordId);

  // ==================== 账本操作 ====================

  static Future<List<String>> getAllLedgers() => LedgersOps.getAll();

  static Future<List<String>> syncLedgers() => LedgersOps.getAll();

  static Future<String> createLedger(String name) => LedgersOps.create(name);

  static Future<String> updateLedger(String oldName, String newName) =>
      LedgersOps.update(oldName, newName);

  static Future<void> deleteLedger(String name) => LedgersOps.delete(name);

  // ==================== 人员操作 ====================

  static Future<List<Staff>> getAllStaff() => StaffOps.getAll();

  static Future<List<Staff>> getStaffList() => StaffOps.getAll();

  static Future<Staff> addStaff(Staff staff) => StaffOps.add(staff);

  static Future<Staff> updateStaff(Staff staff) => StaffOps.update(staff);

  static Future<void> deleteStaff(String staffId) => StaffOps.delete(staffId);

  // ==================== 工作内容和类别 ====================

  static Future<List<String>> getWorkContents() => MetaOps.getWorkContents();

  static Future<List<String>> getCategories() => MetaOps.getCategories();

  // ==================== 图片上传 ====================

  static Future<String> uploadImage(File imageFile) async {
    final dataUrl = await mode_dispatch.fileToDataUrl(imageFile);
    if (dataUrl.length > 60000) {
      throw Exception('图片过大，请选择更小的图片（建议小于 40KB）');
    }
    return dataUrl;
  }

  static void dispose() {
    SyncService.dispose();
  }
}
