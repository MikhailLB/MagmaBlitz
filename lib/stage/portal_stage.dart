import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../core/agent_client.dart';
import '../core/alerts_relay.dart';
import '../core/net_sensor.dart';
import '../core/vault.dart';
import '../theme.dart';
import 'offline_stage.dart';

// ============================================================
// PortalStage — full-bleed WebView shell for the gray flow
// ============================================================
// Highlights:
//
//   • Portrait padding pulls the WebView below the status bar
//     so HTML overlays don't fight with system chrome.
//   • Landscape padding mirrors the camera notch insets on
//     BOTH sides so foldables / cutout phones don't render
//     content behind the lens housing.
//   • Connectivity drops trigger the offline stage but with a
//     700 ms debounce — VPN hand-shakes routinely emit a
//     `[none]` blink that is otherwise harmless.
//   • DNS / disconnect WebView errors immediately drop a
//     spinner overlay to hide the native black robot page
//     before swapping to the styled offline stage.
//   • A focused-input JS bridge keeps inputs visible above the
//     keyboard without the smooth-scroll jitter that other
//     templates suffer from.
// ============================================================

Future<void> warmPortalEngine() async {
  // Hook for any future pre-warm work (e.g. WebViewPlatform).
  return;
}

class PortalStage extends StatefulWidget {
  final String openingUrl;
  final Vault vault;
  final AlertsRelay relay;
  final NetSensor netSensor;

  const PortalStage({
    super.key,
    required this.openingUrl,
    required this.vault,
    required this.relay,
    required this.netSensor,
  });

  @override
  State<PortalStage> createState() => _PortalStageState();
}

class _PortalStageState extends State<PortalStage>
    with WidgetsBindingObserver {
  late final WebViewController _web;
  bool _spinning = true;
  bool _bailedToOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _netSub;
  Timer? _netDebounce;

  String? _lastMainFrame;
  int _redirectAttempts = 0;
  static const _redirectCap = 3;

  // ─── system chrome ────────────────────────────────────────

  void _applyImmersive() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _applyImmersive();
  }

  // ─── lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _applyImmersive();
    _buildWebView();
    _subscribeNet();

    widget.relay.onLandingPush = (url) {
      if (mounted) _web.loadRequest(Uri.parse(url));
    };
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _netDebounce?.cancel();
    _netSub?.cancel();
    widget.relay.onLandingPush = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  // ─── WebView setup ────────────────────────────────────────

  void _buildWebView() {
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(agentClient.userAgent)
      ..setBackgroundColor(MagmaColors.deepRock)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _spinning = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _spinning = false);
          _redirectAttempts = 0;
          _stripSafeAreaCss();
          _wireKeyboardBridge();
        },
        onWebResourceError: _onResourceError,
        onHttpError: (_) {},
        onNavigationRequest: _shouldNavigate,
      ))
      ..enableZoom(false);

    _configureAndroidExtras();
    _web.loadRequest(Uri.parse(widget.openingUrl));
  }

  void _onResourceError(WebResourceError err) {
    if (err.isForMainFrame != true) return;

    final blurb = err.description.toLowerCase();
    final isRedirectLoop = blurb.contains('too_many_redirects') ||
        blurb.contains('too many redirects') ||
        err.errorCode == -1007 ||
        err.errorCode == -9;
    if (isRedirectLoop &&
        _lastMainFrame != null &&
        _redirectAttempts < _redirectCap) {
      _redirectAttempts++;
      _web.loadRequest(Uri.parse(_lastMainFrame!));
      return;
    }

    // Cover the native error page IMMEDIATELY with a spinner
    // (the WebView renders the black robot page otherwise).
    if (mounted) setState(() => _spinning = true);

    final isDnsLike = blurb.contains('name_not_resolved') ||
        blurb.contains('err_name_not_resolved') ||
        blurb.contains('internet_disconnected') ||
        blurb.contains('network_changed') ||
        err.errorCode == -105 ||
        err.errorCode == -106 ||
        err.errorCode == -21;

    if (isDnsLike) {
      _bailToOfflineDirect();
    } else {
      _maybeBailToOffline();
    }
  }

  NavigationDecision _shouldNavigate(NavigationRequest req) {
    final uri = Uri.tryParse(req.url);
    if (uri == null) return NavigationDecision.prevent;
    final scheme = uri.scheme;
    if (scheme == 'http' ||
        scheme == 'https' ||
        scheme == 'about' ||
        scheme == 'data' ||
        scheme == 'blob') {
      if (req.isMainFrame) _lastMainFrame = req.url;
      return NavigationDecision.navigate;
    }
    _launchExternal(uri);
    return NavigationDecision.prevent;
  }

  void _configureAndroidExtras() {
    if (!Platform.isAndroid) return;
    if (_web.platform is! AndroidWebViewController) return;
    final android = _web.platform as AndroidWebViewController;
    android.setMediaPlaybackRequiresUserGesture(false);
    android.setOnShowFileSelector(_onFilePicker);

    final cookieManager = AndroidWebViewCookieManager(
      AndroidWebViewCookieManagerCreationParams
          .fromPlatformWebViewCookieManagerCreationParams(
        const PlatformWebViewCookieManagerCreationParams(),
      ),
    );
    cookieManager.setAcceptThirdPartyCookies(android, true);
  }

  Future<List<String>> _onFilePicker(FileSelectorParams params) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: params.mode == FileSelectorMode.openMultiple,
        type: FileType.any,
      );
      if (result == null) return const [];
      return result.files
          .where((f) => f.path != null)
          .map((f) => Uri.file(f.path!).toString())
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ─── JS bridges ───────────────────────────────────────────

  void _stripSafeAreaCss() {
    _web.runJavaScript(r'''
(function(){
  if (window.__mbSafeAreaPatch) return;
  window.__mbSafeAreaPatch = true;

  var STYLE_ID = '__mbsa_kill';
  var CSS =
    ':root{' +
      '--safe-area-inset-top:0px!important;' +
      '--safe-area-inset-right:0px!important;' +
      '--safe-area-inset-bottom:0px!important;' +
      '--safe-area-inset-left:0px!important;' +
      '--sat:0px!important;--sar:0px!important;' +
      '--sab:0px!important;--sal:0px!important;' +
    '}' +
    'html,body,#app,#root,#__nuxt,#__layout{' +
      'padding-top:0!important;' +
      'padding-left:0!important;' +
      'padding-right:0!important;' +
      'margin-top:0!important;' +
    '}';

  function keyboardOpen(){
    if (!window.visualViewport) return false;
    return window.visualViewport.height < window.innerHeight * 0.75;
  }

  function apply(){
    if (keyboardOpen()) return;
    var head = document.head || document.documentElement;
    if (!head) return;
    var meta = document.querySelector('meta[name="viewport"]');
    if (meta && !/viewport-fit\s*=\s*contain/i.test(meta.getAttribute('content') || '')) {
      var content = (meta.getAttribute('content') || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      meta.setAttribute('content', content + (content ? ', ' : '') + 'viewport-fit=contain');
    }
    var s = document.getElementById(STYLE_ID);
    if (!s) {
      s = document.createElement('style');
      s.id = STYLE_ID;
      head.appendChild(s);
    }
    if (s.textContent !== CSS) s.textContent = CSS;
    if (head.lastElementChild !== s) head.appendChild(s);
  }

  apply();

  ['pushState','replaceState'].forEach(function(fn){
    var orig = history[fn];
    history[fn] = function(){
      var r = orig.apply(this, arguments);
      setTimeout(apply, 80);
      setTimeout(apply, 380);
      return r;
    };
  });
  window.addEventListener('popstate', function(){ setTimeout(apply, 80); });
  setInterval(apply, 2500);
})();
''');
  }

  /// Keyboard helper — must use `behavior:'auto'` and a single
  /// 350 ms delay (see webview_keyboard.mdc).  Smooth scroll
  /// during the IME open animation produces visible jitter.
  void _wireKeyboardBridge() {
    _web.runJavaScript(r'''
(function(){
  if (window.__mbKbBridge) return;
  window.__mbKbBridge = true;

  function editable(node){
    if (!node) return false;
    var tag = node.tagName;
    return tag === 'INPUT' || tag === 'TEXTAREA' || node.isContentEditable === true;
  }

  function bringInto(){
    var node = document.activeElement;
    if (!editable(node)) return;
    var vv = window.visualViewport;
    if (vv) {
      var box = node.getBoundingClientRect();
      var floor = vv.offsetTop + vv.height;
      if (box.bottom > floor - 20 || box.top < vv.offsetTop) {
        node.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    } else {
      node.scrollIntoView({ behavior: 'auto', block: 'nearest' });
    }
  }

  document.addEventListener('focusin', function(ev){
    if (editable(ev.target)) setTimeout(bringInto, 350);
  });

  if (window.visualViewport) {
    var lastH = window.visualViewport.height;
    window.visualViewport.addEventListener('resize', function(){
      var h = window.visualViewport.height;
      if (h < lastH) setTimeout(bringInto, 120);
      lastH = h;
    });
  }
})();
''');
  }

  // ─── connectivity ─────────────────────────────────────────

  void _subscribeNet() {
    _netSub = widget.netSensor.changes.listen((statuses) {
      final allDead =
          statuses.every((s) => s == ConnectivityResult.none);
      if (!allDead) {
        _netDebounce?.cancel();
        return;
      }
      _netDebounce?.cancel();
      _netDebounce = Timer(const Duration(milliseconds: 700), () {
        _bailToOfflineDirect();
      });
    });
  }

  Future<void> _maybeBailToOffline() async {
    if (_bailedToOffline) return;
    final live = await widget.netSensor.reachable();
    if (live || !mounted) return;
    _bailToOfflineDirect();
  }

  Future<void> _bailToOfflineDirect() async {
    if (_bailedToOffline || !mounted) return;
    _bailedToOffline = true;
    final current = await _web.currentUrl() ?? widget.openingUrl;
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => OfflineStage(
          rebuilder: (_) => PortalStage(
            openingUrl: current,
            vault: widget.vault,
            relay: widget.relay,
            netSensor: widget.netSensor,
          ),
        ),
      ),
    );
  }

  Future<void> _launchExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<bool> _handleBack() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    }
    return false;
  }

  // ─── build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;

    // Status bar inset only relevant in portrait (immersive
    // landscape hides system chrome).  Side insets in landscape
    // keep WebView content out of the camera-notch slab.
    final padding = EdgeInsets.only(
      top: landscape ? 0 : media.viewPadding.top,
      left: landscape ? media.viewPadding.left : 0,
      right: landscape ? media.viewPadding.right : 0,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _handleBack();
      },
      child: Scaffold(
        backgroundColor: MagmaColors.deepRock,
        resizeToAvoidBottomInset: false,
        body: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: padding,
              child: WebViewWidget(controller: _web),
            ),
            if (_spinning)
              ColoredBox(
                color: MagmaColors.deepRock.withValues(alpha: 0.55),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor:
                        AlwaysStoppedAnimation<Color>(MagmaColors.ember),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
