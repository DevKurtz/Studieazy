import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

extension type _BeforeInstallPromptEvent(JSObject _) implements JSObject {
  external JSPromise<JSAny?> prompt();
  external JSPromise<JSAny?> get userChoice;
}

extension type _InstallChoice(JSObject _) implements JSObject {
  external JSString get outcome;
}

class AppInstallButton extends StatefulWidget {
  const AppInstallButton({super.key});

  @override
  State<AppInstallButton> createState() => _AppInstallButtonState();
}

class _AppInstallButtonState extends State<AppInstallButton> {
  JSObject? _installPrompt;

  @override
  void initState() {
    super.initState();
    _syncInstallPrompt();
    web.window.addEventListener(
      'studieazy-install-available',
      ((web.Event _) => _syncInstallPrompt()).toJS,
    );
    web.window.addEventListener(
      'appinstalled',
      ((web.Event _) {
        _clearInstallPrompt();
        if (mounted) setState(() => _installPrompt = null);
      }).toJS,
    );
  }

  void _syncInstallPrompt() {
    final prompt = (web.window as JSObject).getProperty<JSAny?>(
      '__studieazyInstallPrompt'.toJS,
    );
    if (prompt != null && mounted) {
      setState(() => _installPrompt = prompt as JSObject);
    }
  }

  void _clearInstallPrompt() {
    (web.window as JSObject).setProperty('__studieazyInstallPrompt'.toJS, null);
  }

  Future<void> _install() async {
    final prompt = _installPrompt;
    if (prompt == null) {
      await _showManualInstallHelp();
      return;
    }

    try {
      final installPrompt = _BeforeInstallPromptEvent(prompt);
      await installPrompt.prompt().toDart;
      final choice = await installPrompt.userChoice.toDart;
      final outcome = _InstallChoice(choice as JSObject).outcome.toDart;
      _clearInstallPrompt();
      if (mounted) setState(() => _installPrompt = null);
      if (outcome == 'accepted' && mounted) {
        ScaffoldMessenger.maybeOf(
          context,
        )?.showSnackBar(const SnackBar(content: Text('Studieazy installed.')));
      }
    } catch (_) {
      _clearInstallPrompt();
      if (mounted) setState(() => _installPrompt = null);
      await _showManualInstallHelp();
    }
  }

  Future<void> _showManualInstallHelp() async {
    final agent = web.window.navigator.userAgent.toLowerCase();
    final isIos = agent.contains('iphone') || agent.contains('ipad');
    final isAndroid = agent.contains('android');
    final guidance =
        isIos
            ? 'In Safari, tap Share, then choose “Add to Home Screen”.'
            : isAndroid
            ? 'Open this page in Chrome, tap the ⋮ menu, then choose “Install app” or “Add to Home screen”.'
            : 'Use the install icon in your browser address bar, or open the browser menu and choose “Install Studieazy”.';
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Install Studieazy'),
            content: Text(guidance),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: _install,
    icon: const Icon(Icons.install_mobile_rounded, size: 18),
    label: const Text('Install App'),
    style: TextButton.styleFrom(
      foregroundColor: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
  );
}
