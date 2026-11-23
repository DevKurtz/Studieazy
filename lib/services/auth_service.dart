import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../config/supabase_config.dart';
import '../models/user_model.dart';

class AuthService {
  AuthCredential? _pendingGoogleCredential;
  String? _pendingGoogleEmail;
  String? get pendingGoogleEmail => _pendingGoogleEmail;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SupabaseClient get _supabase => Supabase.instance.client;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentFirebaseUser => _auth.currentUser;

  Future<UserModel?> getUserFromFirestore(
    String uid, {
    bool forceServer = false,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        final row = await _supabase.from('app_users').select().eq('id', uid).maybeSingle();
        if (row != null) return UserModel.fromFirestore(_profileFromRow(row));
      } catch (_) {
        // Keep the existing Firebase profile path available while Supabase is
        // unavailable or its schema/configuration needs attention.
      }
      // One-time profile migration for an existing Firebase account.
      final legacy = await _firestore.collection('users').doc(uid).get();
      if (legacy.exists && legacy.data() != null) {
        final user = UserModel.fromFirestore(legacy.data()!);
        try {
          await _saveUser(user);
        } catch (_) {
          // The existing Firestore profile remains readable if Supabase fails.
        }
        return user;
      }
      return null;
    }
    try {
      DocumentSnapshot<Map<String, dynamic>> doc;

      if (forceServer) {
        try {
          doc = await _firestore
              .collection('users')
              .doc(uid)
              .get(const GetOptions(source: Source.server))
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
              );
        } on FirebaseException {
          doc = await _firestore
              .collection('users')
              .doc(uid)
              .get()
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
              );
        }
      } else {
        doc = await _firestore
            .collection('users')
            .doc(uid)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
            );
      }

      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc.data()!);
      }
    } catch (e) {
      rethrow;
    }
    return null;
  }

  Future<UserModel?> signUp({
    required String email,
    required String password,
    required String name,
    int? age,
    String? school,
    String? gradeLevel,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final user = UserModel(
          id: result.user!.uid,
          email: email,
          name: name,
          age: age,
          school: school,
          gradeLevel: gradeLevel,
          createdAt: DateTime.now(),
          otpVerified: false,
        );

        await _saveUser(user);
        return user;
      }
    } on FirebaseAuthException catch (e) {
      throw '${_handleAuthError(e)} (code: ${e.code})';
    }
    return null;
  }

  Future<UserModel?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        UserModel? user;
        try {
          user = await getUserFromFirestore(
            result.user!.uid,
            forceServer: true,
          );
        } catch (_) {
          // Firebase has authenticated the user already. A profile read from
          // the optional Supabase store must not turn a valid login into an
          // apparent authentication failure (for example, when its ID column
          // still has a UUID type but Firebase UIDs are strings).
        }
        if (user != null) return user;

        final newUser = UserModel(
          id: result.user!.uid,
          email: email,
          name: result.user!.displayName ?? email.split('@')[0],
          createdAt: DateTime.now(),
          otpVerified: true,
        );

        try { await _saveUser(newUser); } catch (_) {}

        return newUser;
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
    return null;
  }

  Future<UserModel> linkGoogleToPasswordAccount({
    required String email,
    required String password,
  }) async {
    final credential = _pendingGoogleCredential;
    if (credential == null) throw 'Please retry Google sign-in, then connect your account.';
    final result = await _auth.signInWithEmailAndPassword(email: email, password: password);
    await result.user!.linkWithCredential(credential);
    _pendingGoogleCredential = null;
    _pendingGoogleEmail = null;
    final model = await getUserFromFirestore(result.user!.uid, forceServer: true);
    if (model != null) return model;
    final fallback = UserModel(
      id: result.user!.uid,
      email: result.user!.email ?? email,
      name: result.user!.displayName ?? email.split('@').first,
      createdAt: DateTime.now(),
      otpVerified: true,
    );
    await _saveUser(fallback);
    return fallback;
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) return null; // Cancelled by user
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }

      final User? fbUser = userCredential.user;
      if (fbUser != null) {
        UserModel? existingUser;
        try {
          existingUser = await getUserFromFirestore(
            fbUser.uid,
            forceServer: true,
          );
        } catch (_) {
          // Keep Google authentication successful if profile storage is
          // temporarily unavailable or has an incompatible legacy ID type.
        }
        if (existingUser != null) {
          if (!existingUser.otpVerified) {
            await markOtpVerified(existingUser.id);
          }
          return existingUser.copyWith(otpVerified: true);
        }

        // Fresh Google user — auto-verified since Google owns the email domain
        final newUser = UserModel(
          id: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ??
              (fbUser.email?.split('@').first ?? 'User'),
          profileImageUrl: fbUser.photoURL,
          createdAt: DateTime.now(),
          otpVerified: true,
          profileComplete: false,
        );

        try {
          await _saveUser(newUser);
        } catch (_) {
          // Profile persistence can be repaired independently; do not report
          // a failed login after Firebase has accepted the Google account.
        }

        return newUser;
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _pendingGoogleCredential = e.credential;
        _pendingGoogleEmail = e.email;
        throw 'This email already has a password account. Enter its password to connect Google sign-in.';
      }
      throw _handleAuthError(e);
    } catch (e) {
      throw e.toString();
    }
    return null;
  }

  Future<void> _saveUser(UserModel user) async {
    if (!SupabaseConfig.isConfigured) {
      await _firestore.collection('users').doc(user.id).set(user.toFirestore());
      return;
    }
    try {
      await _supabase.from('app_users').upsert(_profileToRow(user));
    } catch (_) {
      await _firestore.collection('users').doc(user.id).set(user.toFirestore());
    }
  }

  Future<void> completeGoogleAccount({
    required String name,
    required String password,
    int? age,
    String? school,
    String? gradeLevel,
  }) async {
    final fbUser = _auth.currentUser;
    if (fbUser == null || fbUser.email == null) {
      throw 'Google session expired. Please sign in again.';
    }
    final hasPasswordProvider = fbUser.providerData.any(
      (provider) => provider.providerId == EmailAuthProvider.PROVIDER_ID,
    );
    if (hasPasswordProvider) {
      await fbUser.updatePassword(password);
    } else {
      await fbUser.linkWithCredential(
        EmailAuthProvider.credential(email: fbUser.email!, password: password),
      );
    }
    final profile = await getUserFromFirestore(fbUser.uid) ?? UserModel(
      id: fbUser.uid,
      email: fbUser.email!,
      name: name,
      profileImageUrl: fbUser.photoURL,
      createdAt: DateTime.now(),
      otpVerified: true,
      profileComplete: false,
    );
    await _saveUser(profile.copyWith(
      name: name,
      age: age,
      school: school,
      gradeLevel: gradeLevel,
      otpVerified: true,
      profileComplete: true,
    ));
  }

  Map<String, dynamic> _profileToRow(UserModel user) => {
        'id': user.id, 'email': user.email.toLowerCase(), 'name': user.name,
        'profile_image_url': user.profileImageUrl,
        'profile_image_base64': user.profileImageBase64, 'age': user.age,
        'address': user.address, 'bio': user.bio, 'school': user.school,
        'grade_level': user.gradeLevel, 'created_at': user.createdAt.toIso8601String(),
        'last_synced_at': user.lastSyncedAt?.toIso8601String(),
        'last_active_at': user.lastActiveAt?.toIso8601String(),
        'otp_verified': user.otpVerified, 'streak_count': user.streakCount,
        'profile_complete': user.profileComplete,
        'last_streak_date': user.lastStreakDate, 'role': user.role,
      };

  Map<String, dynamic> _profileFromRow(Map<String, dynamic> row) => {
        'id': row['id'], 'email': row['email'], 'name': row['name'],
        'profileImageUrl': row['profile_image_url'],
        'profileImageBase64': row['profile_image_base64'], 'age': row['age'],
        'address': row['address'], 'bio': row['bio'], 'school': row['school'],
        'gradeLevel': row['grade_level'], 'createdAt': row['created_at'],
        'lastSyncedAt': row['last_synced_at'], 'lastActiveAt': row['last_active_at'],
        'otpVerified': row['otp_verified'], 'streakCount': row['streak_count'],
        'profileComplete': row['profile_complete'],
        'lastStreakDate': row['last_streak_date'], 'role': row['role'],
      };

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  /// Records the current timestamp as [lastActiveAt] for the given user.
  /// Fire-and-forget — callers should NOT await this.
  Future<void> updateLastActive(String uid) async {
    try {
      if (SupabaseConfig.isConfigured) {
        try {
          await _supabase.from('app_users').update({
            'last_active_at': DateTime.now().toIso8601String(),
          }).eq('id', uid);
          return;
        } catch (_) {
          // Fall through to Firebase as the existing fallback store.
        }
      }
      await _firestore.collection('users').doc(uid).update({
        'lastActiveAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Best-effort; ignore offline errors.
    }
  }

  /// Marks the given user's account as OTP-verified in Firestore.
  /// Called only after confirms the entered code
  /// is correct.
  Future<void> markOtpVerified(String uid) async {
    if (SupabaseConfig.isConfigured) {
      try {
        await _supabase.from('app_users').update({'otp_verified': true}).eq('id', uid);
        return;
      } catch (_) {
        // Preserve OTP completion through the already configured Firebase path.
      }
    }
    await _firestore.collection('users').doc(uid).set(
      {'otpVerified': true},
      SetOptions(merge: true),
    ).timeout(const Duration(seconds: 10), onTimeout: () => throw 'Connection timed out.');
  }

  /// Checks if a user with the given [email] exists in Firestore.
  Future<bool> checkEmailExists(String email) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final snap = await _firestore
          .collection('users')
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 5),
          );
      if (snap.docs.isNotEmpty) return true;

      final snapRaw = await _firestore
          .collection('users')
          .where('email', isEqualTo: email.trim())
          .limit(1)
          .get()
          .timeout(
            const Duration(seconds: 5),
          );
      return snapRaw.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        // Unauthenticated users may not query the users collection under Firestore rules.
        // Return true to allow sending the password reset OTP.
        return true;
      }
      rethrow;
    } catch (_) {
      return true;
    }
  }

  /// Sends a Firebase password reset email to [email].
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  /// Writes streak fields to Firestore without touching other profile data.
  Future<void> updateStreak({
    required String userId,
    required int streakCount,
    required String lastStreakDate,
  }) async {
    if (SupabaseConfig.isConfigured) {
      try {
        await _supabase.from('app_users').update({
          'streak_count': streakCount,
          'last_streak_date': lastStreakDate,
        }).eq('id', userId);
        return;
      } catch (_) {
        // Fall through to Firebase if Supabase rejects the request.
      }
    }
    await _firestore.collection('users').doc(userId).set(
      {'streakCount': streakCount, 'lastStreakDate': lastStreakDate},
      SetOptions(merge: true),
    ).timeout(const Duration(seconds: 8), onTimeout: () => throw 'Timeout');
  }

  Future<UserModel?> updateProfile({
    required String userId,
    String? name,
    int? age,
    String? address,
    String? bio,
    Uint8List? profileImageBytes,
  }) async {
    try {
      if (SupabaseConfig.isConfigured) {
        if (profileImageBytes != null && profileImageBytes.lengthInBytes > 600 * 1024) {
          throw 'Please choose a smaller profile photo.';
        }
        final updates = <String, dynamic>{
          if (name != null) 'name': name,
          if (age != null) 'age': age,
          if (address != null) 'address': address,
          if (bio != null) 'bio': bio,
          if (profileImageBytes != null)
            'profile_image_base64': base64Encode(profileImageBytes),
          'last_synced_at': DateTime.now().toIso8601String(),
        };
        try {
          final row = await _supabase.from('app_users').update(updates)
              .eq('id', userId).select().maybeSingle();
          if (row != null) return UserModel.fromFirestore(_profileFromRow(row));
        } catch (_) {
          // Continue through the existing Firebase profile update path.
        }
      }
      String? profileImageBase64;
      if (profileImageBytes != null) {
        // Firestore documents are limited to 1 MiB. The picker already
        // downscales the image, and this guard leaves room for base64 overhead
        // and the rest of the profile document.
        const maxAvatarBytes = 600 * 1024;
        if (profileImageBytes.lengthInBytes > maxAvatarBytes) {
          throw 'Please choose a smaller profile photo.';
        }
        profileImageBase64 = base64Encode(profileImageBytes);
      }

      final nowIso = DateTime.now().toIso8601String();
      final updates = <String, dynamic>{
        if (name != null) 'name': name,
        if (age != null) 'age': age,
        if (address != null) 'address': address,
        if (bio != null) 'bio': bio,
        if (profileImageBase64 != null)
          'profileImageBase64': profileImageBase64,
        'lastSyncedAt': nowIso,
      };

      try {
        await _firestore
            .collection('users')
            .doc(userId)
            .set(updates, SetOptions(merge: true))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw 'Connection timed out.',
            );
      } catch (firestoreError) {
        // If Firestore write fails (e.g. permission-denied during auto-login or offline),
        // try to fetch existing doc or fall back to constructing updated model locally.
        try {
          final doc = await _firestore.collection('users').doc(userId).get();
          if (doc.exists && doc.data() != null) {
            final merged = Map<String, dynamic>.from(doc.data()!);
            merged.addAll(updates);
            return UserModel.fromFirestore(merged);
          }
        } catch (_) {}

        // Construct local updated UserModel fallback
        final fbUser = _auth.currentUser;
        return UserModel(
          id: userId,
          email: fbUser?.email ?? '',
          name: name ?? fbUser?.displayName ?? 'Student',
          age: age,
          address: address,
          bio: bio,
          profileImageBase64: profileImageBase64,
          createdAt: DateTime.now(),
          otpVerified: true,
        );
      }

      // Read back the full user document. If it doesn't exist or is missing
      // required fields (from older accounts), create a minimal base doc.
      var userDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
          );
      if (!userDoc.exists || userDoc.data() == null) {
        final fbUser = _auth.currentUser;
        final base = <String, dynamic>{
          'id': userId,
          'email': fbUser?.email ?? '',
          'name':
              name ??
              fbUser?.displayName ??
              (fbUser?.email?.split('@').first ?? 'User'),
          'createdAt': DateTime.now().toIso8601String(),
          'otpVerified': true,
          ...updates,
        };
        await _firestore
            .collection('users')
            .doc(userId)
            .set(base, SetOptions(merge: true))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
            );
        userDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
            );
      }

      if (!userDoc.exists || userDoc.data() == null) return null;
      final data = userDoc.data()!;
      if (data['id'] == null ||
          data['email'] == null ||
          data['name'] == null ||
          data['createdAt'] == null) {
        final fbUser = _auth.currentUser;
        await _firestore
            .collection('users')
            .doc(userId)
            .set({
              'id': userId,
              'email': fbUser?.email ?? data['email'] ?? '',
              'name': data['name'] ?? name ?? fbUser?.displayName ?? 'User',
              'createdAt': data['createdAt'] ?? DateTime.now().toIso8601String(),
            }, SetOptions(merge: true))
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
            );
        userDoc = await _firestore
            .collection('users')
            .doc(userId)
            .get()
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => throw 'Connection timed out. Please check your internet connection or disable your ad blocker (e.g. Brave Shield, uBlock Origin) if it is blocking Firebase.',
            );
      }

      if (!userDoc.exists || userDoc.data() == null) return null;
      return UserModel.fromFirestore(userDoc.data()!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteAllUserData(String userId) async {
    try {
      if (SupabaseConfig.isConfigured) {
        await _supabase.from('quizzes').delete().eq('user_id', userId);
        await _supabase.from('support_tickets').delete().eq('user_id', userId);
        await _supabase.from('error_logs').delete().eq('user_id', userId);
        await _supabase.from('app_users').delete().eq('id', userId);
        return;
      }
      final quizzesSnapshot =
          await _firestore
              .collection('quizzes')
              .where('userId', isEqualTo: userId)
              .get();

      final List<DocumentReference<Map<String, dynamic>>> refsToDelete = [];
      for (final quizDoc in quizzesSnapshot.docs) {
        final questionsSnapshot =
            await _firestore
                .collection('questions')
                .where('quizId', isEqualTo: quizDoc.id)
                .get();

        for (final qDoc in questionsSnapshot.docs) {
          refsToDelete.add(qDoc.reference);
        }

        refsToDelete.add(quizDoc.reference);
      }

      refsToDelete.add(_firestore.collection('users').doc(userId));

      // Firestore write batch limit is 500. Keep a safe margin.
      const chunkSize = 450;
      for (var i = 0; i < refsToDelete.length; i += chunkSize) {
        final batch = _firestore.batch();
        final end =
            (i + chunkSize) > refsToDelete.length
                ? refsToDelete.length
                : (i + chunkSize);
        for (final ref in refsToDelete.sublist(i, end)) {
          batch.delete(ref);
        }
        await batch.commit();
      }
    } on FirebaseException catch (e) {
      // Surface the error so UI can display it.
      throw e.message ?? 'Failed to delete user data.';
    } catch (e) {
      throw 'Failed to delete user data.';
    }
  }

  /// Confirms password reset in Firebase Auth using the oobCode and sets the new password.
  Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-login-credentials':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'operation-not-allowed':
        return 'This sign-in provider is not enabled in Firebase Console. Please enable Google under Authentication > Sign-in method.';
      case 'unauthorized-domain':
        return 'Domain not authorized. Please add your domain to Firebase Console > Authentication > Settings > Authorized domains.';
      case 'popup-closed-by-user':
        return 'Sign-in cancelled (popup was closed).';
      case 'cancelled-popup-request':
        return 'Sign-in request was cancelled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'expired-action-code':
        return 'The password reset link/code has expired. Please request a new one.';
      case 'invalid-action-code':
        return 'Invalid reset link or code. Please check the email sent to your inbox.';
      default:
        return e.message != null && e.message!.isNotEmpty
            ? '${e.message} (${e.code})'
            : 'Authentication failed. (${e.code})';
    }
  }
}
