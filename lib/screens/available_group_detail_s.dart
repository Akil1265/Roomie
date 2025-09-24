import 'package:flutter/material.dart';
import 'package:roomie/services/groups_service.dart';
import 'package:roomie/services/auth_service.dart';

class AvailableGroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const AvailableGroupDetailScreen({
    super.key,
    required this.group,
  });

  @override
  State<AvailableGroupDetailScreen> createState() => _AvailableGroupDetailScreenState();
}

class _AvailableGroupDetailScreenState extends State<AvailableGroupDetailScreen> {
  final GroupsService _groupsService = GroupsService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  Future<void> _requestToJoin() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = _authService.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Send join request
      final success = await _groupsService.sendJoinRequest(
        widget.group['id'],
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Join request sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        throw Exception('Failed to send join request');
      }
    } catch (e) {
      print('Error sending join request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Group Details',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group Image
                  Container(
                    height: 250,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF5F5F5),
                    ),
                    child: widget.group['imageUrl'] != null && 
                           widget.group['imageUrl'].toString().isNotEmpty
                        ? Image.network(
                            widget.group['imageUrl'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFF5F5F5),
                                child: const Center(
                                  child: Icon(
                                    Icons.image,
                                    color: Colors.grey,
                                    size: 50,
                                  ),
                                ),
                              );
                            },
                          )
                        : Container(
                            color: const Color(0xFFF5F5F5),
                            child: const Center(
                              child: Icon(
                                Icons.group,
                                color: Colors.grey,
                                size: 50,
                              ),
                            ),
                          ),
                  ),

                  // Group Information
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Group Name and Status
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.group['name'] ?? 'Unnamed Group',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF121417),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Description
                        Text(
                          widget.group['description'] ?? 'No description available',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF677583),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Details Grid
                        _buildInfoCard(
                          icon: Icons.location_on,
                          title: 'Location',
                          value: widget.group['location'] ?? 'Not specified',
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        
                        _buildInfoCard(
                          icon: Icons.people,
                          title: 'Members',
                          value: '${widget.group['memberCount'] ?? 0}/${widget.group['maxMembers'] ?? 0} members',
                          color: Colors.purple,
                        ),
                        const SizedBox(height: 16),

                        if (widget.group['rent'] != null && widget.group['rent'] > 0)
                          _buildInfoCard(
                            icon: Icons.attach_money,
                            title: 'Rent',
                            value: '\$${widget.group['rent'].toInt()}/month',
                            color: Colors.green,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Button
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Color(0xFFE8E8E8), width: 1),
              ),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _requestToJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isLoading ? const Color(0xFFCCCCCC) : const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  disabledBackgroundColor: const Color(0xFFCCCCCC),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Request to Join',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF677583),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF121417),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}