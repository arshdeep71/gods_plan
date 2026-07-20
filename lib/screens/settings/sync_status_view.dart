import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../models/sync_item.dart';

class SyncStatusView extends StatefulWidget {
  const SyncStatusView({super.key});

  @override
  State<SyncStatusView> createState() => _SyncStatusViewState();
}

class _SyncStatusViewState extends State<SyncStatusView> {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  List<SyncItem> _queue = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    setState(() => _isLoading = true);
    final queue = await _dbService.getSyncQueue();
    if (mounted) {
      setState(() {
        _queue = queue;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    final userId = _dbService.settingsBox.get('current_user_id') as String?; // Assuming this exists or we get it via auth
    if (userId != null) {
      await _syncService.sync(userId);
    }
    await _loadQueue();
    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Synchronization cycle completed.')),
      );
    }
  }

  void _exportDatabase() {
    // TODO: Implement file_picker export logic for SQLite backup
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Database export initiated...')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sync & Backup Status', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync),
              onPressed: _triggerManualSync,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBackupSection(),
                const Divider(color: Colors.white24),
                Expanded(
                  child: _queue.isEmpty
                      ? _buildEmptyState()
                      : _buildQueueList(),
                ),
              ],
            ),
    );
  }

  Widget _buildBackupSection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Local Backup',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "God's Plan is offline-first. You can export a fully encrypted AES copy of your SQLite database for manual restoration.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportDatabase,
                    icon: const Icon(Icons.download),
                    label: const Text('Export DB'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      foregroundColor: Colors.blueAccent,
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload),
                    label: const Text('Restore DB'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.2),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_done, size: 64, color: Colors.greenAccent.withOpacity(0.8)),
          const SizedBox(height: 16),
          const Text(
            'All systems synced!',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your local database matches the cloud.',
            style: TextStyle(color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _buildQueueList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _queue.length,
      itemBuilder: (context, index) {
        final item = _queue[index];
        final bool isDelayed = item.nextRetryAt != null && item.nextRetryAt!.isAfter(DateTime.now().toUtc());

        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isDelayed ? Colors.orangeAccent.withOpacity(0.2) : Colors.blueAccent.withOpacity(0.2),
              child: Icon(
                isDelayed ? Icons.timer : Icons.cloud_upload,
                color: isDelayed ? Colors.orangeAccent : Colors.blueAccent,
                size: 20,
              ),
            ),
            title: Text(
              '\${item.actionType} \${item.tableName}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID: \${item.recordId}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                if (item.retryCount > 0)
                  Text(
                    'Retries: \${item.retryCount}' + (isDelayed ? ' • Next: \${DateFormat.Hm().format(item.nextRetryAt!.toLocal())}' : ''),
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () async {
                if (item.id != null) {
                  await _dbService.removeSyncItem(item.id!);
                  _loadQueue();
                }
              },
            ),
          ),
        );
      },
    );
  }
}
