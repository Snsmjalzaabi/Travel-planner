import 'package:flutter/material.dart';

class QuickCaptureWidget extends StatefulWidget {
  final Function(String type, {String? text, List<String>? tags}) onCapture;

  const QuickCaptureWidget({super.key, required this.onCapture});

  @override
  State<QuickCaptureWidget> createState() => _QuickCaptureWidgetState();
}

class _QuickCaptureWidgetState extends State<QuickCaptureWidget> {
  final GlobalKey<ScaffoldMessengerState> _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  void _handleCapture(String type) {
    switch (type) {
      case 'note':
        _showNoteCapture();
        break;
      case 'task':
        _showTaskCapture();
        break;
      case 'expense':
        _showExpenseCapture();
        break;
      case 'trip idea':
        _showTripIdeaCapture();
        break;
      case 'photo':
        _showPhotoCapture();
        break;
      case 'flight':
        _showFlightCapture();
        break;
      case 'hotel':
        _showHotelCapture();
        break;
      default:
        widget.onCapture(type);
    }
  }

  void _showNoteCapture() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Note', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What\'s on your mind?',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Grab the messenger before popping: using `context` after
                    // Navigator.pop tears the route down and can blank the screen.
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    if (controller.text.isNotEmpty) {
                      widget.onCapture('note', text: controller.text);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Note captured')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTaskCapture() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Task', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'What needs to be done?',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Grab the messenger before popping: using `context` after
                    // Navigator.pop tears the route down and can blank the screen.
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    if (controller.text.isNotEmpty) {
                      widget.onCapture('task', text: controller.text);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Task captured')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showExpenseCapture() {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Expense', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Grab the messenger before popping: using `context` after
                    // Navigator.pop tears the route down and can blank the screen.
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    if (amountController.text.isNotEmpty) {
                      widget.onCapture('expense', text: '${amountController.text} ${descController.text}');
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Expense logged')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTripIdeaCapture() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trip Idea', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Where to? (e.g., "Tokyo winter trip")',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Grab the messenger before popping: using `context` after
                    // Navigator.pop tears the route down and can blank the screen.
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(context);
                    if (controller.text.isNotEmpty) {
                      widget.onCapture('trip', text: controller.text);
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Trip idea saved')),
                      );
                    }
                  },
                  child: const Text('Save'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPhotoCapture() => widget.onCapture('photo');
  void _showFlightCapture() => widget.onCapture('flight');
  void _showHotelCapture() => widget.onCapture('hotel');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      body: Column(
        children: [
          _buildQuickButton(Icons.note, 'Note', ColorsRecord.noteColor,
              'Tap to capture a quick note'),
          _buildQuickButton(Icons.tag, 'Task', ColorsRecord.taskColor,
              'Tap to log a quick task'),
          _buildQuickButton(Icons.attach_money, 'Expense', ColorsRecord.expenseColor,
              'Tap to log an expense'),
          _buildQuickButton(Icons.hotel, 'Trip Idea', ColorsRecord.tripColor,
              'Tap to save a trip idea'),
          _buildQuickButton(Icons.photo_camera, 'Photo', ColorsRecord.photoColor,
              'Tap to take a photo'),
          _buildQuickButton(Icons.flight, 'Flight', ColorsRecord.flightColor,
              'Tap to log flight info'),
          _buildQuickButton(Icons.hotel, 'Hotel', ColorsRecord.hotelColor,
              'Tap to log hotel info'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildQuickButton(IconData icon, String label, Color color, String tooltip) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => _handleCapture(label.toLowerCase()),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Icon(Icons.add, color: Colors.grey, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ColorsRecord {
  static const noteColor = Color(0xFF6366F1);
  static const taskColor = Color(0xFFF59E0B);
  static const expenseColor = Color(0xFF10B981);
  static const tripColor = Color(0xFF3B82F6);
  static const photoColor = Color(0xFFEC4899);
  static const flightColor = Color(0xFF8B5CF6);
  static const hotelColor = Color(0xFFF97316);
}
