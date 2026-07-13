import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/social.dart';
import '../models/sync_item.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class SocialProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();
  final Uuid _uuid = const Uuid();

  List<SocialContact> _contacts = [];
  bool _isLoading = false;

  List<SocialContact> get contacts => _contacts;
  bool get isLoading => _isLoading;

  // Fetch all social contact details
  Future<void> fetchContacts(String userId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _contacts = await _dbService.getLocalSocialContacts(userId);
    } catch (e) {
      print("Error fetching contacts: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Sync in background
    try {
      await _syncService.sync(userId);
      _contacts = await _dbService.getLocalSocialContacts(userId);
      notifyListeners();
    } catch (_) {}
  }

  // Create friend contact profile
  Future<void> addContact(String userId, String name, DateTime lastContacted, String notes) async {
    final now = DateTime.now();
    final contact = SocialContact(
      id: _uuid.v4(),
      userId: userId,
      name: name,
      lastContacted: lastContacted,
      notes: notes,
      loggedAt: now,
      updatedAt: now,
    );

    // Write locally
    await _dbService.upsertLocalSocialContact(contact);
    _contacts.add(contact);
    notifyListeners();

    // Queue sync mutation
    final syncItem = SyncItem(
      actionType: 'INSERT',
      tableName: 'social_contacts',
      recordId: contact.id,
      payload: contact.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Sync remote
    _syncService.sync(userId).then((_) => fetchContacts(userId));
  }

  // Update contact date
  Future<void> updateContacted(String userId, String contactId, DateTime contactedDate) async {
    final index = _contacts.indexWhere((c) => c.id == contactId);
    if (index == -1) return;

    final existing = _contacts[index];
    final updated = SocialContact(
      id: existing.id,
      userId: existing.userId,
      name: existing.name,
      lastContacted: contactedDate,
      notes: existing.notes,
      loggedAt: existing.loggedAt,
      updatedAt: DateTime.now(),
    );

    // Write locally
    await _dbService.upsertLocalSocialContact(updated);
    _contacts[index] = updated;
    notifyListeners();

    // Queue sync mutation
    final syncItem = SyncItem(
      actionType: 'UPDATE',
      tableName: 'social_contacts',
      recordId: updated.id,
      payload: updated.toJson(),
    );
    await _dbService.queueMutation(syncItem);

    // Sync remote
    _syncService.sync(userId).then((_) => fetchContacts(userId));
  }

  // Check if any contact hasn't been contacted in 10 or more days
  bool get hasNeglectedContacts {
    final now = DateTime.now();
    for (final contact in _contacts) {
      final difference = now.difference(contact.lastContacted).inDays;
      if (difference >= 10) {
        return true;
      }
    }
    return false;
  }
}
