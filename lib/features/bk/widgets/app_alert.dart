import 'dart:async';

import 'package:flutter/material.dart';

class AppAlert {
  static Future<void> success(
    BuildContext context, {
    String title = 'Berhasil',
    String? message,
    bool autoClose = false,
    int autoCloseMs = 1800,
  }) {
    return _showAlert(
      context,
      type: _AlertType.success,
      title: title,
      message: message,
      okText: 'OK',
      autoClose: autoClose,
      autoCloseMs: autoCloseMs,
    );
  }

  static Future<void> error(
    BuildContext context, {
    String title = 'Terjadi Kesalahan',
    required String message,
  }) {
    return _showAlert(
      context,
      type: _AlertType.error,
      title: title,
      message: message,
      okText: 'OK',
    );
  }

  static Future<void> info(
    BuildContext context, {
    String title = 'Informasi',
    required String message,
  }) {
    return _showAlert(
      context,
      type: _AlertType.info,
      title: title,
      message: message,
      okText: 'OK',
    );
  }

  static Future<bool> confirm(
    BuildContext context, {
    String title = 'Konfirmasi',
    required String message,
    String okText = 'Ya, lanjutkan',
    String cancelText = 'Batal',
  }) async {
    final completer = Completer<bool>();

    unawaited(
      _showDialog(
        context,
        type: _AlertType.warning,
        title: title,
        message: message,
        okText: okText,
        cancelText: cancelText,
        onOk: () {
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        },
        onCancel: () {
          if (!completer.isCompleted) {
            completer.complete(false);
          }
        },
      ),
    );

    return completer.future;
  }

  static Future<void> _showAlert(
    BuildContext context, {
    required _AlertType type,
    required String title,
    String? message,
    required String okText,
    bool autoClose = false,
    int autoCloseMs = 1800,
  }) {
    var isDialogClosed = false;

    final future = _showDialog(
      context,
      type: type,
      title: title,
      message: message,
      okText: okText,
      cancelText: null,
    ).whenComplete(() {
      isDialogClosed = true;
    });

    if (autoClose) {
      Future<void>.delayed(Duration(milliseconds: autoCloseMs), () {
        if (!context.mounted || isDialogClosed) {
          return;
        }
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      });
    }

    return future;
  }

  static Future<void> _showDialog(
    BuildContext context, {
    required _AlertType type,
    required String title,
    String? message,
    required String okText,
    String? cancelText,
    VoidCallback? onOk,
    VoidCallback? onCancel,
  }) {
    final barrierColor = Colors.black.withAlpha(120);

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: cancelText == null,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: barrierColor,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Material(
              type: MaterialType.transparency,
              child: _AlertDialogBody(
                type: type,
                title: title,
                message: message,
                okText: okText,
                cancelText: cancelText,
                onOk: () {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                  onOk?.call();
                },
                onCancel: () {
                  Navigator.of(dialogContext, rootNavigator: true).pop();
                  onCancel?.call();
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

enum _AlertType { success, error, warning, info }

class _AlertDialogBody extends StatelessWidget {
  final _AlertType type;
  final String title;
  final String? message;
  final String okText;
  final String? cancelText;
  final VoidCallback onOk;
  final VoidCallback? onCancel;

  const _AlertDialogBody({
    required this.type,
    required this.title,
    required this.message,
    required this.okText,
    required this.cancelText,
    required this.onOk,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = _AlertTheme.of(type);

    return Container(
      width: MediaQuery.sizeOf(context).width > 520
          ? 420
          : MediaQuery.sizeOf(context).width * 0.9,
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.background,
              shape: BoxShape.circle,
            ),
            child: Icon(colors.icon, size: 40, color: colors.foreground),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          if (message != null && message!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (cancelText != null) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF374151),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(cancelText!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onOk,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.foreground,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(okText),
                  ),
                ),
              ],
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onOk,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.foreground,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(okText),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertTheme {
  final Color foreground;
  final Color background;
  final Color border;
  final IconData icon;

  const _AlertTheme({
    required this.foreground,
    required this.background,
    required this.border,
    required this.icon,
  });

  static _AlertTheme of(_AlertType type) {
    switch (type) {
      case _AlertType.success:
        return const _AlertTheme(
          foreground: Color(0xFF16A34A),
          background: Color(0xFFE8F8EE),
          border: Color(0xFFB7E4C7),
          icon: Icons.check_circle,
        );
      case _AlertType.error:
        return const _AlertTheme(
          foreground: Color(0xFFDC2626),
          background: Color(0xFFFDECEC),
          border: Color(0xFFF5B5B5),
          icon: Icons.error,
        );
      case _AlertType.warning:
        return const _AlertTheme(
          foreground: Color(0xFFF59E0B),
          background: Color(0xFFFFF4D6),
          border: Color(0xFFF4D28A),
          icon: Icons.warning_amber_rounded,
        );
      case _AlertType.info:
        return const _AlertTheme(
          foreground: Color(0xFF2563EB),
          background: Color(0xFFE7F0FF),
          border: Color(0xFFB9CDFB),
          icon: Icons.info,
        );
    }
  }
}
