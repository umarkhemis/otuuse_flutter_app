import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/rating_repository.dart';

/// Shows the star rating dialog after a ride completes.
/// Call this from both the driver screen (rate passenger) and
/// the chat screen (rate driver).
Future<void> showRatingDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String rideId,
  required String ratingFor, // 'driver' or 'passenger'
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _RatingDialog(
      rideId: rideId,
      ratingFor: ratingFor,
      ref: ref,
    ),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog({
    required this.rideId,
    required this.ratingFor,
    required this.ref,
  });

  final String rideId;
  final String ratingFor;
  final WidgetRef ref;

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _selectedRating = 0;
  final _reviewController = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  String get _title => widget.ratingFor == 'driver'
      ? 'Rate your driver'
      : 'Rate your passenger';

  String get _subtitle => widget.ratingFor == 'driver'
      ? 'How was your ride experience?'
      : 'How was this passenger?';

  Future<void> _submit() async {
    if (_selectedRating == 0) {
      setState(() => _error = 'Please select a rating');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final repo = RatingRepository(widget.ref.read(apiClientProvider));
      await repo.submitRating(
        rideId: widget.rideId,
        rating: _selectedRating,
        ratingFor: widget.ratingFor,
        review: _reviewController.text,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _error = 'Could not submit rating. Please try again.';
      });
    }
  }

  void _skip() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.7),
                  )),
          const SizedBox(height: 20),

          // Star selector
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return GestureDetector(
                onTap: () => setState(() => _selectedRating = starValue),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    starValue <= _selectedRating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 40,
                    color: starValue <= _selectedRating
                        ? Colors.amber
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.3),
                  ),
                ),
              );
            }),
          ),

          if (_selectedRating > 0) ...[
            const SizedBox(height: 6),
            Text(
              _ratingLabel(_selectedRating),
              style: TextStyle(
                color: Colors.amber.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Optional comment
          TextField(
            controller: _reviewController,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(
              hintText: 'Leave a comment (optional)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : _skip,
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Submit'),
        ),
      ],
    );
  }

  String _ratingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very good';
      case 5:
        return 'Excellent!';
      default:
        return '';
    }
  }
}
