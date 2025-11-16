import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/services/supabase_client.dart';
import 'package:homiego/core/utils/confirmation_dialog.dart';
import 'package:homiego/core/utils/show_snackbar.dart';
import 'package:homiego/widgets/property_box.dart';
import 'add_listing_screen.dart';
import 'package:homiego/features/homeowner/providers/booking_providers.dart'
    show myListingsProvider;

// State provider to manage the loading state of the delete button
final _isDeletingProvider = StateProvider<bool>((_) => false);

class MyListingsScreen extends ConsumerWidget {
  const MyListingsScreen({super.key});

  // Method to handle deleting a listing
  void _deleteListing(
    WidgetRef ref,
    BuildContext context,
    Property property,
  ) {
    // 1. Use the mandatory confirmation dialog with its CORRECT signature
    showConfirmationDialog(
      context: context,
      title: 'Delete Listing?',
      description:
          'Are you sure you want to delete "${property.title}"? This action cannot be undone.',
      button1Text: 'Cancel', // Your util uses button1 for TextButton
      button2Text: 'Delete', // Your util uses button2 for ElevatedButton
      button2Callback: () async {
        // 2. Put all delete logic inside the confirmation callback
        ref.read(_isDeletingProvider.notifier).state = true;

        try {
          // 3. Call Supabase delete from the provider
          await ref
              .read(supabaseClientProvider)
              .from('properties')
              .delete()
              .eq('id', property.id);

          // 4. Show success feedback
          if (context.mounted) {
            showSnackBar(context, 'Listing deleted successfully.');
          }

          // 5. Refresh the list of properties
          ref.invalidate(myListingsProvider);
        } catch (e) {
          // 6. Show error feedback
          if (context.mounted) {
            showSnackBar(context, 'Failed to delete listing: $e', isError: true);
          }
        } finally {
          // 7. Reset loading state
          if (ref.context.mounted) {
            ref.read(_isDeletingProvider.notifier).state = false;
          }
        }
      },
    );
  }

  // Helper widget for the action buttons
  Widget _buildActionRow(
    WidgetRef ref,
    // --- FIX: Corrected typo 'BuildContextContext' to 'BuildContext' ---
    BuildContext context,
    // --- END FIX ---
    Property property,
  ) {
    final isDeleting = ref.watch(_isDeletingProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // --- EDIT BUTTON ---
          IconButton(
            // --- FIX: Changed 'Icons.edit_outline' to 'Icons.edit' ---
            icon: const Icon(Icons.edit),
            // --- END FIX ---
            tooltip: 'Edit Listing',
            onPressed: () async {
              // Navigate to AddListingScreen in "Edit" mode
              final bool? didSave = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AddListingScreen(propertyToEdit: property),
                ),
              );

              // If the user saved changes, refresh the list
              if (didSave == true && context.mounted) {
                ref.invalidate(myListingsProvider);
              }
            },
          ),
          const SizedBox(width: 8),

          // --- DELETE BUTTON ---
          if (isDeleting)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              tooltip: 'Delete Listing',
              onPressed: () => _deleteListing(ref, context, property),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              'Failed to load your listings. Please try again later.\n\nError: $error',
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

              final String? imagePath = property.images.isNotEmpty
                  ? property.images.first.storagePath
                  : null;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PropertyBox(
                    imageUrl: imagePath,
                    name: property.title,
                    location: property.address,
                    rating: 5.0, // TODO: Aggregate from reviews
                    reviewCount: 0, // TODO: Count real reviews
                    price: property.pricePerNight,
                    onTap: () async {
                      final bool? didSave = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddListingScreen(propertyToEdit: property),
                        ),
                      );
                      if (didSave == true && context.mounted) {
                        ref.invalidate(myListingsProvider);
                      }
                    },
                  ),
                  _buildActionRow(ref, context, property),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? didSave = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddListingScreen()),
          );

          if (didSave == true && context.mounted) {
            ref.invalidate(myListingsProvider);
          }
        },
        tooltip: 'Add Property',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}