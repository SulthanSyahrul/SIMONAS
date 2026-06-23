-- Supabase Storage Bucket Setup Guide
-- Document: SUPABASE_STORAGE_SETUP.md
-- Purpose: Configure storage buckets for file uploads (documents, avatars)

# Supabase Storage Setup Guide

## Overview
Storage buckets in Supabase allow users to upload and manage files (documents, images, etc.).

## Architecture

```
Flutter App
    ↓
Supabase Storage API
    ↓
PostgreSQL Storage (metadata in storage.objects)
    ↓
Cloud Blob Storage
```

## Part 1: Create Storage Buckets

### Step 1.1: Create Buckets via Dashboard

1. **Go to Supabase Dashboard** → **Storage** → **Buckets**
2. **Create New Bucket**:
   - Name: `administrasi_pembelajaran`
   - Visibility: Private (RLS controlled)
   - Click **Create Bucket**

3. **Repeat for**:
   - `avatars` (for user profile pictures)
   - `jurnal_attachments` (for journal documents)
   - `tugas_files` (for assignment files)

### Step 1.2: Create Buckets via SQL

```sql
-- Create storage buckets
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('administrasi_pembelajaran', 'administrasi_pembelajaran', false),
  ('avatars', 'avatars', false),
  ('jurnal_attachments', 'jurnal_attachments', false),
  ('tugas_files', 'tugas_files', false);
```

## Part 2: Configure RLS Policies

### Step 2.1: Enable RLS on Storage Objects

```sql
-- Enable RLS for storage objects
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
```

### Step 2.2: Create RLS Policies for administrasi_pembelajaran

```sql
-- Teachers can upload their own documents
CREATE POLICY "Teachers upload own docs" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'administrasi_pembelajaran' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Teachers can view/download own documents
CREATE POLICY "Teachers read own docs" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'administrasi_pembelajaran' AND
    (
      auth.uid()::text = (storage.foldername(name))[1] OR
      -- Allow kepsek/kemahasiswaan to view all
      EXISTS (
        SELECT 1 FROM user_roles
        WHERE user_id = auth.uid()
        AND role IN ('kepsek', 'kemahasiswaan')
        AND is_deleted = false
      )
    )
  );

-- Teachers can delete own documents
CREATE POLICY "Teachers delete own docs" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'administrasi_pembelajaran' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

### Step 2.3: Create RLS Policies for avatars

```sql
-- Users can upload own avatar
CREATE POLICY "Users upload own avatar" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- Users can view all avatars
CREATE POLICY "View avatars" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'avatars'
  );

-- Users can delete own avatar
CREATE POLICY "Users delete own avatar" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'avatars' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

### Step 2.4: Create RLS Policies for Other Buckets

```sql
-- jurnal_attachments (similar to documents)
CREATE POLICY "Teachers upload jurnal attachments" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'jurnal_attachments' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );

-- tugas_files (assignments)
CREATE POLICY "Teachers upload assignment files" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'tugas_files' AND
    auth.uid()::text = (storage.foldername(name))[1]
  );
```

## Part 3: Create Storage Service

### Step 3.1: Create StorageService Class

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class StorageService {
  final SupabaseClient _client;

  StorageService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Upload file to storage bucket
  /// Returns: Public URL of uploaded file
  Future<String> uploadFile({
    required String bucket,
    required String filePath,
    required File file,
    String? fileType, // 'image/jpeg', 'application/pdf'
  }) async {
    try {
      final fileName = file.path.split('/').last;
      final fullPath = '$filePath/$fileName';

      // Upload file
      await _client.storage.from(bucket).upload(
        fullPath,
        file,
        fileOptions: FileOptions(
          contentType: fileType,
        ),
      );

      // Get public URL
      final publicUrl = _client.storage
          .from(bucket)
          .getPublicUrl(fullPath);

      return publicUrl;
    } catch (e) {
      throw Exception('Error uploading file: $e');
    }
  }

  /// Download file from storage
  Future<List<int>> downloadFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      final data = await _client.storage
          .from(bucket)
          .download(filePath);
      return data;
    } catch (e) {
      throw Exception('Error downloading file: $e');
    }
  }

  /// Delete file from storage
  Future<void> deleteFile({
    required String bucket,
    required String filePath,
  }) async {
    try {
      await _client.storage.from(bucket).remove([filePath]);
    } catch (e) {
      throw Exception('Error deleting file: $e');
    }
  }

  /// List files in bucket folder
  Future<List<FileObject>> listFiles({
    required String bucket,
    required String folderPath,
  }) async {
    try {
      final files = await _client.storage
          .from(bucket)
          .list(path: folderPath);
      return files;
    } catch (e) {
      throw Exception('Error listing files: $e');
    }
  }

  /// Upload user avatar
  Future<String> uploadAvatar({
    required String userId,
    required File imageFile,
  }) async {
    return uploadFile(
      bucket: 'avatars',
      filePath: userId,
      file: imageFile,
      fileType: 'image/jpeg',
    );
  }

  /// Upload learning document (Administrasi Pembelajaran)
  Future<String> uploadAdministrasiDocument({
    required String guruId,
    required File document,
    String? fileName,
  }) async {
    return uploadFile(
      bucket: 'administrasi_pembelajaran',
      filePath: guruId,
      file: document,
      fileType: _getContentType(document.path),
    );
  }

  /// Get content type from file extension
  String _getContentType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    const mimeTypes = {
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
    };
    return mimeTypes[ext] ?? 'application/octet-stream';
  }

  /// Get signed URL (for private files)
  String getSignedUrl({
    required String bucket,
    required String filePath,
    Duration expiresIn = const Duration(hours: 1),
  }) {
    return _client.storage
        .from(bucket)
        .createSignedUrl(filePath, expiresIn.inSeconds);
  }
}
```

### Step 3.2: Create Riverpod Storage Providers

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/storage_service.dart';
import 'dart:io';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

// Upload avatar
final uploadAvatarProvider = FutureProvider.family<String, (String, File)>(
  (ref, args) async {
    final storageService = ref.watch(storageServiceProvider);
    final (userId, imageFile) = args;
    return await storageService.uploadAvatar(
      userId: userId,
      imageFile: imageFile,
    );
  },
);

// Upload learning document
final uploadAdministrasiDocProvider = FutureProvider.family<String, (String, File)>(
  (ref, args) async {
    final storageService = ref.watch(storageServiceProvider);
    final (guruId, document) = args;
    return await storageService.uploadAdministrasiDocument(
      guruId: guruId,
      document: document,
    );
  },
);

// List files
final listFilesProvider = FutureProvider.family<List<FileObject>, (String, String)>(
  (ref, args) async {
    final storageService = ref.watch(storageServiceProvider);
    final (bucket, folder) = args;
    return await storageService.listFiles(
      bucket: bucket,
      folderPath: folder,
    );
  },
);
```

## Part 4: Implement File Upload UI

### Step 4.1: Avatar Upload Widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/storage_providers.dart';
import '../providers/auth_providers.dart';
import 'dart:io';

class AvatarUploadWidget extends ConsumerStatefulWidget {
  final String currentAvatarUrl;
  final Function(String) onUploadComplete;

  const AvatarUploadWidget({
    Key? key,
    required this.currentAvatarUrl,
    required this.onUploadComplete,
  }) : super(key: key);

  @override
  ConsumerState<AvatarUploadWidget> createState() => _AvatarUploadWidgetState();
}

class _AvatarUploadWidgetState extends ConsumerState<AvatarUploadWidget> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Current avatar
        GestureDetector(
          onTap: _isUploading ? null : _pickImage,
          child: CircleAvatar(
            radius: 50,
            backgroundImage: widget.currentAvatarUrl.isNotEmpty
                ? NetworkImage(widget.currentAvatarUrl)
                : null,
            child: widget.currentAvatarUrl.isEmpty
                ? const Icon(Icons.person, size: 50)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        // Upload button
        ElevatedButton.icon(
          onPressed: _isUploading ? null : _pickImage,
          icon: _isUploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          label: Text(_isUploading ? 'Uploading...' : 'Change Avatar'),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final userId = ref.read(currentUserProvider).value?.id;
      if (userId == null) throw Exception('User not authenticated');

      final imageFile = File(image.path);
      final storageService = ref.read(storageServiceProvider);

      final url = await storageService.uploadAvatar(
        userId: userId,
        imageFile: imageFile,
      );

      widget.onUploadComplete(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avatar updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }
}
```

### Step 4.2: Document Upload Widget

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/storage_providers.dart';
import 'dart:io';

class DocumentUploadWidget extends ConsumerStatefulWidget {
  final String guruId;
  final Function(String fileName, String url) onUploadComplete;

  const DocumentUploadWidget({
    Key? key,
    required this.guruId,
    required this.onUploadComplete,
  }) : super(key: key);

  @override
  ConsumerState<DocumentUploadWidget> createState() => _DocumentUploadWidgetState();
}

class _DocumentUploadWidgetState extends ConsumerState<DocumentUploadWidget> {
  bool _isUploading = false;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isUploading ? null : _pickDocument,
      icon: _isUploading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file),
      label: Text(_isUploading ? 'Uploading...' : 'Upload Document'),
    );
  }

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() => _isUploading = true);

    try {
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final storageService = ref.read(storageServiceProvider);

      final url = await storageService.uploadAdministrasiDocument(
        guruId: widget.guruId,
        document: file,
        fileName: fileName,
      );

      widget.onUploadComplete(fileName, url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }
}
```

## Part 5: File Organization Strategy

### Recommended Folder Structure

```
avatars/
  └── {user_id}/
      └── avatar.jpg

administrasi_pembelajaran/
  └── {guru_id}/
      ├── rpp/
      │   ├── RPP_Matematika_2024.docx
      │   └── RPP_IPA_2024.docx
      ├── silabus/
      │   └── Silabus_2024.xlsx
      └── penilaian/
          └── Rubrik_Penilaian.pdf

jurnal_attachments/
  └── {guru_id}/
      └── {tanggal}/
          ├── lampiran1.pdf
          └── foto_kelas.jpg

tugas_files/
  └── {guru_id}/
      └── {tugas_id}/
          └── panduan_tugas.pdf
```

## Part 6: Security Considerations

### File Validation
```dart
// Validate file size
const maxFileSize = 10 * 1024 * 1024; // 10 MB

if (file.lengthSync() > maxFileSize) {
  throw Exception('File too large');
}

// Validate file type
final allowedTypes = ['application/pdf', 'image/jpeg'];
final fileType = _getContentType(file.path);

if (!allowedTypes.contains(fileType)) {
  throw Exception('Invalid file type');
}
```

### Signed URLs
```dart
// Generate temporary download link (1 hour expiry)
final url = storageService.getSignedUrl(
  bucket: 'administrasi_pembelajaran',
  filePath: filePath,
  expiresIn: const Duration(hours: 1),
);

// Share with others (link expires after 1 hour)
```

## Part 7: Testing

```dart
test('Upload avatar successfully', () async {
  final storageService = StorageService();
  final testFile = File('test_assets/avatar.jpg');

  final url = await storageService.uploadAvatar(
    userId: 'test-user-id',
    imageFile: testFile,
  );

  expect(url, isNotEmpty);
  expect(url, contains('avatars'));
});

test('Upload document with validation', () async {
  final storageService = StorageService();
  final testFile = File('test_assets/document.pdf');

  final url = await storageService.uploadAdministrasiDocument(
    guruId: 'test-guru-id',
    document: testFile,
  );

  expect(url, isNotEmpty);
});
```

## Next Steps

1. **Create Buckets**: Set up buckets via Supabase dashboard
2. **Configure RLS**: Implement access policies
3. **Implement StorageService**: Add to Flutter app
4. **Test Upload/Download**: Verify functionality
5. **Handle Errors**: Implement proper error handling
6. **Monitor Usage**: Track storage usage in dashboard

## Troubleshooting

### Upload Fails
- Check RLS policies are correct
- Verify user is authenticated
- Check file size limits
- Ensure bucket exists

### Access Denied
- Verify RLS policy allows operation
- Check user has correct role
- Ensure auth.uid() is set correctly

### Performance Issues
- Compress images before upload
- Use chunked upload for large files
- Monitor storage costs
