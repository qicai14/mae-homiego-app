import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homiego/core/models/property.dart';
import 'package:homiego/core/models/property_image.dart';
import 'package:homiego/widgets/property_box.dart';

// --- 1. MOCK HTTP SETUP ---
// A 1x1 transparent PNG to satisfy Image.network immediately
const List<int> _kTransparentImage = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

// A simple Fake class to handle missing overrides via noSuchMethod
class Fake {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

// Override global HTTP client to intercept NetworkImage calls
class TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _MockHttpClient();
  }
}

class _MockHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _MockHttpClientRequest();
  }
}

class _MockHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async {
    return _MockHttpClientResponse();
  }
}

class _MockHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;

  @override
  int get contentLength => _kTransparentImage.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

// --- TEST SUITE ---
void main() {
  setUpAll(() {
    // Install the Mock HTTP client to intercept Image.network calls
    HttpOverrides.global = TestHttpOverrides();
  });

  testWidgets('PropertyBox renders title, price, and location icon correctly', (WidgetTester tester) async {
    // --- 1. SETUP SCREEN SIZE ---
    // Set a large physical screen size to prevent RenderFlex overflow errors
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // --- 2. ARRANGE ---
    final mockProperty = Property(
      id: 1,
      hostId: 'owner1',
      title: 'Luxury Studio @ Bukit Bintang',
      description: 'Near Pavilion',
      address: 'Bukit Bintang, KL',
      pricePerNight: 250.0,
      latitude: 3.14,
      longitude: 101.68,
      amenities: ['wifi'],
      images: [
        PropertyImage(
          id: 1,
          propertyId: 1,
          storagePath: 'https://via.placeholder.com/150', // Intercepted by MockClient
          position: 0,
        )
      ],
      createdAt: DateTime.now(),
      propertyType: 'Apartment',
      maxGuest: 2,
      status: PropertyStatus.approved,
      verified: true,
      cleaningFee: 50.0,
      serviceFee: 30.0,
    );

    // --- 3. ACT ---
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            // Wrap in SingleChildScrollView to handle remaining layout constraints safely
            body: SingleChildScrollView(
              child: PropertyBox(
                name: mockProperty.title,
                location: mockProperty.address,
                price: mockProperty.pricePerNight,
                rating: 4.8,
                reviewCount: 12,
                imageUrl: mockProperty.images.first.storagePath,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    // Allow async image loading to complete (returns transparent pixel)
    await tester.pumpAndSettle();

    // --- 4. ASSERT ---
    expect(find.text('Luxury Studio @ Bukit Bintang'), findsOneWidget);
    expect(find.textContaining('250'), findsOneWidget);
    
    // Verify the presence of the location icon
    expect(find.byIcon(Icons.location_on), findsOneWidget);
  });
}