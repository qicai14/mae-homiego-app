import 'package:flutter/material.dart';

class PropertyBox extends StatelessWidget {
  final String imageUrl;
  final String name;
  final String location;
  final double rating;
  final int reviewCount;
  final double price;
  final VoidCallback? onTap;

  const PropertyBox({
    super.key,
    required this.imageUrl,
    required this.name,
    required this.location,
    required this.rating,
    required this.reviewCount,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Image - fixed aspect ratio
            AspectRatio(
              aspectRatio: 12 / 9, // Fixed aspect ratio for image
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.image_not_supported)),
              ),
            ),

            // Bottom: Details - fixed height
            SizedBox(
              height: 90, // Fixed height for text section
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Column(
                      crossAxisAlignment:  CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 12,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                      fontSize: 10,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '$rating',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                            ),
                            Text(
                              ' ($reviewCount)',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text(
                              'RM $price',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                            ),
                            Text(
                              '/night',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w300,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
