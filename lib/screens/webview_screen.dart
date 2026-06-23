import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme.dart';

class WebViewScreen extends StatefulWidget {
  final String title;
  final String url;

  const WebViewScreen({super.key, required this.title, required this.url});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(MagmaColors.deepRock)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
                _error = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MagmaColors.deepRock,
      appBar: AppBar(
        backgroundColor: MagmaColors.rock,
        foregroundColor: MagmaColors.ash,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          if (!_error) WebViewWidget(controller: _controller),
          if (_error) _buildError(),
          if (_loading && !_error)
            const Center(
              child: CircularProgressIndicator(color: MagmaColors.lava),
            ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, color: MagmaColors.lava, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Could not load the page.\nPlease check your connection.',
              textAlign: TextAlign.center,
              style: TextStyle(color: MagmaColors.ash),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                setState(() {
                  _error = false;
                  _loading = true;
                });
                _controller.loadRequest(Uri.parse(widget.url));
              },
              child: const Text(
                'Retry',
                style: TextStyle(color: MagmaColors.ember),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
