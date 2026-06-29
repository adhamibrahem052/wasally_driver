import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

class ProductCard extends StatelessWidget {
  final String name;
  final double price;
  final double? comparePrice;
  final String? imageUrl;
  final String? storeName;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;

  const ProductCard({
    super.key,
    required this.name,
    required this.price,
    this.comparePrice,
    this.imageUrl,
    this.storeName,
    this.onTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 1,
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl!, fit: BoxFit.cover, width: double.infinity,
                        placeholder: (_, _) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (_, _, _) => Container(color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
                      )
                    : Container(color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (storeName != null) Text(storeName!, style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${price.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFFF9800))),
                      if (comparePrice != null) ...[
                        const SizedBox(width: 4),
                        Text('${comparePrice!.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough)),
                      ],
                      const Spacer(),
                      if (onAddToCart != null)
                        GestureDetector(
                          onTap: onAddToCart,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(color: const Color(0xFFFF9800), borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.add, size: 18, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderCard extends StatelessWidget {
  final String orderId;
  final String status;
  final String details;
  final double total;
  final VoidCallback? onTap;

  const OrderCard({
    super.key,
    required this.orderId,
    required this.status,
    required this.details,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (status) {
      case 'pending': statusColor = Colors.orange; break;
      case 'on_the_way': statusColor = Colors.green; break;
      case 'delivered': statusColor = const Color(0xFF0D47A1); break;
      case 'cancelled': statusColor = Colors.red; break;
      default: statusColor = Colors.blue;
    }
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.1),
          child: Icon(_getStatusIcon(), color: statusColor),
        ),
        title: Text(details, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
        subtitle: Text('${total.toStringAsFixed(0)} ج.م', style: GoogleFonts.cairo(color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(_getStatusText(), style: TextStyle(color: statusColor, fontSize: 11)),
        ),
        onTap: onTap,
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (status) {
      case 'pending': return Icons.hourglass_empty;
      case 'on_the_way': return Icons.delivery_dining;
      case 'delivered': return Icons.check_circle;
      case 'cancelled': return Icons.cancel;
      default: return Icons.receipt_long;
    }
  }

  String _getStatusText() {
    switch (status) {
      case 'pending': return 'قيد الانتظار';
      case 'on_the_way': return 'في الطريق';
      case 'delivered': return 'تم التسليم';
      case 'cancelled': return 'ملغي';
      default: return status;
    }
  }
}
