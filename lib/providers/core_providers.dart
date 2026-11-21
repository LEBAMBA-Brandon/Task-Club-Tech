import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/network/api_client.dart';
import '../core/storage/cache_storage.dart';
import '../core/storage/secure_storage.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/meta_repository.dart';
import '../data/repositories/task_repository.dart';

/// Instance de SharedPreferences, injectée dans main() (ProviderScope.overrides).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider doit être surchargé dans main()'),
);

/// Jeton courant gardé en mémoire (lu par l'intercepteur Dio à chaque requête).
class TokenHolder {
  String? token;
}

final tokenHolderProvider = Provider<TokenHolder>((ref) => TokenHolder());

final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());

final cacheStorageProvider = Provider<CacheStorage>((ref) => CacheStorage(ref.watch(sharedPreferencesProvider)));

final apiClientProvider = Provider<ApiClient>((ref) {
  final holder = ref.watch(tokenHolderProvider);
  return ApiClient(tokenReader: () => holder.token);
});

// ----- Repositories (couche données)

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository(
      ref.watch(apiClientProvider),
      ref.watch(secureStorageProvider),
      ref.watch(cacheStorageProvider),
    ));

final metaRepositoryProvider =
    Provider<MetaRepository>((ref) => MetaRepository(ref.watch(apiClientProvider), ref.watch(cacheStorageProvider)));

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) => TaskRepository(ref.watch(apiClientProvider), ref.watch(cacheStorageProvider)));
