import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homiego/core/models/property.dart';

/// Property comparison state
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

  bool get isEmpty => slot1 == null && slot2 == null;
  bool get isFull => slot1 != null && slot2 != null;

  /// Check if property exists in slots
  bool containsProperty(Property property) {
    return (slot1?.id == property.id) || (slot2?.id == property.id);
  }
}

/// Comparison state manager
class ComparisonNotifier extends StateNotifier<ComparisonState> {
  ComparisonNotifier() : super(const ComparisonState());

  /// Add or replace property in slot
  void addOrReplace(Property property) {
    if (state.slot1?.id == property.id) {
      return;
    }
    if (state.slot2?.id == property.id) {
      return;
    }

    // Find available slot or replace slot1
    if (state.slot1 == null) {
      state = state.copyWith(slot1: property);
    } else if (state.slot2 == null) {
      state = state.copyWith(slot2: property);
    } else {
      state = state.copyWith(slot1: property);
    }
  }

  /// Remove property from slot
  void removeFromSlot(int slotIndex) {
    if (slotIndex == 1) {
      state = state.copyWith(clearSlot1: true);
    } else if (slotIndex == 2) {
      state = state.copyWith(clearSlot2: true);
    }
  }

  /// Reset slots
  void reset() {
    state = const ComparisonState();
  }

  /// Set property in slot
  void setSlot(int slotIndex, Property? property) {
    if (slotIndex == 1) {
      state = state.copyWith(slot1: property);
    } else if (slotIndex == 2) {
      state = state.copyWith(slot2: property);
    }
  }
}

/// Comparison provider
final comparisonProvider = StateNotifierProvider<ComparisonNotifier, ComparisonState>((ref) {
  return ComparisonNotifier();
});

