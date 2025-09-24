# Roomie

Modern roommate & group management app built with Flutter, Firebase (Auth + Firestore), and Cloudinary for media.

## Architecture (Current)
| Concern | Stack |
|---------|------|
| Auth | Firebase Auth (Google, Phone) |
| Database | Cloud Firestore |
| Images (Profile & Groups) | Cloudinary (unsigned uploads) |
| State (profile image broadcast) | Simple notifier (`ProfileImageNotifier`) |

## Recent Migration
MongoDB & Base64 image storage have been removed. Images now upload to Cloudinary and only the secure URL is stored in Firestore (`users.profileImageUrl`, `groups.imageUrl`). Legacy Mongo service files were deleted:
`mongodb_service.dart`, `mongo_groups_service.dart`, `hybrid_groups_service.dart`, `mongodb_profile_image.dart`.

## Cloudinary Setup
1. Create a Cloudinary account (if not already).
2. In your dashboard create an **Unsigned Upload Preset** (e.g. `roomie_unsigned`). Recommended restrictions:
	 - Allowed formats: jpg,png,webp
	 - Max file size: e.g. 2 MB
	 - Delivery type: upload
	 - Disable unsafe transformations
3. Note your cloud name (currently default: `cloud-roomie`).
4. DO NOT put `api_secret` in the Flutter app (client). Unsigned preset handles uploads.

### Dart Defines
At run/build time provide (override if needed):
```
flutter run \
	--dart-define=CLOUDINARY_CLOUD_NAME=cloud-roomie \
	--dart-define=CLOUDINARY_UPLOAD_PRESET=roomie_unsigned
```

If not supplied, defaults in `CloudinaryConfig` are used.

## Image Flow
1. User picks image (profile or group) using `image_picker`.
2. File bytes are uploaded via `CloudinaryService` (multipart POST).
3. `secure_url` returned is stored directly in Firestore.
4. Display uses `ProfileImageWidget` (profile) or standard `Image.network` for groups.

## Code Highlights
| File | Purpose |
|------|---------|
| `lib/services/cloudinary_service.dart` | Upload abstraction |
| `lib/services/profile_image_service.dart` | Wrapper now returning URL (legacy signature retained) |
| `lib/services/groups_service.dart` | Firestore group CRUD + Cloudinary image upload |
| `lib/widgets/profile_image_widget.dart` | Reactive profile image display |

## Removing Mongo (Completed)
- Removed dependency `mongo_dart` from `pubspec.yaml`.
- Deleted Mongo-related service & widget files.
- Cleared initialization in `main.dart`.

## Tests
Add a mock HTTP test for `CloudinaryService.uploadBytes` verifying `secure_url` extraction (planned).

## Next Ideas
- Add caching headers or `cached_network_image` for performance.
- Signed upload (server) if you need stricter control / transformations.
- Delete old Cloudinary assets on replacement (currently we overwrite by using deterministic `public_id`).

## Running
```
flutter pub get
flutter run --dart-define=CLOUDINARY_CLOUD_NAME=cloud-roomie --dart-define=CLOUDINARY_UPLOAD_PRESET=roomie_unsigned
```

## Troubleshooting
| Issue | Fix |
|-------|-----|
| Upload returns 400 | Check unsigned preset name & restrictions |
| Image not updating immediately | Cloudinary CDN cache; append `?v=<timestamp>` if needed |
| URL null | Ensure preset allows unsigned uploads |

## Security Note
Never embed API secret in the client. For advanced transformations that require signing, introduce a lightweight backend (Cloud Functions / server) to generate signed parameters.

