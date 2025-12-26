import 'package:flutter/material.dart';
import 'package:animations/animations.dart';
import '../Models/Task.dart';
import 'dart:ui';

class Task3DCard extends StatefulWidget {
  final Task task;
  final VoidCallback onClose;

  const Task3DCard({Key? key, required this.task, required this.onClose})
      : super(key: key);

  @override
  _Task3DCardState createState() => _Task3DCardState();
}

class _Task3DCardState extends State<Task3DCard> {
  double _xRotation = 0.1;
  double _yRotation = 0.1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _yRotation -= details.delta.dx / 100;
            _xRotation += details.delta.dy / 100;
          });
        },
        child: Stack(
          children: [
            // Hiệu ứng nền mờ
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
            Center(
              child: Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateX(_xRotation)
                  ..rotateY(_yRotation),
                alignment: FractionalOffset.center,
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _getTaskColor().withOpacity(0.8),
                        _getTaskColor().withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        spreadRadius: 3,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: _buildCardContent(),
                ),
              ),
            ),
            Positioned(
              top: 50,
              right: 20,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: widget.onClose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getTaskIcon(), size: 60, color: Colors.white),
          SizedBox(height: 20),
          Text(
            widget.task.description,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 10),
          Divider(color: Colors.white70),
          SizedBox(height: 10),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                widget.task.description,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ),
          SizedBox(height: 20),
          _buildTaskDetails(),
        ],
      ),
    );
  }

  Widget _buildTaskDetails() {
    return Column(
      children: [
        _buildDetailRow('Priority:', widget.task.type.toString()),
        _buildDetailRow('Start Date:', _formatDate(widget.task.startDate.toString())),
        if (widget.task.endDate != null)
          _buildDetailRow('End Date:', _formatDate(widget.task.endDate!.toString())),
        _buildDetailRow(
          'Status:',
          widget.task.isCompleted ? 'Completed' : 'In Progress',
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 10),
          Text(
            value,
            style: TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Color _getTaskColor() {
    switch (widget.task.type) {
      case 'Urgent':
        return Colors.redAccent;
      case 'Work':
        return Colors.blueAccent;
      case 'Personal':
        return Colors.greenAccent;
      default:
        return Colors.deepPurpleAccent;
    }
  }

  IconData _getTaskIcon() {
    switch (widget.task.type) {
      case 'Urgent':
        return Icons.warning;
      case 'Work':
        return Icons.work;
      case 'Personal':
        return Icons.person;
      default:
        return Icons.task;
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }
}