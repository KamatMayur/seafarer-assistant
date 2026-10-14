import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db.dart';
import '../data/models.dart';
import '../data/repositories.dart';
import '../domain/sea_time.dart';
import 'api_client.dart';
import 'config.dart';
import 'feedback.dart';
import 'file_vault.dart';
import 'notifications.dart';
import 'token_store.dart';

/// Overridden in main() (and in tests) with real instances.
final databaseProvider = Provider<AppDatabase>((ref) => throw UnimplementedError('override in main'));
final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());
final toastProvider = Provider<ToastService>((ref) => ToastService());
final fileVaultProvider = Provider<FileVault>((ref) => FileVault());

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: AppConfig.defaultApiBase, tokens: ref.watch(tokenStoreProvider));
  client.onSignedOut = () => ref.read(sessionProvider.notifier).signedOut();
  return client;
});

final authRepoProvider = Provider((ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));
final profileRepoProvider =
    Provider((ref) => ProfileRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));
final feedRepoProvider = Provider((ref) => FeedRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));
final documentRepoProvider =
    Provider((ref) => DocumentRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));
final feedbackProvider =
    Provider((ref) => FeedbackService(ref.watch(apiClientProvider), ref.watch(databaseProvider)));
final seaRepoProvider =
    Provider((ref) => SeaServiceRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));
final certRepoProvider =
    Provider((ref) => CertificateRepository(ref.watch(apiClientProvider), ref.watch(databaseProvider)));

// ------------------------------------------------------------------------------------------- session
enum SessionState { loading, signedOut, needsProfile, ready }

class SessionNotifier extends Notifier<SessionState> {
  @override
  SessionState build() {
    Future.microtask(restore);
    return SessionState.loading;
  }

  Future<void> restore() async {
    final api = ref.read(apiClientProvider);
    final db = ref.read(databaseProvider);
    final savedBase = await db.getValue('api_base');
    if (savedBase != null && savedBase.isNotEmpty) api.baseUrl = savedBase;
    if (!await ref.read(authRepoProvider).isSignedIn()) {
      state = SessionState.signedOut;
      return;
    }
    try {
      final p = await ref.read(profileRepoProvider).load();
      state = (p?.isComplete ?? false) ? SessionState.ready : SessionState.needsProfile;
    } catch (_) {
      // Server error but we have tokens: let the user in with cached data.
      final cached = await ref.read(profileRepoProvider).cached();
      state = (cached?.isComplete ?? true) ? SessionState.ready : SessionState.needsProfile;
    }
  }

  void signedIn({required bool profileComplete}) =>
      state = profileComplete ? SessionState.ready : SessionState.needsProfile;

  void profileSaved() => state = SessionState.ready;

  Future<void> signOut() async {
    await ref.read(authRepoProvider).signOut();
    await ref.read(fileVaultProvider).wipe();
    state = SessionState.signedOut;
  }

  void signedOut() => state = SessionState.signedOut;
}

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);

// ------------------------------------------------------------------------------------------- data
final metaProvider = FutureProvider<Meta>((ref) => ref.watch(profileRepoProvider).meta());

final profileProvider = FutureProvider<Profile?>((ref) async {
  ref.watch(sessionProvider);
  return ref.watch(profileRepoProvider).cached();
});

final dataSaverProvider = StreamProvider<bool>(
    (ref) => ref.watch(databaseProvider).watchValue('data_saver').map((v) => v == 'true'));

final feedItemsProvider = StreamProvider<List<FeedItem>>((ref) => ref.watch(feedRepoProvider).watch());

final certificatesProvider = StreamProvider<List<Certificate>>((ref) => ref.watch(certRepoProvider).watchAll());

final seaServiceProvider = StreamProvider<List<SeaService>>((ref) => ref.watch(seaRepoProvider).watchAll());

/// NRI-day thresholds with their citations (assets/nri_rules.json, decisions.md R15).
final nriRulesProvider = FutureProvider<NriRules>(
    (ref) async => NriRules.fromJson(jsonDecode(await rootBundle.loadString('assets/nri_rules.json')) as Map<String, dynamic>));

/// Last time the feed was synced with the server (shown as "Updated 5 min ago" / offline banner).
final lastSyncProvider = StreamProvider<DateTime?>((ref) => ref
    .watch(databaseProvider)
    .watchValue('feed_synced_at')
    .map((v) => v == null ? null : DateTime.tryParse(v)));

/// True after a refresh failed because the server could not be reached.
class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool offline) => state = offline;
}

final offlineProvider = NotifierProvider<OfflineNotifier, bool>(OfflineNotifier.new);
