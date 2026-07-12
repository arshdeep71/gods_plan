import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _supabaseService = SupabaseService();
  final DatabaseService _dbService = DatabaseService();

  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    _user = _supabaseService.currentUser;
  }

  // Getters
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Clear current error state
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Log in existing user
  Future<bool> logIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabaseService.logIn(email: email, password: password);
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during login. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Sign up new user
  Future<bool> signUp(String email, String password, String username) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabaseService.signUp(
        email: email,
        password: password,
        username: username,
      );
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred during registration.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Log out current user
  Future<void> logOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _supabaseService.logOut();
      await _dbService.clearLocalCache();
      _user = null;
    } catch (e) {
      // Log errors locally, but still clear memory session
      _user = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
