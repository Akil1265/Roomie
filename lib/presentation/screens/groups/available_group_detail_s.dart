import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:roomie/data/datasources/auth_service.dart';
import 'package:roomie/data/datasources/groups_service.dart';

class AvailableGroupDetailScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const AvailableGroupDetailScreen({super.key, required this.group});

  @override
  State<AvailableGroupDetailScreen> createState() =>
      _AvailableGroupDetailScreenState();
}

class _AvailableGroupDetailScreenState
    extends State<AvailableGroupDetailScreen> {
  final GroupsService _groupsService = GroupsService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat.yMMMd().format(timestamp.toDate());
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _currencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'INR':
      default:
        return '₹';
    }
  }

  String _formatRent(double amount, String currency) {
    if (amount <= 0) return 'Not specified';
    final formatter = NumberFormat.compactCurrency(
      symbol: _currencySymbol(currency),
      decimalDigits: 0,
    );
    return '${formatter.format(amount)}/month';
  }

  String _formatAdvance(double amount, String currency) {
    if (amount <= 0) return 'No advance';
    final formatter = NumberFormat.compactCurrency(
      symbol: _currencySymbol(currency),
      decimalDigits: 0,
    );
    return '${formatter.format(amount)} deposit';
  }

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

      final success = await _groupsService.sendJoinRequest(widget.group['id']);

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
    final List<String> images = List<String>.from(widget.group['images'] ?? []);
    final bool hasImages = images.isNotEmpty;
    final dynamic rentRaw = widget.group['rent'];
    double rentAmount = _toDouble(widget.group['rentAmount']);
    String rentCurrency = (widget.group['rentCurrency'] ?? '').toString();
    double advanceAmount = _toDouble(widget.group['advanceAmount']);

    if (rentAmount == 0 && rentRaw != null) {
      if (rentRaw is Map<String, dynamic>) {
        rentAmount = _toDouble(rentRaw['amount']);
      } else if (rentRaw is num || rentRaw is String) {
        rentAmount = _toDouble(rentRaw);
      }
    }

    if (rentCurrency.isEmpty && rentRaw is Map<String, dynamic>) {
      rentCurrency = (rentRaw['currency'] ?? 'INR').toString();
    }
    if (rentCurrency.isEmpty) {
      rentCurrency = 'INR';
    }

    if (advanceAmount == 0 && rentRaw is Map<String, dynamic>) {
      advanceAmount = _toDouble(rentRaw['advanceAmount']);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280.0,
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            stretch: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Hero(
                tag: 'group-image-${widget.group['id']}',
                child:
                    hasImages
                        ? _buildImageSlider(images)
                        : _buildPlaceholderImage(),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.group['name'] ?? 'Unnamed Group',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF121417),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2F1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Available',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.teal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.group['description'] ?? 'No description available.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF677583),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(height: 1, color: Color(0xFFE8E8E8)),
                  const SizedBox(height: 24),
                  _buildFullWidthInfoCard(
                    icon: Icons.location_on_outlined,
                    title: 'Location',
                    value: widget.group['location'] ?? 'Not specified',
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.attach_money,
                          title: 'Rent',
                          value: _formatRent(rentAmount, rentCurrency),
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Advance',
                          value: _formatAdvance(advanceAmount, rentCurrency),
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.group_outlined,
                          title: 'Roommates',
                          value:
                              '${widget.group['memberCount'] ?? 0} / ${widget.group['capacity']?.toString() ?? 'N/A'}',
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          icon: Icons.home_outlined,
                          title: 'Room Type',
                          value: widget.group['roomType'] ?? 'N/A',
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.calendar_today_outlined,
                    title: 'Created On',
                    value: _formatTimestamp(
                      widget.group['createdAt'] as Timestamp?,
                    ),
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 24),
                  if (widget.group['amenities'] != null &&
                      (widget.group['amenities'] as List).isNotEmpty) ...[
                    const Text(
                      'Amenities',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF121417),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAmenitiesGrid(
                      List<String>.from(widget.group['amenities']),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE8E8E8), width: 1)),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _requestToJoin,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isLoading
                      ? const Color(0xFFCCCCCC)
                      : const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: const Color(0xFFE0E0E0),
            ),
            child:
                _isLoading
                    ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
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
    );
  }

  Widget _buildImageSlider(List<String> images) {
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: images.length,
          onPageChanged: (index) {
            setState(() {
              _currentImageIndex = index;
            });
          },
          itemBuilder: (context, index) {
            return Image.network(
              images[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            );
          },
        ),
        if (images.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.5),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Icon(Icons.group, color: Colors.grey, size: 60),
      ),
    );
  }

  Widget _buildAmenitiesGrid(List<String> amenities) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          amenities.map((amenity) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                amenity,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildFullWidthInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF677583),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.05),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF677583),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF121417),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
