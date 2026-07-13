import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../utils/colors.dart';

class SocialView extends StatefulWidget {
  const SocialView({super.key});

  @override
  State<SocialView> createState() => _SocialViewState();
}

class _SocialViewState extends State<SocialView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      if (user != null) {
        Provider.of<SocialProvider>(context, listen: false).fetchContacts(user.id);
      }
    });
  }

  void _showAddFriendDialog() {
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text(
            "Add Friend Profile",
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: "Friend's Name",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                  ),
                  validator: (v) => v == null || v.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notesController,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: "Relationship Notes",
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final user = Provider.of<AuthProvider>(context, listen: false).user;
                  if (user != null) {
                    Provider.of<SocialProvider>(context, listen: false).addContact(
                      user.id,
                      nameController.text,
                      DateTime.now(),
                      notesController.text,
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showInteractionOptions(String friendId, String name) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final activities = [
          {"label": "Called friend", "icon": Icons.phone_rounded},
          {"label": "Video call", "icon": Icons.video_call_rounded},
          {"label": "In-person meet", "icon": Icons.people_rounded},
          {"label": "Group hangout", "icon": Icons.group_rounded},
          {"label": "Sent message", "icon": Icons.message_rounded},
          {"label": "Attended event", "icon": Icons.event_rounded},
        ];

        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Log Activity with $name",
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: activities.length,
                  itemBuilder: (context, idx) {
                    final act = activities[idx];
                    return ListTile(
                      leading: Icon(act["icon"] as IconData, color: AppColors.accent),
                      title: Text(act["label"] as String, style: const TextStyle(color: AppColors.textPrimary)),
                      onTap: () {
                        final user = Provider.of<AuthProvider>(context, listen: false).user;
                        if (user != null) {
                          Provider.of<SocialProvider>(context, listen: false).updateContacted(
                            user.id,
                            friendId,
                            DateTime.now(),
                          );
                        }
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Activity '${act['label']}' logged with $name!"),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SocialProvider>();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: const Text(
          "Social & Friends",
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Social Status Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Friend Contacts Log",
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: _showAddFriendDialog,
                        icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.accent, size: 28),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  if (provider.contacts.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        "No contacts added yet. Tap '+' to create friend profiles.",
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: provider.contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final friend = provider.contacts[index];
                        final difference = now.difference(friend.lastContacted).inDays;
                        final isNeglected = difference >= 10;

                        return Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isNeglected ? Colors.redAccent.withOpacity(0.5) : AppColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Avatar / Neglect Badge
                              Stack(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isNeglected
                                        ? Colors.redAccent.withOpacity(0.1)
                                        : AppColors.accent.withOpacity(0.1),
                                    radius: 28,
                                    child: Icon(
                                      Icons.person,
                                      color: isNeglected ? Colors.redAccent : AppColors.accent,
                                      size: 30,
                                    ),
                                  ),
                                  if (isNeglected)
                                    const Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 16),

                              // Info Details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.name,
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      difference == 0
                                          ? "Last contact: Today"
                                          : difference == 1
                                              ? "Last contact: Yesterday"
                                              : "Last contact: $difference days ago",
                                      style: TextStyle(
                                        color: isNeglected ? Colors.redAccent : AppColors.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    if (isNeglected) ...[
                                      const SizedBox(height: 4),
                                      const Text(
                                        "⚠️ Haven't talked in a while",
                                        style: TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              // Log Action button
                              IconButton(
                                style: IconButton.styleFrom(
                                  backgroundColor: AppColors.border,
                                  padding: const EdgeInsets.all(12),
                                ),
                                onPressed: () => _showInteractionOptions(friend.id, friend.name),
                                icon: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  color: AppColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
