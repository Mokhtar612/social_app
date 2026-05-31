import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  final String _baseUrl = dotenv.env['EXPO_PUBLIC_API_URL'] ?? 'http://localhost:3000';
  final _storage = const FlutterSecureStorage();

  // Common headers including ngrok skip
  Map<String, String> _headers({String? token, bool isJson = true}) {
    final headers = <String, String>{
      'ngrok-skip-browser-warning': 'true',
    };
    if (isJson) {
      headers['Content-Type'] = 'application/json';
    }
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  // Get stored token
  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Get stored user ID
  Future<int?> getUserId() async {
    final idStr = await _storage.read(key: 'user_id');
    if (idStr != null) return int.parse(idStr);
    return null;
  }

  // Get stored username
  Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  // Login — Backend expects { email, password }
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        await _storage.write(key: 'user_id', value: data['user']['id'].toString());
        await _storage.write(key: 'username', value: data['user']['username']);
        return {'success': true, 'user': data['user']};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Invalid credentials'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Register — Backend expects { username, email, password }
  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/api/auth/register'),
        headers: _headers(),
        body: jsonEncode({'username': username, 'email': email, 'password': password}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        await _storage.write(key: 'jwt_token', value: data['token']);
        await _storage.write(key: 'user_id', value: data['user']['id'].toString());
        await _storage.write(key: 'username', value: data['user']['username']);
        return {'success': true, 'user': data['user']};
      } else {
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }

  // Fetch current user profile
  Future<Map<String, dynamic>?> fetchProfile() async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/profile'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['user'];
      }
    } catch (e) {
      print('Error fetching profile: $e');
    }
    return null;
  }

  // Fetch chat history
  Future<List<dynamic>> fetchChatHistory() async {
    try {
      final token = await getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/public-chat/history'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['messages'] ?? [];
      }
    } catch (e) {
      print('Error fetching chat history: $e');
    }
    return [];
  }

  // Fetch Feed posts
  Future<List<dynamic>> fetchFeed() async {
    try {
      final token = await getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/feed'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['posts'] ?? [];
      }
    } catch (e) {
      print('Error fetching feed: $e');
    }
    return [];
  }

  // Upload audio file
  Future<String?> uploadAudio(String filePath) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/upload/audio'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('audio', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['audio_url'];
      }
    } catch (e) {
      print('Error uploading audio: $e');
    }
    return null;
  }

  // Upload any media file
  Future<String?> uploadMedia(String filePath) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/upload/media'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.files.add(await http.MultipartFile.fromPath('media', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['media_url'];
      }
    } catch (e) {
      print('Error uploading media: $e');
    }
    return null;
  }

  // Create Feed Post
  Future<Map<String, dynamic>?> createPost(String content, {String? imageUrl, String? videoUrl}) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/feed'),
        headers: _headers(token: token),
        body: jsonEncode({
          'content': content,
          'image_url': imageUrl,
          'video_url': videoUrl,
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['post'];
      }
    } catch (e) {
      print('Error creating post: $e');
    }
    return null;
  }

  // Toggle like on a post
  Future<Map<String, dynamic>?> toggleLike(int postId) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/feed/$postId/like'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error toggling like: $e');
    }
    return null;
  }

  // Update profile
  Future<Map<String, dynamic>?> updateProfile({String? username, String? bio, String? avatarPath}) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$_baseUrl/api/users/profile'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['ngrok-skip-browser-warning'] = 'true';

      if (username != null) request.fields['username'] = username;
      if (bio != null) request.fields['bio'] = bio;
      if (avatarPath != null) {
        request.files.add(await http.MultipartFile.fromPath('avatar', avatarPath));
      }

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['user'];
      }
    } catch (e) {
      print('Error updating profile: $e');
    }
    return null;
  }

  // Fetch Explore Users
  Future<List<dynamic>> fetchExploreUsers() async {
    try {
      final token = await getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/explore'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['users'] ?? [];
      }
    } catch (e) {
      print('Error fetching explore users: $e');
    }
    return [];
  }

  // Toggle follow status
  Future<bool?> toggleFollow(int userId, bool isFollowing) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final action = isFollowing ? 'unfollow' : 'follow';
      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/$userId/$action'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_following'] as bool?;
      }
    } catch (e) {
      print('Error toggling follow: $e');
    }
    return null;
  }

  // Fetch post replies
  Future<List<dynamic>> fetchPostReplies(int postId) async {
    try {
      final token = await getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/feed/$postId/replies'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['replies'] ?? [];
      }
    } catch (e) {
      print('Error fetching post replies: $e');
    }
    return [];
  }

  // Create post reply
  Future<Map<String, dynamic>?> createPostReply(int postId, String content) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/feed/$postId/replies'),
        headers: _headers(token: token),
        body: jsonEncode({'content': content}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['reply'];
      }
    } catch (e) {
      print('Error creating post reply: $e');
    }
    return null;
  }

  // Delete a post
  Future<bool> deletePost(int postId) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/feed/$postId'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('Error deleting post: $e');
    }
    return false;
  }

  // Warn a user (Admin only)
  Future<Map<String, dynamic>?> warnUser(int userId) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$_baseUrl/api/users/$userId/warn'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Error warning user: $e');
    }
    return null;
  }

  // Delete a user (Admin only)
  Future<bool> deleteUser(int userId) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$_baseUrl/api/users/$userId'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true;
      }
    } catch (e) {
      print('Error deleting user: $e');
    }
    return false;
  }

  // Fetch user profile (public profile)
  Future<Map<String, dynamic>?> fetchUserProfile(int userId) async {
    try {
      final token = await getToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['user'];
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

  // Fetch target user's posts
  Future<List<dynamic>> fetchUserPosts(int userId) async {
    try {
      final token = await getToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$_baseUrl/api/users/$userId/posts'),
        headers: _headers(token: token),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['posts'] ?? [];
      }
    } catch (e) {
      print('Error fetching user posts: $e');
    }
    return [];
  }

  // Logout
  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
