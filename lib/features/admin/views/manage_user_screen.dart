import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/profile.dart';
import 'package:homiego/features/admin/providers/admin_providers.dart';
import 'package:homiego/features/admin/views/user_detail_screen.dart';

class ManageUserScreen extends ConsumerStatefulWidget {
  const ManageUserScreen({super.key});

  @override
  ConsumerState<ManageUserScreen> createState() => _ManageUserScreenState();
}

class _ManageUserScreenState extends ConsumerState<ManageUserScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        automaticallyImplyLeading: false,
      ),
      body: _ViewAllUsersTab(
        searchController: _searchController,
        searchQuery: _searchQuery,
        onSearchChanged: _onSearchChanged,
      ),
    );
  }
}

// Provider for filtered profiles with memoization
final filteredProfilesProvider = Provider.family<AsyncValue<List<Profile>>, String>((ref, searchQuery) {
  final allProfilesAsync = ref.watch(allProfilesProvider);
  
  return allProfilesAsync.when(
    data: (profiles) {
      if (searchQuery.isEmpty) {
        return AsyncValue.data(profiles);
      }
      
      final query = searchQuery.toLowerCase();
      final filtered = profiles.where((profile) {
        return (profile.fullName?.toLowerCase().contains(query) ?? false) ||
            (profile.contactNo?.toLowerCase().contains(query) ?? false) ||
            (profile.location?.toLowerCase().contains(query) ?? false) ||
            (profile.shortBio?.toLowerCase().contains(query) ?? false) ||
            profile.role.name.toLowerCase().contains(query);
      }).toList();
      
      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
});

class _ViewAllUsersTab extends ConsumerWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;

  const _ViewAllUsersTab({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filteredProfilesAsync = ref.watch(filteredProfilesProvider(searchQuery));

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Search users...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),

        // Users List
        Expanded(
          child: filteredProfilesAsync.when(
            data: (filteredProfiles) {
              if (filteredProfiles.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        searchQuery.isNotEmpty
                            ? 'No users found'
                            : 'No users available',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredProfiles.length,
                cacheExtent: 500, // Cache more items for smoother scrolling
                itemBuilder: (context, index) {
                  final profile = filteredProfiles[index];
                  return _UserCard(
                    key: ValueKey(profile.id), // Use stable key for better performance
                    profile: profile,
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading users',
                    style: TextStyle(fontSize: 18, color: Colors.red[700]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(allProfilesProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final Profile profile;

  const _UserCard({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    final isVerified = profile.isVerified;
    final fullName = profile.fullName ?? 'No Name';
    final location = profile.location;
    final roleName = profile.role.name.toUpperCase();
    final avatarUrl = profile.avatarUrl;
    final initial = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserDetailScreen(profile: profile),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.grey[300],
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null
                    ? Text(
                        initial,
                        style: const TextStyle(fontSize: 24),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Chip(
                          label: Text(
                            roleName,
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.blue[100],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            isVerified ? 'VERIFIED' : 'PENDING',
                            style: const TextStyle(fontSize: 10),
                          ),
                          backgroundColor: isVerified
                              ? Colors.green[100]
                              : Colors.orange[100],
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ],
                    ),
                    if (location != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }
}
