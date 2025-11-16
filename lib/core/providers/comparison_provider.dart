import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';

/// State class for property comparison
@immutable
class ComparisonState {
  final Property? slot1;
  final Property? slot2;

  const ComparisonState({
    this.slot1,
    this.slot2,
  });

  ComparisonState copyWith({
    Property? slot1,
    Property? slot2,
    bool? clearSlot1,
    bool? clearSlot2,
  }) {
    return ComparisonState(
      slot1: clearSlot1 == true ? null : (slot1 ?? this.slot1),
      slot2: clearSlot2 == true ? null : (slot2 ?? this.slot2),
    );
  }

  /// Check if both slots are empty
  bool get isEmpty => slot1 == null && slot2 == null;

  /// Check if both slots are filled
  bool get isFull => slot1 != null && slot2 != null;

  /// Check if a property is already in either slot
  bool containsProperty(Property property) {
    return (slot1?.id == property.id) || (slot2?.id == property.id);
  }
}

/// Notifier for managing comparison state
class ComparisonNotifier extends StateNotifier<ComparisonState> {
  ComparisonNotifier() : super(const ComparisonState());

  /// Add or replace a property in a slot
  /// If property already exists in a slot, replace it in that slot
  /// Otherwise, add to the first available slot
  void addOrReplace(Property property) {
    // Check if property already exists in either slot
    if (state.slot1?.id == property.id) {
      // Already in slot1, no need to change
      return;
    }
    if (state.slot2?.id == property.id) {
      // Already in slot2, no need to change
      return;
    }

    // Find first available slot or replace slot1 if both are full
    if (state.slot1 == null) {
      state = state.copyWith(slot1: property);
    } else if (state.slot2 == null) {
      state = state.copyWith(slot2: property);
    } else {
      // Both slots full, replace slot1
      state = state.copyWith(slot1: property);
    }
  }

  /// Remove property from a specific slot (1 or 2)
  void removeFromSlot(int slotIndex) {
    if (slotIndex == 1) {
      state = state.copyWith(clearSlot1: true);
    } else if (slotIndex == 2) {
      state = state.copyWith(clearSlot2: true);
    }
  }

  /// Reset both slots
  void reset() {
    state = const ComparisonState();
  }

  /// Add property to a specific slot (replaces if already filled)
  void setSlot(int slotIndex, Property? property) {
    if (slotIndex == 1) {
      state = state.copyWith(slot1: property);
    } else if (slotIndex == 2) {
      state = state.copyWith(slot2: property);
    }
  }
}

/// Provider for property comparison state
final comparisonProvider = StateNotifierProvider<ComparisonNotifier, ComparisonState>((ref) {
  return ComparisonNotifier();
});

