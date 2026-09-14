import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'api_config.dart';
import 'backend_client.dart';
import 'connection_mode.dart';
import 'local_database.dart';
import '../models/record.dart';
import '../models/staff.dart';

class SyncService {
  static WebSocket? _webSocket;
  static StreamSubscription? _webSocketSubscription;
  static Timer? _heartbeatTimer;
  static bool _isConnected = false;
  static bool _syncInProgress = false;
  static bool _syncPending = false;
  static final _syncController = StreamController<bool>.broadcast();
  static final _syncCompletedController = StreamController<void>.broadcast();

  static Stream<bool> get syncStream => _syncController.stream;

  /// 每次增量同步完成后触发，UI 可据此刷新
  static Stream<void> get syncCompletedStream => _syncCompletedController.stream;

  static bool get isConnected => _isConnected;

  static Future<void> connectWebSocket() async {
    try {
      final mode = await ApiConfig.getConnectionMode();
      if (mode != ConnectionMode.backend) {
        return;
      }

      await disconnectWebSocket();

      final wsUrl = await ApiConfig.getWebSocketUrl();
      print('WebSocket connecting to: $wsUrl');

      // Windows 上使用自定义 SecurityContext 解决 SSL 问题
      final securityContext = SecurityContext();
      final httpClient = HttpClient(context: securityContext);
      httpClient.badCertificateCallback = (cert, host, port) => true;

      _webSocket = await WebSocket.connect(wsUrl, customClient: httpClient);

      _webSocketSubscription = _webSocket?.listen(
        (data) => _handleWebSocketMessage(data),
        onError: (error) {
          _isConnected = false;
          _syncController.add(false);
          print('WebSocket error: $error');
        },
        onDone: () {
          _isConnected = false;
          _syncController.add(false);
          _stopHeartbeat();
          print('WebSocket disconnected');
          Future.delayed(const Duration(seconds: 5), () => connectWebSocket());
        },
      );

      _isConnected = true;
      _syncController.add(true);
      _startHeartbeat();
      print('WebSocket connected');

      await performIncrementalSync();
    } catch (e) {
      _isConnected = false;
      _syncController.add(false);
      _stopHeartbeat();
      print('Failed to connect to WebSocket: $e');
      Future.delayed(const Duration(seconds: 5), () => connectWebSocket());
    }
  }

  static void _startHeartbeat() {
    _stopHeartbeat();
    // Cloudflare 等代理约 100s 空闲会断开，30s 发一次心跳
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final socket = _webSocket;
      if (socket == null || socket.readyState != WebSocket.open) {
        return;
      }
      try {
        socket.add('{"type":"ping"}');
      } catch (e) {
        print('WebSocket heartbeat failed: $e');
      }
    });
  }

  static void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  static Future<void> disconnectWebSocket() async {
    _stopHeartbeat();
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    if (_webSocket != null) {
      await _webSocket!.close();
      _webSocket = null;
    }
    _isConnected = false;
    _syncController.add(false);
  }

  static void _handleWebSocketMessage(dynamic data) {
    try {
      if (data == null || data.toString().isEmpty) return;
      final message = json.decode(data);
      if (message is Map && message['type'] == 'pong') {
        return;
      }

      final entityType = message['entity_type'];
      final eventType = message['event_type'];
      print('Received sync event: $eventType for $entityType');

      // await 会阻塞 WS 回调；用 pending 合并并发触发
      unawaited(performIncrementalSync());
    } catch (e) {
      print('Error handling WebSocket message: $e');
    }
  }

  static Future<void> performIncrementalSync() async {
    if (_syncInProgress) {
      _syncPending = true;
      print(
        'DEBUG: skip duplicate incremental sync while another sync is still running',
      );
      return;
    }

    _syncInProgress = true;
    _syncPending = false;
    print('DEBUG: start incremental sync');

    try {
      final mode = await ApiConfig.getConnectionMode();
      if (mode != ConnectionMode.backend) {
        print(
          'DEBUG: incremental sync skipped because current mode is not backend',
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSync = prefs.getString('lastSyncTime');
      print('DEBUG: lastSyncTime=$lastSync');

      final baseUrl = await ApiConfig.getBackendBaseUrl();
      print('DEBUG: syncing with backend url=$baseUrl');

      final response = await BackendClient.post('/api/v1/sync', {
        'lastSyncTime': lastSync,
      });

      print('DEBUG: sync response=$response');

      await _applySyncChanges(Map<String, dynamic>.from(response as Map));

      final serverTime = response['serverTime']?.toString();
      if (serverTime != null && serverTime.isNotEmpty) {
        await prefs.setString('lastSyncTime', serverTime);
      }
      print('DEBUG: sync completed successfully, serverTime=$serverTime');
      if (!_syncCompletedController.isClosed) {
        _syncCompletedController.add(null);
      }
    } catch (e) {
      print('DEBUG: incremental sync failed: $e');
    } finally {
      _syncInProgress = false;
      print('DEBUG: incremental sync complete');
      if (_syncPending) {
        unawaited(performIncrementalSync());
      }
    }
  }

  static Future<void> _applySyncChanges(Map<String, dynamic> data) async {
    final db = await LocalDatabase.get();
    final batch = db.batch();

    final records = data['records'] as List? ?? [];
    for (final recordJson in records) {
      final record = Record.fromMap(recordJson);
      batch.insert('records', {
        'id': record.id,
        'record_id': record.id,
        'date': record.date.toIso8601String(),
        'category': record.category,
        'work_content': record.workContent,
        'amount': record.amount,
        'ledger': record.ledger,
        'image_url': record.imageUrl,
        'staff_ids': json.encode(record.staffIds),
        'updated_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    final deletedRecordIds = data['deletedRecordIds'] as List? ?? [];
    for (final id in deletedRecordIds) {
      batch.delete('records', where: 'record_id = ?', whereArgs: [id]);
    }

    // 人员：按 ID 覆盖更新
    final staffList = data['staff'] as List? ?? [];
    for (final staffJson in staffList) {
      final staff = Staff.fromMap(staffJson);
      batch.insert('staff', {
        'id': int.tryParse(staff.id) ?? 0,
        'name': staff.name,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    // 人员删除：之前客户端完全忽略了 deletedStaffIds
    final deletedStaffIds = data['deletedStaffIds'] as List? ?? [];
    for (final id in deletedStaffIds) {
      batch.delete(
        'staff',
        where: 'id = ?',
        whereArgs: [int.tryParse(id.toString()) ?? -1],
      );
    }

    // 账本：同步返回的是当前全量列表，需要整体替换，否则本地会残留已删除账本
    final ledgers = data['ledgers'] as List? ?? [];
    if (ledgers.isNotEmpty) {
      batch.delete('ledgers');
      for (final ledger in ledgers) {
        batch.insert('ledgers', {
          'name': ledger,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }

    await batch.commit(noResult: true);
  }

  static void dispose() {
    _stopHeartbeat();
    final socketSub = _webSocketSubscription;
    _webSocketSubscription = null;
    final socket = _webSocket;
    _webSocket = null;
    socketSub?.cancel();
    socket?.close();
    _isConnected = false;
    _syncController.close();
    _syncCompletedController.close();
  }
}
