# Roomie Loading Widget Integration Guide

Your Roomie-loading.json Lottie animation is now integrated throughout your application! Here's how to use it:

## 1. Basic Loading Widget
```dart
// Simple loading widget
RoomieLoadingWidget(
  size: 100,
  showText: true,
  text: 'Loading your content...',
)

// Without text
RoomieLoadingWidget(size: 80)
```

## 2. Small Loading Widget (for buttons, inline use)
```dart
// For buttons and small spaces
RoomieLoadingSmall(size: 24)

// In a button
ElevatedButton(
  onPressed: loading ? null : onPressed,
  child: loading 
    ? const RoomieLoadingSmall(size: 20)
    : const Text('Submit'),
)
```

## 3. Full Screen Loading Overlay
```dart
// Full screen overlay
RoomieFullScreenLoading(
  text: 'Please wait...',
  canDismiss: false,
)

// Using the helper service
RoomieLoadingHelper.showFullScreenLoading(context, message: 'Loading...');
RoomieLoadingHelper.hideFullScreenLoading(); // To hide
```

## 4. Loading Helper Service Methods
```dart
// Show loading for async operations
final result = await RoomieLoadingHelper.showLoadingFor(
  context,
  someAsyncOperation(),
  message: 'Processing request...',
);

// Loading dialog
RoomieLoadingHelper.showLoadingDialog(context, message: 'Uploading...');

// Loading snackbar
RoomieLoadingHelper.showLoadingSnackBar(context, message: 'Syncing data...');

// Page loading widget
return RoomieLoadingHelper.getPageLoadingWidget(message: 'Setting up...');
```

## 5. Current Integration Status

✅ **Login Screen** - Phone auth button shows Roomie animation
✅ **OTP Screen** - Verify button shows Roomie animation  
✅ **Home Screen** - Group loading shows Roomie animation
✅ **Chat Screen** - Message loading shows Roomie animation
✅ **Loading Widget** - Uses assets/Roomie-loading.json correctly

## 6. Asset Configuration

Your Roomie-loading.json file is now properly configured:
- **Location**: `assets/Roomie-loading.json`
- **pubspec.yaml**: Assets section includes the file
- **Widget Path**: Uses `'assets/Roomie-loading.json'`

## 7. Usage Examples Throughout Your App

### In Auth Screens:
```dart
// Login loading state
child: _loading 
  ? const RoomieLoadingSmall(size: 24)
  : const Text('Sign In'),
```

### In List Views:
```dart
// Loading list items
if (isLoading)
  return RoomieLoadingHelper.getListLoadingWidget(
    message: 'Loading groups...',
  );
```

### In Chat/Messages:
```dart
// Loading messages
if (snapshot.connectionState == ConnectionState.waiting) {
  return const RoomieLoadingWidget(
    size: 60,
    showText: true,
    text: 'Loading messages...',
  );
}
```

### For Image Uploads:
```dart
// Image upload loading
_isUploading 
  ? const RoomieLoadingSmall(size: 16)
  : const Icon(Icons.camera_alt),
```

## 8. Customization Options

```dart
RoomieLoadingWidget(
  size: 120,                    // Animation size
  backgroundColor: Colors.blue, // Background color
  showText: true,              // Show/hide text
  text: 'Custom message...',   // Custom loading text
)
```

## 9. Best Practices

- Use `RoomieLoadingSmall` for buttons and small spaces (16-24px)
- Use `RoomieLoadingWidget` for main loading states (60-120px)  
- Use `RoomieFullScreenLoading` for blocking operations
- Use `RoomieLoadingHelper` for consistent loading across the app
- Always provide meaningful loading messages for better UX

Your Roomie loading animation is now ready to use across your entire application! 🚀