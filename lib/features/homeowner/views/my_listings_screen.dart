import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:homiego/core/models/property.dart';
import 'package:homiego/widgets/property_box.dart';
import 'add_listing_screen.dart';
import 'package:homiego/features/homeowner/providers/booking_providers.dart'
    show homeownerProfileProvider, myListingsProvider;
// --- END CHANGES ---

// --- CHANGES ---
// REMOVED the entire myListingsProvider definition from this file.
// It now lives in 'booking_providers.dart'.
// --- END CHANGES ---

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // This 'watch' is now safe and will use the new RLS policy
    final listingsAsync = ref.watch(myListingsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Listing'),
        centerTitle: true,
        elevation: 0,
      ),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Failed to load your listings. Please try again later.\n\nError: $error', // Added error for debugging
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.red),
            ),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 36),
                child: Text(
                  "You have no listings. Tap '+' to create one!",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 18),
            itemBuilder: (ctx, idx) {
              final property = list[idx];

              // --- 1. GET THE IMAGE PATH ---
              // Get the first image path, or null if no images exist
              final String? imagePath = property.images.isNotEmpty
                  ? property.images.first.storagePath
                  : null;

              // --- 2. PASS THE PATH TO THE WIDGET ---
              return PropertyBox(
                imageUrl: imagePath, // <-- THE FIX
                name: property.title,
                location: property.address,
                rating: 5.0, // TODO: Aggregate from reviews
                reviewCount: 0, // TODO: Count real reviews
                price: property.pricePerNight,
                onTap: () {
                  // TODO: Go to property detail/edit page
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddListingScreen()),
          );
        },
        tooltip: 'Add Property',
        child: const Icon(Icons.add),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}