import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../shared/providers/supabase_client_provider.dart';

class DriverAuthState {
  final User? supabaseUser;
  final bool isLoading;
  final String? errorMessage;

  const DriverAuthState({this.supabaseUser, this.isLoading = false, this.errorMessage});

  bool get isLoggedIn => supabaseUser != null;
}

class DriverAuthNotifier extends StateNotifier<DriverAuthState> {
  final SupabaseClient _supabase;
  StreamSubscription<AuthState>? _authSub;

  DriverAuthNotifier(this._supabase) : super(const DriverAuthState()) {
    _init();
  }

  void _init() {
    final user = _supabase.auth.currentUser;
    developer.log('_init: existing user = ${user?.id ?? "null"}', name: 'WASALLY_SYNC');
    state = DriverAuthState(supabaseUser: user);
    _authSub = _supabase.auth.onAuthStateChange.listen((authState) {
      developer.log('onAuthStateChange: event=${authState.event} session=${authState.session?.user.id ?? "null"} isLoading=${state.isLoading}', name: 'WASALLY_SYNC');
      // Preserve isLoading during active signIn/signUp to avoid overwriting the flag
      if (!state.isLoading) {
        state = DriverAuthState(supabaseUser: authState.session?.user);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  User? get currentSupabaseUser => state.supabaseUser;

  Stream<AuthState> get authState => _supabase.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    developer.log('signIn: START isLoading=true', name: 'WASALLY_SYNC');
    state = DriverAuthState(supabaseUser: state.supabaseUser, isLoading: true);
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      developer.log('signIn: after signInWithPassword user=${user?.id ?? "null"}', name: 'WASALLY_SYNC');
      if (user == null) throw Exception('فشل تسجيل الدخول');
      final profile = await _getProfile(user.id);
      if (profile == null) throw Exception('لم يتم العثور على بيانات المستخدم');
      if (profile['role'] != 'driver') {
        await _supabase.auth.signOut();
        throw Exception('هذا الحساب ليس لحساب سائق');
      }
      developer.log('signIn: SUCCESS setting state isLoading=false', name: 'WASALLY_SYNC');
      state = DriverAuthState(supabaseUser: user);
    } catch (e) {
      developer.log('signIn: ERROR $e', name: 'WASALLY_SYNC');
      state = DriverAuthState(supabaseUser: state.supabaseUser, errorMessage: _mapAuthError(e));
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String fullName, String phone) async {
    state = DriverAuthState(supabaseUser: state.supabaseUser, isLoading: true);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName, 'role': 'driver'},
      );
      final user = response.user;
      if (user == null) throw Exception('فشل إنشاء الحساب');
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'full_name': fullName,
        'phone_number': phone,
        'role': 'driver',
      });
      state = DriverAuthState(supabaseUser: user);
    } catch (e) {
      state = DriverAuthState(supabaseUser: state.supabaseUser, errorMessage: _mapAuthError(e));
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
    state = const DriverAuthState();
  }

  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    try {
      return await _supabase.from('profiles').select().eq('id', userId).single();
    } catch (_) {
      return null;
    }
  }

  String _mapAuthError(Object error) {
    final message = error.toString();
    if (message.contains('Email not confirmed') || message.contains('email_not_confirmed')) {
      return 'يرجى تأكيد البريد الإلكتروني أولاً';
    }
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('User already registered')) {
      return 'البريد الإلكتروني مسجل بالفعل';
    }
    if (message.contains('rate_limit')) {
      return 'طلبات كثيرة جداً، حاول بعد قليل';
    }
    return 'حدث خطأ، حاول مرة أخرى';
  }

  Future<void> updateProfile({String? fullName, String? phoneNumber, String? address}) async {
    final user = state.supabaseUser;
    if (user == null) throw Exception('لا يوجد مستخدم');
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (address != null) data['address'] = address;
    await _supabase.from('profiles').update(data).eq('id', user.id);
  }

  Future<void> updateFcmToken(String token) async {
    final user = state.supabaseUser;
    if (user == null) throw Exception('لا يوجد مستخدم');
    await _supabase.from('profiles').update({'fcm_token': token}).eq('id', user.id);
  }

  Future<void> sendPasswordReset(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  bool isEmailConfirmed() {
    return state.supabaseUser?.emailConfirmedAt != null;
  }
}

final driverAuthProvider = StateNotifierProvider<DriverAuthNotifier, DriverAuthState>((ref) {
  return DriverAuthNotifier(ref.read(supabaseClientProvider));
});
