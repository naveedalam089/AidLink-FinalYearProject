import 'package:flutter/material.dart';

/// WhatsApp-style message status ticks.
/// - Single grey tick: sent (not yet delivered)
/// - Double grey tick: delivered (not yet read)
/// - Double blue tick: read
class MessageTickIcon extends StatelessWidget {
  final bool delivered;
  final bool read;
  final double size;

  const MessageTickIcon({
    Key? key,
    required this.delivered,
    required this.read,
    this.size = 14,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (read) {
      return Icon(Icons.done_all, size: size, color: const Color(0xFF34B7F1));
    }
    if (delivered) {
      return Icon(Icons.done_all, size: size, color: Colors.grey[400]);
    }
    return Icon(Icons.done, size: size, color: Colors.grey[400]);
  }
}
