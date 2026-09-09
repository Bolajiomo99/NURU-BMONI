import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/nuru_theme.dart';

/// Full-screen in-app browser for the Mono Connect widget (mobile only —
/// see ConnectScreen for the web new-tab equivalent).
///
/// Watches every navigation for one starting with [redirectUrl] — the exact
/// string /mono/connect/initiate/ echoed back — and intercepts it before the
/// WebView actually loads it, since that URL is a backend SPA route with
/// nothing useful to render inside a WebView. Pops with the extracted `code`
/// on success, or null if the user backs out without finishing.
class MonoWebViewScreen extends StatefulWidget {
  final String monoUrl;
  final String redirectUrl;

  const MonoWebViewScreen({super.key, required this.monoUrl, required this.redirectUrl});

  @override
  State<MonoWebViewScreen> createState() => _MonoWebViewScreenState();
}

class _MonoWebViewScreenState extends State<MonoWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(NuruTheme.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _loading = true),
          onPageFinished: (_) => setState(() => _loading = false),
          onNavigationRequest: (request) {
            if (widget.redirectUrl.isNotEmpty &&
                request.url.startsWith(widget.redirectUrl)) {
              final code = Uri.parse(request.url).queryParameters['code'];
              Navigator.of(context).pop(code);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.monoUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Link Bank Account'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(child: CircularProgressIndicator(color: NuruTheme.primary)),
        ],
      ),
    );
  }
}
