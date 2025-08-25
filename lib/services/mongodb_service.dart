import 'package:mongo_dart/mongo_dart.dart';
import 'dart:async';

class MongoDBService {
  // Primary connection using SRV with secure=true for TLS
  static const String _connectionString =
      'mongodb+srv://akil20052622:Akil_1265@cluster0.pxg9bhf.mongodb.net/roomie_db?retryWrites=true&w=majority&appName=roomie';

  // Fallback with correct hostnames and TLS
  static const String _fallbackConnectionString =
      'mongodb://akil20052622:Akil_1265@ac-rnilsmr-shard-00-00.pxg9bhf.mongodb.net:27017,ac-rnilsmr-shard-00-01.pxg9bhf.mongodb.net:27017,ac-rnilsmr-shard-00-02.pxg9bhf.mongodb.net:27017/roomie_db?replicaSet=atlas-ngo66u-shard-0&authSource=admin&retryWrites=true&w=majority&ssl=true';

  // Basic connection with SSL
  static const String _basicConnectionString =
      'mongodb://akil20052622:Akil_1265@ac-rnilsmr-shard-00-00.pxg9bhf.mongodb.net:27017/roomie_db?authSource=admin&ssl=true';

  late Db _database;
  bool _isConnected = false;
  bool _isConnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _connectionMonitor;
  Timer? _reconnectTimer;

  static final MongoDBService _instance = MongoDBService._internal();
  factory MongoDBService() => _instance;
  MongoDBService._internal() {
    _startConnectionMonitor();
  }

  // Initialize MongoDB when app starts with automatic retry
  Future<void> initialize() async {
    print('🔄 Initializing MongoDB connection...');

    // Try to connect immediately
    final connected = await connect();

    if (connected) {
      print('✅ MongoDB initialized successfully');
    } else {
      print('⚠️ Initial MongoDB connection failed, will retry automatically');
      // Start background reconnection attempts
      _startAutoReconnect();
    }
  }

  // Connect to MongoDB with improved error handling
  Future<bool> connect() async {
    if (_isConnecting) {
      print('⏳ Connection already in progress...');
      return false;
    }

    if (_isConnected && _database.isConnected) {
      print('✅ Already connected to MongoDB');
      return true;
    }

    _isConnecting = true;

    // Try basic connection string first to bypass potential SRV issues
    print('🔄 Trying basic connection first...');
    if (await _attemptConnection(_basicConnectionString, 'basic')) {
      return true;
    }

    // Try fallback connection string
    print('🔄 Basic connection failed, trying fallback...');
    if (await _attemptConnection(_fallbackConnectionString, 'fallback')) {
      return true;
    }

    // Try primary SRV connection as a last resort
    print('🔄 Fallback connection failed, trying primary SRV connection...');
    if (await _attemptConnection(_connectionString, 'primary')) {
      return true;
    }

    _isConnected = false;
    _isConnecting = false;
    print('❌ All connection attempts failed');
    return false;
  }

  // Helper method to attempt connection with a specific connection string
  Future<bool> _attemptConnection(String connectionString, String type) async {
    try {
      print('🔗 Attempting $type connection to MongoDB Atlas...');

      // Create database connection with enhanced settings
      _database = await Db.create(connectionString);

      print('🔧 Opening database connection...');

      // For SRV connections, enable secure mode
      if (connectionString.contains('mongodb+srv://') ||
          connectionString.contains('ssl=true')) {
        await _database.open(secure: true);
      } else {
        await _database.open();
      }

      print('🧪 Testing connection with server status...');
      // Test the connection with a simple ping operation
      await _database.serverStatus();
      print('📊 Server status check successful');

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;

      // Cancel any existing reconnect timer since we're now connected
      _reconnectTimer?.cancel();

      print('✅ Successfully connected to MongoDB Atlas using $type connection');
      return true;
    } catch (e) {
      print('❌ $type connection failed: $e');

      // Provide helpful error messages
      if (e.toString().contains('authentication')) {
        print('🔐 Authentication failed - please check username/password');
      } else if (e.toString().contains('network') ||
          e.toString().contains('timeout')) {
        print('🌐 Network issue - please check internet connection');
      } else if (e.toString().contains('IP')) {
        print('🚫 IP not whitelisted - please add your IP to MongoDB Atlas');
      } else if (e.toString().contains('TLS') ||
          e.toString().contains('SSL') ||
          e.toString().contains('Handshake')) {
        print('🔒 TLS/SSL handshake error with $type connection');
      }

      return false;
    }
  }

  // Ensure connection with automatic reconnection
  Future<bool> ensureConnection() async {
    // Check if already connected and connection is healthy
    if (_isConnected && _database.isConnected) {
      return true;
    }

    // Mark as disconnected if connection is not healthy
    if (_isConnected && !_database.isConnected) {
      _isConnected = false;
      print('🔄 MongoDB connection lost, attempting to reconnect...');
    }

    // Attempt to reconnect
    return await connect();
  }

  // Start automatic reconnection attempts
  void _startAutoReconnect() {
    _reconnectTimer?.cancel(); // Cancel any existing timer

    _reconnectTimer = Timer.periodic(const Duration(seconds: 45), (
      timer,
    ) async {
      if (!_isConnected) {
        _reconnectAttempts++;
        print(
          '🔄 Auto-reconnect attempt $_reconnectAttempts of $_maxReconnectAttempts',
        );

        final connected = await connect();
        if (connected) {
          print('✅ Auto-reconnection successful!');
          timer.cancel();
        } else if (_reconnectAttempts >= _maxReconnectAttempts) {
          print(
            '❌ Max reconnection attempts reached. Will retry in 2 minutes...',
          );
          timer.cancel();
          _reconnectAttempts = 0; // Reset for future attempts

          // Schedule a longer retry after max attempts
          Timer(const Duration(minutes: 2), () {
            if (!_isConnected) {
              print('🔄 Resuming auto-reconnect attempts...');
              _startAutoReconnect();
            }
          });
        }
      } else {
        // If connected, cancel the timer
        timer.cancel();
      }
    });
  }

  // Disconnect from MongoDB
  Future<void> disconnect() async {
    try {
      _reconnectTimer?.cancel();
      if (_isConnected) {
        await _database.close();
        _isConnected = false;
        print('🔌 Disconnected from MongoDB');
      }
    } catch (e) {
      print('❌ Error disconnecting from MongoDB: $e');
    }
  }

  // Get collection with automatic connection handling
  Future<DbCollection?> getCollection(String collectionName) async {
    // Try to ensure connection
    final connected = await ensureConnection();

    if (connected) {
      return _database.collection(collectionName);
    }

    // If not connected, start auto-reconnect and return null
    print('⚠️ MongoDB not connected, starting auto-reconnect...');
    if (!_isConnected) {
      _startAutoReconnect();
    }

    // Return null instead of throwing exception
    return null;
  }

  // Safe database operation wrapper
  Future<T?> safeOperation<T>(
    String operationName,
    Future<T> Function(DbCollection collection) operation,
    String collectionName,
  ) async {
    try {
      final collection = await getCollection(collectionName);
      if (collection == null) {
        print('⚠️ $operationName failed: Database not connected');
        return null;
      }

      final result = await operation(collection);
      print('✅ $operationName successful');
      return result;
    } catch (e) {
      print('❌ $operationName error: $e');
      return null;
    }
  }

  // Check if connected
  bool get isConnected => _isConnected && _database.isConnected;

  // Reset reconnection attempts (call this on successful operations)
  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  // Start connection monitoring with health checks
  void _startConnectionMonitor() {
    _connectionMonitor = Timer.periodic(const Duration(minutes: 2), (timer) {
      _checkConnection();
    });
  }

  // Enhanced connection health check
  Future<void> _checkConnection() async {
    if (_isConnected) {
      try {
        // Simple ping to check if connection is alive
        await _database.collection('healthCheck').findOne({});
        // print('💚 MongoDB connection health check: OK');
        resetReconnectAttempts(); // Reset since connection is healthy
      } catch (e) {
        print('💔 MongoDB connection health check failed: $e');
        _isConnected = false;
        // Start auto-reconnect
        _startAutoReconnect();
      }
    } else {
      // If not connected, try to reconnect
      print(
        '🔄 Connection monitor detected disconnection, attempting reconnect...',
      );
      await ensureConnection();
    }
  }

  // Get connection status with emoji
  String get connectionStatus {
    if (_isConnecting) return '🔄 Connecting...';
    if (_isConnected) return '✅ Connected';
    return '❌ Disconnected';
  }

  // Simple test method to verify connection
  Future<bool> testConnection() async {
    try {
      if (!await ensureConnection()) {
        return false;
      }

      final testCollection = _database.collection('test');
      await testCollection.insertOne({
        'test': true,
        'timestamp': DateTime.now().toIso8601String(),
        'message': 'Auto-connection test successful',
      });

      print('✅ MongoDB connection test passed!');
      return true;
    } catch (e) {
      print('❌ MongoDB connection test failed: $e');
      return false;
    }
  }

  // Dispose method to clean up timers
  void dispose() {
    _connectionMonitor?.cancel();
    _reconnectTimer?.cancel();
  }
}
