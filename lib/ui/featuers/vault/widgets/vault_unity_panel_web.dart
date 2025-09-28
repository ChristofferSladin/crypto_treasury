import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class VaultCoinSelection {
  const VaultCoinSelection({required this.symbol, required this.countPerCoin});

  final String symbol;
  final int countPerCoin;
}

class VaultUnityPanel extends StatefulWidget {
  const VaultUnityPanel({
    super.key,
    required this.walletBalances,
    required this.onCoinSelected,
    required this.showLoader,
    required this.onUnityReady,
  });

  final List<Map<String, dynamic>> walletBalances;
  final ValueChanged<VaultCoinSelection>? onCoinSelected;
  final bool showLoader;
  final ValueChanged<bool>? onUnityReady;

  @override
  State<VaultUnityPanel> createState() => _VaultUnityPanelState();
}

class _VaultUnityPanelState extends State<VaultUnityPanel> {
  static int _viewIdSeed = 0;

  late final String _viewType;
  html.IFrameElement? _iframe;
  StreamSubscription<html.Event>? _messageSub;
  bool _frameLoaded = false;
  String? _lastWalletPayload;

  @override
  void initState() {
    super.initState();
    assert(kIsWeb, 'VaultUnityPanel_web is only for web builds.');
    _viewType = 'unity-vault-frame-${_viewIdSeed++}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, _createIFrame);
    _messageSub = html.window.onMessage.listen(_handleMessageEvent);
  }

  html.Element _createIFrame(int viewId) {
    final element = html.IFrameElement()
      ..id = 'unity-vault-frame-$viewId'
      ..src = '/3d/index.html'
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000'
      ..allow = 'autoplay; fullscreen; xr-spatial-tracking';

    element.onLoad.listen((_) {
      _frameLoaded = true;
      widget.onUnityReady?.call(true);
      _postWallet();
      setState(() {});
    });

    _iframe = element;
    return element;
  }

  @override
  void didUpdateWidget(covariant VaultUnityPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _postWallet();
  }

  @override
  void dispose() {
    widget.onUnityReady?.call(false);
    _messageSub?.cancel();
    _messageSub = null;
    super.dispose();
  }

  void _postWallet() {
    if (!_frameLoaded) {
      return;
    }

    final window = _iframe?.contentWindow;
    if (window == null) {
      return;
    }

    final payloadMap = {
      'type': 'setWallet',
      'balances': widget.walletBalances,
    };
    final payload = jsonEncode(payloadMap);

    if (payload == _lastWalletPayload) {
      return;
    }

    _lastWalletPayload = payload;
    window.postMessage(payload, '*');
  }

  void _handleMessageEvent(html.Event event) {
    if (event is! html.MessageEvent) {
      return;
    }

    final data = event.data;
    dynamic message;
    if (data is String) {
      try {
        message = jsonDecode(data);
      } catch (_) {
        message = null;
      }
    } else if (data is Map) {
      message = data;
    }

    if (message is! Map) {
      return;
    }

    if (message['type'] != 'coinSelected') {
      return;
    }

    final symbol = (message['symbol'] as String?) ?? '';
    final count = (message['count_per_coin'] as num?)?.toInt() ?? 0;
    widget.onCoinSelected?.call(
      VaultCoinSelection(symbol: symbol, countPerCoin: count),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (widget.showLoader || !_frameLoaded)
          Container(
            color: Colors.black.withOpacity(0.65),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(),
          ),
      ],
    );
  }
}
