import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Simple in-app browser used for the Privacy Policy and Support pages.
///
/// The core game never needs network access; this screen is the one place
/// that does, and it degrades gracefully (with a clear message) when the
/// device has no connectivity.
class LegalWebViewScreen extends StatefulWidget {
  const LegalWebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<LegalWebViewScreen> createState() => _LegalWebViewScreenState();
}

class _LegalWebViewScreenState extends State<LegalWebViewScreen> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (_) => setState(() {
            _isLoading = false;
            _hasError = true;
          }),
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _retry() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    await _webViewController.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          if (!_hasError) WebViewWidget(controller: _webViewController),
          if (_isLoading && !_hasError)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7A3C)),
            ),
          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.black38, size: 40),
                    const SizedBox(height: 12),
                    const Text(
                      'Couldn\'t load this page.\nPlease check your internet connection.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
