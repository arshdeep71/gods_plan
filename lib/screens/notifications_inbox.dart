import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/notification_history_model.dart';
import '../models/reminder_model.dart';
import '../services/database_service.dart';
import '../services/haptic_service.dart';
import 'package:intl/intl.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() => _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseService _db = DatabaseService();
  final TextEditingController _searchController = TextEditingController();
  
  List<NotificationHistoryModel> _history = [];
  List<ReminderModel> _upcoming = [];
  bool _isLoading = true;

  String _searchQuery = "";
  String _activeFilter = "All";
  final List<String> _filters = ["All", "Unread", "Today", "Upcoming", "Missed", "Completed", "Achievements", "Streaks", "Goals"];

  @override
  void initState() {
    debugPrint("[NOTIF_INBOX_FLOW] STEP 1: NotificationsInboxScreen initState()");
    super.initState();
    try {
      debugPrint("[NOTIF_INBOX_FLOW] STEP 2: Initializing TabController");
      _tabController = TabController(length: 2, vsync: this);
      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          if (mounted) setState(() {});
        }
      });
      debugPrint("[NOTIF_INBOX_FLOW] STEP 2 OK: TabController initialized");
    } catch (e, st) {
      debugPrint("[NOTIF_INBOX_FLOW] STEP 2 FAILED: $e");
      debugPrintStack(stackTrace: st);
    }
    
    debugPrint("[NOTIF_INBOX_FLOW] STEP 3: Calling _loadData()");
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    debugPrint("[NOTIF_INBOX_FLOW] STEP 4: _loadData() start");
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      debugPrint("[NOTIF_INBOX_FLOW] STEP 5: Getting currentUserId from DatabaseService");
      final userId = _db.currentUserId;
      debugPrint("[NOTIF_INBOX_FLOW] STEP 5 OK: currentUserId = $userId");
      
      if (userId != null && userId.isNotEmpty) {
        debugPrint("[NOTIF_INBOX_FLOW] STEP 6: Querying getLocalNotificationHistory");
        final history = await _db.getLocalNotificationHistory(userId);
        debugPrint("[NOTIF_INBOX_FLOW] STEP 6 OK: Loaded ${history.length} history records");

        debugPrint("[NOTIF_INBOX_FLOW] STEP 7: Querying getLocalReminders");
        final reminders = await _db.getLocalReminders(userId);
        debugPrint("[NOTIF_INBOX_FLOW] STEP 7 OK: Loaded ${reminders.length} reminder records");

        final now = DateTime.now();
        
        if (mounted) {
          setState(() {
            _history = history.where((h) => h.timestamp.isBefore(now)).toList();
            _history.sort((a, b) => b.timestamp.compareTo(a.timestamp));
            _upcoming = reminders.where((r) => r.scheduledTime.isAfter(now) && !r.isCompleted).toList();
            _upcoming.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
            _isLoading = false;
          });
        }
        debugPrint("[NOTIF_INBOX_FLOW] STEP 8 OK: State updated with upcoming=${_upcoming.length}, history=${_history.length}");
      } else {
        debugPrint("[NOTIF_INBOX_FLOW] STEP 5 WARN: userId is null or empty!");
        if (mounted) {
          setState(() {
            _history = [];
            _upcoming = [];
            _isLoading = false;
          });
        }
      }
    } catch (e, st) {
      debugPrint("[NOTIF_INBOX_FLOW] _loadData FAILED: $e");
      debugPrintStack(stackTrace: st);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _setFilter(String filter) {
    HapticService().selectionClick();
    setState(() {
      _activeFilter = filter;
    });
  }

  List<NotificationHistoryModel> _getFilteredHistory() {
    final now = DateTime.now();
    return _history.where((h) {
      // STRICT RULE: History tab ONLY contains past events
      if (h.timestamp.isAfter(now)) return false;

      if (_searchQuery.isNotEmpty) {
        final matchesTitle = h.title.toLowerCase().contains(_searchQuery);
        final matchesBody = h.body.toLowerCase().contains(_searchQuery);
        final matchesCategory = (h.category ?? '').toLowerCase().contains(_searchQuery);
        if (!matchesTitle && !matchesBody && !matchesCategory) return false;
      }
      
      if (_activeFilter == "All") return true;
      if (_activeFilter == "Unread") return h.status != "READ"; // Assuming DELIVERED is unread
      if (_activeFilter == "Today") {
        final now = DateTime.now();
        return h.timestamp.year == now.year && h.timestamp.month == now.month && h.timestamp.day == now.day;
      }
      if (_activeFilter == "Missed") return h.status == "MISSED";
      if (_activeFilter == "Completed") return h.status == "COMPLETED" || h.status == "DELIVERED";
      if (_activeFilter == "Achievements") return h.type == "ACHIEVEMENT";
      if (_activeFilter == "Streaks") return h.type == "STREAK";
      if (_activeFilter == "Goals") return h.type == "GOAL";
      
      return true;
    }).toList();
  }

  List<ReminderModel> _getFilteredUpcoming() {
    return _upcoming.where((r) {
      if (_searchQuery.isNotEmpty) {
        final matchesTitle = r.title.toLowerCase().contains(_searchQuery);
        final matchesBody = r.body.toLowerCase().contains(_searchQuery);
        final matchesCategory = (r.category ?? '').toLowerCase().contains(_searchQuery);
        if (!matchesTitle && !matchesBody && !matchesCategory) return false;
      }
      
      if (_activeFilter == "Today") {
        final now = DateTime.now();
        return r.scheduledTime.year == now.year && r.scheduledTime.month == now.month && r.scheduledTime.day == now.day;
      }
      if (_activeFilter == "Achievements" || _activeFilter == "Streaks" || _activeFilter == "Goals") return false; 
      
      return true;
    }).toList();
  }

  Future<void> _deleteHistoryRecord(String id) async {
    HapticService().heavyImpact();
    await _db.deleteLocalNotificationHistory(id);
    _loadData();
  }

  Future<void> _markHistoryRead(String id) async {
    HapticService().lightImpact();
    // In a real app we'd update the status to READ in SQLite.
    // For now, we mock the UI update.
    final index = _history.indexWhere((h) => h.id == id);
    if (index != -1) {
      // Re-insert with updated status
      final old = _history[index];
      final updated = NotificationHistoryModel(
        id: old.id,
        title: old.title,
        body: old.body,
        timestamp: old.timestamp,
        type: old.type,
        status: 'READ',
        relatedId: old.relatedId,
        category: old.category,
        userId: old.userId,
      );
      await _db.insertLocalNotificationHistory(updated);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              backgroundColor: const Color(0xFF0F0F1A),
              elevation: 0,
              pinned: true,
              floating: true,
              title: const Text('Notification Center', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              iconTheme: const IconThemeData(color: Colors.white),
              actions: [
                IconButton(
                  icon: const Icon(CupertinoIcons.settings),
                  onPressed: () {
                    HapticService().lightImpact();
                    Navigator.pushNamed(context, '/settings');
                  },
                )
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(180),
                child: Column(
                  children: [
                    _buildStatsCard(),
                    _buildSearchBar(),
                    _buildFilters(),
                    TabBar(
                      controller: _tabController,
                      indicatorColor: Colors.blueAccent,
                      labelColor: Colors.blueAccent,
                      unselectedLabelColor: Colors.white54,
                      dividerColor: Colors.white10,
                      tabs: const [
                        Tab(text: 'History'),
                        Tab(text: 'Upcoming'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildHistoryList(),
                  _buildUpcomingList(),
                ],
              ),
      ),
    );
  }

  Widget _buildStatsCard() {
    int upcomingCount = _upcoming.where((r) {
      final now = DateTime.now();
      return r.scheduledTime.year == now.year && r.scheduledTime.day == now.day;
    }).length;
    
    int missedCount = _history.where((h) {
      final now = DateTime.now();
      return h.status == 'MISSED' && h.timestamp.year == now.year && h.timestamp.day == now.day;
    }).length;

    int completedCount = _history.where((h) {
      final now = DateTime.now();
      return h.status == 'COMPLETED' && h.timestamp.year == now.year && h.timestamp.day == now.day;
    }).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161622),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('TODAY', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Upcoming', upcomingCount.toString(), Colors.blueAccent),
                Container(width: 1, height: 30, color: Colors.white10),
                _buildStatColumn('Missed', missedCount.toString(), Colors.redAccent),
                Container(width: 1, height: 30, color: Colors.white10),
                _buildStatColumn('Completed', completedCount.toString(), Colors.greenAccent),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOut);
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search alerts, tasks, categories...',
            hintStyle: const TextStyle(color: Colors.white38),
            prefixIcon: const Icon(CupertinoIcons.search, color: Colors.white38, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(CupertinoIcons.clear_circled_solid, color: Colors.white38, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isActive = _activeFilter == filter;
          return GestureDetector(
            onTap: () => _setFilter(filter),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isActive ? Colors.blueAccent : Colors.white12),
              ),
              child: Center(
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isActive ? Colors.blueAccent : Colors.white54,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryList() {
    final filtered = _getFilteredHistory();
    if (filtered.isEmpty) return _buildEmptyState('No history available 🎉', CupertinoIcons.tray_arrow_down);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        bool isUnread = item.status != 'READ' && item.status != 'COMPLETED';
        Color color = _getColorForType(item.type, item.status);
        IconData icon = _getIconForType(item.type);

        return Slidable(
          key: ValueKey(item.id),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              if (isUnread)
                SlidableAction(
                  onPressed: (_) => _markHistoryRead(item.id),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  icon: CupertinoIcons.checkmark_circle,
                  label: 'Read',
                ),
              SlidableAction(
                onPressed: (_) => _deleteHistoryRecord(item.id),
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                icon: CupertinoIcons.delete,
                label: 'Delete',
                borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
            ],
          ),
          child: _buildNotificationCard(
            title: item.title,
            message: item.body,
            timeStr: _formatDate(item.timestamp),
            icon: icon,
            color: color,
            isRead: !isUnread,
          ).animate().fadeIn(duration: 200.ms, delay: (index * 50).ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOut),
        );
      },
    );
  }

  Widget _buildUpcomingList() {
    final filtered = _getFilteredUpcoming();
    if (filtered.isEmpty) return _buildEmptyState('No upcoming tasks 🎉', CupertinoIcons.calendar);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        Color color = _getColorForType(item.type, '');
        IconData icon = _getIconForType(item.type);
        final nextNotifStr = _getUpcomingNextNotificationText(item.scheduledTime);

        return Slidable(
          key: ValueKey(item.id),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) {
                  HapticService().selectionClick();
                },
                backgroundColor: Colors.orangeAccent,
                foregroundColor: Colors.white,
                icon: CupertinoIcons.clock,
                label: 'Snooze',
              ),
            ],
          ),
          child: _buildUpcomingTaskCard(
            title: item.title,
            scheduledTimeStr: _formatDate(item.scheduledTime),
            nextNotificationStr: nextNotifStr,
            icon: icon,
            color: color,
          ).animate().fadeIn(duration: 200.ms, delay: (index * 50).ms).slideX(begin: -0.1, end: 0, curve: Curves.easeOut),
        );
      },
    );
  }

  String _getUpcomingNextNotificationText(DateTime scheduledTime) {
    final diff = scheduledTime.difference(DateTime.now());
    if (diff.inMinutes > 15) {
      return 'Next reminder: 15 min before';
    } else if (diff.inMinutes > 5) {
      return 'Next reminder: 5 min before';
    } else if (diff.inMinutes > 1) {
      return 'Next reminder: 1 min before';
    } else if (diff.inMinutes > 0) {
      return 'Next notification in 1 minute';
    } else {
      return 'Starting now!';
    }
  }

  Widget _buildUpcomingTaskCard({
    required String title,
    required String scheduledTimeStr,
    required String nextNotificationStr,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161622),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.blueAccent, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(CupertinoIcons.clock, size: 13, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text(
                      scheduledTimeStr,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(CupertinoIcons.bell_fill, size: 11, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(
                        nextNotificationStr,
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white10),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.white38, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required String timeStr,
    required IconData icon,
    required Color color,
    bool isRead = true,
    bool isUpcoming = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white.withOpacity(0.02) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.white.withOpacity(0.05) : color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isRead ? FontWeight.w500 : FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (!isRead && !isUpcoming)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: isUpcoming ? Colors.blueAccent : Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForType(String type, String status) {
    if (status == 'MISSED') return Colors.redAccent;
    if (status == 'COMPLETED') return Colors.greenAccent;
    switch (type) {
      case 'ACHIEVEMENT': return Colors.amber;
      case 'STREAK': return Colors.orangeAccent;
      case 'GOAL': return Colors.purpleAccent;
      case 'REMINDER': default: return Colors.cyanAccent;
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'ACHIEVEMENT': return CupertinoIcons.star_fill;
      case 'STREAK': return CupertinoIcons.flame_fill;
      case 'GOAL': return CupertinoIcons.flag_fill;
      case 'ACTION': return CupertinoIcons.hand_draw_fill;
      case 'REMINDER': default: return CupertinoIcons.bell_fill;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final localNow = DateTime(now.year, now.month, now.day);
    final localDt = DateTime(dt.year, dt.month, dt.day);
    final dayDiff = localDt.difference(localNow).inDays;

    final timeStr = DateFormat.jm().format(dt.toLocal());
    final difference = now.difference(dt);

    if (dayDiff == 0) {
      return 'Today, $timeStr';
    } else if (dayDiff == 1) {
      return 'Tomorrow, $timeStr';
    } else if (dayDiff == -1) {
      return 'Yesterday, $timeStr';
    } else if (dayDiff > 1) {
      return DateFormat('MMM d, h:mm a').format(dt.toLocal());
    } else {
      // Past dates beyond yesterday
      if (difference.inMinutes < 1) return 'Just now';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
      if (difference.inHours < 24) return '${difference.inHours}h ago';
      if (difference.inDays < 7) return '${difference.inDays}d ago';
      return DateFormat('MMM d, h:mm a').format(dt.toLocal());
    }
  }
}
