import 'package:flutter/material.dart';

import '../../../core/auth/auth_token_store.dart';

class TokenDebugScreen extends StatefulWidget {
  const TokenDebugScreen({super.key});

  @override
  State<TokenDebugScreen> createState() => _TokenDebugScreenState();
}

class _TokenDebugScreenState extends State<TokenDebugScreen> {
  final TextEditingController _tokenController = TextEditingController();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final token = await AuthTokenStore.instance.readToken();
    if (!mounted) {
      return;
    }

    setState(() {
      _tokenController.text = token ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveToken() async {
    await AuthTokenStore.instance.writeToken(_tokenController.text);
    if (!mounted) {
      return;
    }

    _showMessage('Token saved. Future requests will include Authorization.');
    await _loadToken();
  }

  Future<void> _clearToken() async {
    await AuthTokenStore.instance.clearToken();
    if (!mounted) {
      return;
    }

    _showMessage('Token cleared.');
    await _loadToken();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Token Debug'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Paste the token from the login response. You can paste the raw JWT or a full Bearer token.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xFF4A5550),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tokenController,
                  minLines: 6,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    labelText: 'Token',
                    hintText: 'eyJhbGciOiJIUzI1NiJ9...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saveToken,
                  child: const Text('Save Token'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _loadToken,
                  child: const Text('Reload Stored Token'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _clearToken,
                  child: const Text('Clear Token'),
                ),
                const SizedBox(height: 24),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFF4F7F5),
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'After saving, requests sent through ApiClient will automatically add Authorization: Bearer <token>. Auth endpoints remain unchanged.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF4A5550),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
