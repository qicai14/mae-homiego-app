import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/providers/comparison_provider.dart';
import 'package:homiego/core/services/property_service.dart';
import 'package:homiego/core/constants/app_constants.dart';
import 'package:homiego/features/tenant/views/property_detail_screen.dart';

class ComparisonBottomSheet extends ConsumerStatefulWidget {
  final Property currentProperty;

  const ComparisonBottomSheet({
    super.key,
    required this.currentProperty,
  });

  @override
  ConsumerState<ComparisonBottomSheet> createState() => _ComparisonBottomSheetState();
}

class _ComparisonBottomSheetState extends ConsumerState<ComparisonBottomSheet> {
  Map<int, List<String>> _propertyImages = {};
  Map<int, double> _propertyRatings = {};
  Map<int, int> _propertyReviewCounts = {};

  @override
  void initState() {
    super.initState();
    _loadPropertyData();
  }

  Future<void> _loadPropertyData() async {
    final comparisonState = ref.read(comparisonProvider);
    
    final propertiesToLoad = <Property>[];
    if (comparisonState.slot1 != null) propertiesToLoad.add(comparisonState.slot1!);
    if (comparisonState.slot2 != null) propertiesToLoad.add(comparisonState.slot2!);
    if (!propertiesToLoad.contains(widget.currentProperty)) {
      propertiesToLoad.add(widget.currentProperty);
    }

    for (final property in propertiesToLoad) {
      try {
        final results = await Future.wait([
          PropertyService.getPropertyImages(property.id),
          PropertyService.getPropertyRating(property.id),
        ]);

        if (mounted) {
          setState(() {
            _propertyImages[property.id] = results[0] as List<String>;
            final ratingData = results[1] as Map<String, dynamic>;
            _propertyRatings[property.id] = ratingData['rating'] as double;
            _propertyReviewCounts[property.id] = ratingData['reviewCount'] as int;
          });
        }
      } catch (e) {
        // Silently fail - will show placeholder
      }
    }
  }

  void _handleSlotTap(int slotIndex, Property? existingProperty) {
    final notifier = ref.read(comparisonProvider.notifier);
    
    // Don't allow same property in both slots
    if (slotIndex == 1 && ref.read(comparisonProvider).slot2?.id == widget.currentProperty.id || 
    slotIndex == 2 && ref.read(comparisonProvider).slot1?.id == widget.currentProperty.id) {
      return;
    }

    if (existingProperty != null && existingProperty.id == widget.currentProperty.id) {
      // Already in this slot, no need to change
      return;
    }

    notifier.setSlot(slotIndex, widget.currentProperty);
    _loadPropertyData(); // Reload data for the new property
  }

  @override
  Widget build(BuildContext context) {
    final comparisonState = ref.watch(comparisonProvider);

    return Container(
      padding: const EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Compare Properties',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Comparison Slots
          Row(
            children: [
              Expanded(
                child: _buildSlot(
                  slotIndex: 1,
                  property: comparisonState.slot1,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSlot(
                  slotIndex: 2,
                  property: comparisonState.slot2,
                ),
              ),
            ],
          ),
          
          // Comparison Table (only show if at least one slot has property)
          if (!comparisonState.isEmpty) ...[
            const SizedBox(height: 32),
            _buildComparisonTable(comparisonState),
          ] else ...[
            // Add padding when empty to prevent cut-off
            const SizedBox(height: 600),
          ],
          
          // Bottom padding to ensure content isn't cut off
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom
                : 0,
          ),
        ],
      ),
    );
  }

  Widget _buildSlot({required int slotIndex, required Property? property}) {
    return InkWell(
      onTap: () => _handleSlotTap(slotIndex, property),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: property == null
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_circle_outline, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 8),
                  Text(
                    'Tap to add property',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _propertyImages[property.id]?.isNotEmpty == true
                          ? _propertyImages[property.id]!.first
                          : '',
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 120,
                        color: Colors.grey.shade200,
                        child: Icon(Icons.image_not_supported, color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Property Name
                  Text(
                    property.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                   const SizedBox(height: 8),
                   // Remove Button
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton.icon(
                       onPressed: () {
                         ref.read(comparisonProvider.notifier).removeFromSlot(slotIndex);
                       },
                       icon: const Icon(Icons.close, size: 16),
                       label: const Text('Remove'),
                       style: OutlinedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 8),
                       ),
                     ),
                   ),
                   const SizedBox(height: 8),
                   // Book Button
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       onPressed: () {
                         Navigator.pop(context); // Close the comparison sheet
                         
                         // Remove current PropertyDetailScreen from navigation stack if it exists
                         // This prevents back button from going to previous property detail page
                         // After popping the comparison sheet, if we can still pop, 
                         // it means there's a PropertyDetailScreen below that we should remove
                         if (Navigator.canPop(context)) {
                           Navigator.pop(context); // Remove the PropertyDetailScreen we came from
                         }
                         
                         // Now push the new property detail screen
                         Navigator.push(
                           context,
                           MaterialPageRoute(
                             builder: (context) => PropertyDetailScreen(property: property),
                           ),
                         );
                       },
                       label: const Text('Book'),
                       style: ElevatedButton.styleFrom(
                         padding: const EdgeInsets.symmetric(vertical: 8),
                       ),
                     ),
                   ),
                ],
              ),
      ),
    );
  }

  Widget _buildComparisonTable(ComparisonState state) {
    final slot1 = state.slot1;
    final slot2 = state.slot2;

    // Collect all unique amenities from both properties
    final allAmenities = <String>{};
    if (slot1 != null) allAmenities.addAll(slot1.amenities);
    if (slot2 != null) allAmenities.addAll(slot2.amenities);
    final sortedAmenities = allAmenities.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Comparison',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              // Header row
              _buildTableRow(
                label: 'Property',
                slot1Value: slot1?.title ?? '—',
                slot2Value: slot2?.title ?? '—',
                isHeader: true,
              ),
              _buildDivider(),
              // Price
              _buildTableRow(
                label: 'Price per Night',
                slot1Value: slot1 != null ? 'RM ${slot1.pricePerNight.toStringAsFixed(2)}' : '—',
                slot2Value: slot2 != null ? 'RM ${slot2.pricePerNight.toStringAsFixed(2)}' : '—',
              ),
              _buildDivider(),
              // Location
              _buildTableRow(
                label: 'Location',
                slot1Value: slot1?.address ?? '—',
                slot2Value: slot2?.address ?? '—',
              ),
              _buildDivider(),
              // Property Type
              _buildTableRow(
                label: 'Property Type',
                slot1Value: slot1?.propertyType ?? '—',
                slot2Value: slot2?.propertyType ?? '—',
              ),
              _buildDivider(),
              // Max Guests
              _buildTableRow(
                label: 'Max Guests',
                slot1Value: slot1 != null ? '${slot1.maxGuest}' : '—',
                slot2Value: slot2 != null ? '${slot2.maxGuest}' : '—',
              ),
              _buildDivider(),
              // Rating
              _buildTableRow(
                label: 'Rating',
                slot1Value: slot1 != null && _propertyRatings.containsKey(slot1.id)
                    ? '${_propertyRatings[slot1.id]!.toStringAsFixed(1)} (${_propertyReviewCounts[slot1.id] ?? 0} reviews)'
                    : '—',
                slot2Value: slot2 != null && _propertyRatings.containsKey(slot2.id)
                    ? '${_propertyRatings[slot2.id]!.toStringAsFixed(1)} (${_propertyReviewCounts[slot2.id] ?? 0} reviews)'
                    : '—',
              ),
              _buildDivider(),
              // Cleaning Fee
              _buildTableRow(
                label: 'Cleaning Fee',
                slot1Value: slot1 != null ? 'RM ${slot1.cleaningFee.toStringAsFixed(2)}' : '—',
                slot2Value: slot2 != null ? 'RM ${slot2.cleaningFee.toStringAsFixed(2)}' : '—',
              ),
              _buildDivider(),
              // Service Fee
              _buildTableRow(
                label: 'Service Fee',
                slot1Value: slot1 != null ? 'RM ${slot1.serviceFee.toStringAsFixed(2)}' : '—',
                slot2Value: slot2 != null ? 'RM ${slot2.serviceFee.toStringAsFixed(2)}' : '—',
              ),
              _buildDivider(),
              // Verified Status
              _buildTableRow(
                label: 'Verified',
                slot1Value: slot1?.verified == true ? 'Yes' : slot1 != null ? 'No' : '—',
                slot2Value: slot2?.verified == true ? 'Yes' : slot2 != null ? 'No' : '—',
              ),
               _buildDivider(),
               // Amenities Section
               if (sortedAmenities.isNotEmpty) ...[
                 Container(
                   padding: const EdgeInsets.all(16),
                   color: Colors.grey.shade50,
                   child: Row(
                     children: [
                       Expanded(
                         flex: 2,
                         child: Text(
                           'Amenities',
                           style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                 fontWeight: FontWeight.bold,
                               ),
                         ),
                       ),
                       Expanded(flex: 2, child: Container()),
                       Expanded(flex: 2, child: Container()),
                     ],
                   ),
                 ),
                 _buildDivider(),
                 Container(
                   padding: const EdgeInsets.all(16),
                   child: Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Amenities label column
                       Expanded(
                         flex: 2,
                         child: Container(),
                       ),
                       // Slot 1 amenities column
                       Expanded(
                         flex: 2,
                         child: _buildAmenitiesColumn(slot1, sortedAmenities),
                       ),
                       // Slot 2 amenities column
                       Expanded(
                         flex: 2,
                         child: _buildAmenitiesColumn(slot2, sortedAmenities),
                       ),
                     ],
                   ),
                 ),
               ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTableRow({
    required String label,
    required String slot1Value,
    required String slot2Value,
    bool isHeader = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: isHeader ? Colors.grey.shade100 : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              slot1Value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              slot2Value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmenitiesColumn(Property? property, List<String> allAmenities) {
    if (property == null) {
      return const SizedBox.shrink();
    }

    final propertyAmenities = property.amenities.toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: allAmenities
          .where((amenity) => propertyAmenities.contains(amenity))
          .map((amenity) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildAmenityBox(amenity),
              ))
          .toList(),
    );
  }

  Widget _buildAmenityBox(String amenity) {
    final icon = AppConstants.getAmenityIcon(amenity) ?? Icons.check_circle_outline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              amenity,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Icon(icon, size: 14, color: Colors.grey.shade600),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, color: Colors.grey.shade300);
  }
}

