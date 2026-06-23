-- Supabase Auth Integration Guide
-- Document: SUPABASE_AUTH_SETUP.md
-- Purpose: Guide for implementing Supabase Auth in the Pengawasan Kelas application

# Supabase Auth Setup & Integration Guide

## Overview
This guide explains how to set up Supabase Authentication and integrate it with the Pengawasan Kelas Flutter application.

## Architecture

```
Flutter App
    ↓
Supabase Auth (JWT tokens)
    ↓
Supabase PostgreSQL (RLS policies check auth.uid())
```

## Part 1: Supabase Auth Configuration

### Step 1.1: Enable Auth Providers

1. **Go to Supabase Dashboard** → **Authentication** → **Providers**
2. **Enable Email/Password**:
   - Toggle "Enable Email" ON
   - Set "Confirm email" to your preference (required for production)
   - Configure email templates

3. **Enable (Optional) OAuth Providers**:
   - Google
   - GitHub
   - Microsoft
   - etc.

### Step 1.2: Auth Settings

1. **Authentication** → **Settings**
2. **Site URL**: Set to your app domain
3. **Redirect URLs**: Add valid redirect URIs
   ```
   http://localhost:5173
   https://yourdomain.com
   ```
4. **JWT Settings**:
   - Expiration: 3600 seconds (1 hour) - default
   - Refresh token expiration: 604800 seconds (7 days)
   - External URL: Keep default

### Step 1.3: Email Configuration

1. **Email** → **Email Templates**
2. Customize:
   - Confirmation email
   - Recovery email
   - Invite email
   - Magic link email

## Part 2: Update Flutter App

### Step 2.1: Update supabase_config.dart

```dart
class SupabaseConfig {
  const SupabaseConfig._();

  // Supabase Project Details
  static const String projectUrl = 'https://YOUR_PROJECT_ID.supabase.co';
  static const String publishableKey = 'YOUR_SUPABASE_ANON_KEY';
  static const String storageBucket = 'YOUR_STORAGE_BUCKET';

  // Auth Settings
  static const String redirectUrl = 'io.supabase.pengawasan://callback'; // Deep link
  static const bool emailConfirmationRequired = true; // Set to false for testing
}
```

### Step 2.2: Initialize Supabase in main.dart

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    anonKey: SupabaseConfig.publishableKey,
    // Optional: Deep link for redirect
    authCallbackUrlHostname: 'supabase.pengawasan',
    debug: true, // Set to false in production
  );

  runApp(const MyApp());
}
```

### Step 2.3: Create AuthService

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../../models/user_model.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  // Get current user
  User? get currentUser => _client.auth.currentUser;

  // Get current session
  Session? get currentSession => _client.auth.currentSession;

  // Listen to auth changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Sign up with email and password
  /// Creates user in Supabase Auth, also inserts record in users table
  Future<UserModel> signUp({
    required String email,
    required String password,
    required String nama,
    required String nip,
  }) async {
    try {
      // 1. Create auth user
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'nama': nama,
          'nip': nip,
        },
      );

      if (res.user == null) {
        throw Exception('Failed to create auth user');
      }

      // 2. Create user record in users table
      await _client.from('users').insert({
        'id': res.user!.id,
        'email': email,
        'nama': nama,
        'nip': nip,
        'updated_at': DateTime.now().toIso8601String(),
      });

      return UserModel.fromJson(res.user!.id, {
        'email': email,
        'nama': nama,
        'nip': nip,
      });
    } on AuthException catch (e) {
      throw Exception('Sign up error: ${e.message}');
    }
  }

  /// Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        throw Exception('Sign in failed');
      }

      // Fetch user details from users table
      final userRow = await _client
          .from('users')
          .select()
          .eq('id', res.user!.id)
          .single();

      return UserModel.fromJson(res.user!.id, userRow);
    } on AuthException catch (e) {
      throw Exception('Sign in error: ${e.message}');
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw Exception('Sign out error: $e');
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw Exception('Password reset error: ${e.message}');
    }
  }

  /// Update password
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
    } on AuthException catch (e) {
      throw Exception('Password update error: ${e.message}');
    }
  }

  /// Get user role
  Future<String?> getUserRole() async {
    if (currentUser == null) return null;

    try {
      final roles = await _client
          .from('user_roles')
          .select('role')
          .eq('user_id', currentUser!.id)
          .eq('is_deleted', false);

      if (roles.isNotEmpty) {
        return roles.first['role'];
      }
      return null;
    } catch (e) {
      print('Error fetching user role: $e');
      return null;
    }
  }

  /// Check if user has specific role
  Future<bool> hasRole(String role) async {
    if (currentUser == null) return false;

    try {
      final result = await _client
          .from('user_roles')
          .select()
          .eq('user_id', currentUser!.id)
          .eq('role', role)
          .eq('is_deleted', false);

      return result.isNotEmpty;
    } catch (e) {
      print('Error checking role: $e');
      return false;
    }
  }

  /// Verify email
  Future<void> verifyEmail(String token, String type) async {
    try {
      await _client.auth.verifyOTP(
        email: currentUser!.email!,
        token: token,
        type: OtpType.signup,
      );
    } on AuthException catch (e) {
      throw Exception('Email verification error: ${e.message}');
    }
  }
}
```

### Step 2.4: Create Riverpod Auth Provider

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../../models/user_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

// Current user state
final currentUserProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((state) => state.session?.user);
});

// Current auth session
final currentSessionProvider = StreamProvider<Session?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges.map((state) => state.session);
});

// User role state
final userRoleProvider = FutureProvider<String?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserRole();
});

// Sign in notifier
final signInProvider = FutureProvider.family<UserModel, (String, String)>(
  (ref, args) async {
    final authService = ref.watch(authServiceProvider);
    final (email, password) = args;
    return await authService.signIn(email: email, password: password);
  },
);

// Sign up notifier
final signUpProvider = FutureProvider.family<UserModel, Map<String, String>>(
  (ref, data) async {
    final authService = ref.watch(authServiceProvider);
    return await authService.signUp(
      email: data['email']!,
      password: data['password']!,
      nama: data['nama']!,
      nip: data['nip']!,
    );
  },
);
```

### Step 2.5: Update Login Screen

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Login'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (mounted) {
        // Navigate to home screen
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
```

## Part 3: User Management

### Step 3.1: Import Existing Firebase Users

If migrating from Firebase, use this script to import users:

```bash
#!/bin/bash
# scripts/import_users_from_firebase.sh

PROJECT_ID="smp-1-jenar-testing-5c904"

# Export Firebase users
firebase auth:export users.json --project $PROJECT_ID

# Convert to Supabase format and import
# (Manual import through Supabase dashboard or API)
```

### Step 3.2: Create User with Role

```dart
Future<void> createUserWithRole({
  required String email,
  required String password,
  required String nama,
  required String role, // 'guru', 'siswa', 'kepsek', 'kemahasiswaan'
}) async {
  final authService = ref.read(authServiceProvider);
  
  // 1. Create auth user
  final user = await authService.signUp(
    email: email,
    password: password,
    nama: nama,
    nip: '', // For non-guru roles
  );

  // 2. Assign role
  await _client.from('user_roles').insert({
    'user_id': user.id,
    'role': role,
  });

  // 3. Create role-specific record (guru, siswa)
  if (role == 'guru') {
    await _client.from('guru').insert({
      'user_id': user.id,
      'nama_guru': nama,
    });
  } else if (role == 'siswa') {
    await _client.from('siswa').insert({
      'user_id': user.id,
      'nama_siswa': nama,
    });
  }
}
```

## Part 4: Security Best Practices

### JWT Token Handling
```dart
// Supabase automatically handles JWT tokens
// - Stored in secure storage
// - Automatically refreshed
// - Sent with every request

// No manual token management needed!
```

### Password Security
- ✅ Minimum 6 characters (configurable in Supabase)
- ✅ Hashed with bcrypt
- ✅ Never stored in plaintext
- ✅ Use secure password reset flow

### Email Verification
```dart
// Require email confirmation for new signups
const bool emailConfirmationRequired = true;

// Users must click link in email before account is active
```

### Session Management
```dart
// Auto logout on token expiration
ref.listen(currentSessionProvider, (previous, next) {
  if (next == null) {
    // User logged out
    Navigator.of(context).pushReplacementNamed('/login');
  }
});
```

## Part 5: Testing

### Unit Tests
```dart
test('Sign in with valid credentials', () async {
  final authService = AuthService();
  
  // Test user should exist in Supabase
  final user = await authService.signIn(
    email: 'test@example.com',
    password: 'password123',
  );
  
  expect(user.email, 'test@example.com');
});

test('Sign in with invalid password fails', () async {
  final authService = AuthService();
  
  expect(
    () => authService.signIn(
      email: 'test@example.com',
      password: 'wrongpassword',
    ),
    throwsException,
  );
});
```

### Integration Tests
```dart
// Test actual Supabase instance
testWidgets('Login flow works end-to-end', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  // Find and fill login form
  await tester.enterText(find.byType(TextField).at(0), 'guru@school.com');
  await tester.enterText(find.byType(TextField).at(1), 'password123');
  
  // Tap login
  await tester.tap(find.byType(ElevatedButton));
  await tester.pumpAndSettle();
  
  // Verify navigation to home
  expect(find.text('Home'), findsOneWidget);
});
```

## Part 6: Troubleshooting

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| "Invalid login credentials" | User doesn't exist or wrong password | Verify user exists in Supabase, check password |
| "Email not confirmed" | User hasn't clicked confirmation link | Resend confirmation email |
| "JWT expired" | Token expired | Auto-handled by Supabase, should auto-refresh |
| "User already exists" | Signup with existing email | Use different email or password reset |
| "Network timeout" | Slow connection | Retry request, check internet |

### Debug Mode
```dart
// Enable debug logging
Supabase.instance.client.rest.headers['X-Debug'] = 'true';

// View auth state changes
Supabase.instance.client.auth.onAuthStateChange.listen((event) {
  print('Auth event: ${event.event}');
  print('Session: ${event.session}');
});
```

## Next Steps

1. **Test Auth Flow**: Verify sign-up and sign-in work
2. **Implement RLS Policies**: Enforce role-based access
3. **Set up Email Templates**: Customize confirmation emails
4. **Configure OAuth** (if needed): Add social login providers
5. **User Management UI**: Create admin panel for user management
