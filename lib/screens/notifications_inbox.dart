import 'package:flutter/material.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() => _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'History'),
            Tab(text: 'Upcoming'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Navigate to notification settings
            },
          )
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList(),
          _buildUpcomingList(),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    // This will eventually be powered by the SQLite 'reminders' table
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5, // Mock data count
      itemBuilder: (context, index) {
        return _buildNotificationCard(
          title: 'Drink Water',
          message: 'It has been 2 hours since your last glass.',
          timeStr: '2 hours ago',
          icon: Icons.water_drop,
          color: Colors.cyanAccent,
          isRead: index > 1,
        );
      },
    );
  }

  Widget _buildUpcomingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Mock data count
      itemBuilder: (context, index) {
        return _buildNotificationCard(
          title: 'Read 10 Pages',
          message: 'Daily habit reminder scheduled for 9:00 PM.',
          timeStr: 'Today, 9:00 PM',
          icon: Icons.menu_book,
          color: Colors.purpleAccent,
          isUpcoming: true,
        );
      },
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
        color: isRead ? Colors.white.withOpacity(0.03) : color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRead ? Colors.white12 : color.withOpacity(0.3),
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
                        decoration: const BoxDecoration(
                          color: Colors.blueAccent,
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
}
