import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/nuru_theme.dart';

/// Six single-character boxes for the verification code.
///
/// Hand-rolled rather than pulling a package: the behaviour that matters is
/// auto-advance, backspace-to-previous, and pasting a whole code at once, all
/// of which are a few lines each.
class NuruOtpInput extends StatefulWidget {
  final int length;
  final void Function(String code) onChanged;

  /// Fired when the last box is filled, so the caller can submit without
  /// making the user reach for a button.
  final void Function(String code)? onCompleted;
  final bool enabled;
  final bool hasError;

  const NuruOtpInput({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  State<NuruOtpInput> createState() => NuruOtpInputState();
}

class NuruOtpInputState extends State<NuruOtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  /// Separate nodes for the KeyboardListener wrappers. Built once here rather
  /// than inline in build(), which would allocate a new node every rebuild and
  /// never dispose any of them.
  late final List<FocusNode> _keyNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    _keyNodes = List.generate(
      widget.length,
      (_) => FocusNode(skipTraversal: true, canRequestFocus: false),
    );
    // Repaint on focus change so the active box shows its border.
    for (final n in _nodes) {
      n.addListener(_onFocusChanged);
    }
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.removeListener(_onFocusChanged);
      n.dispose();
    }
    for (final n in _keyNodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  /// Clears every box and returns focus to the first. Called after a wrong
  /// code so the user is not deleting six digits by hand.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    widget.onChanged('');
    if (mounted) _nodes.first.requestFocus();
  }

  void _distribute(String value, int index) {
    // A paste (or an SMS autofill) arrives as one long string in one box.
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      for (var i = 0; i < widget.length; i++) {
        final target = index + i;
        if (target >= widget.length || i >= digits.length) break;
        _controllers[target].text = digits[i];
      }
      final filled = (index + digits.length).clamp(0, widget.length);
      if (filled >= widget.length) {
        _nodes[widget.length - 1].unfocus();
      } else {
        _nodes[filled].requestFocus();
      }
      _emit();
      return;
    }

    if (digits.isEmpty) {
      _controllers[index].clear();
    } else {
      _controllers[index].text = digits;
      if (index < widget.length - 1) {
        _nodes[index + 1].requestFocus();
      } else {
        _nodes[index].unfocus();
      }
    }
    _emit();
  }

  void _emit() {
    final code = _code;
    widget.onChanged(code);
    // _code joins every box, so a full-length result means all six are filled.
    if (code.length == widget.length) {
      widget.onCompleted?.call(code);
    }
  }

  void _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey != LogicalKeyboardKey.backspace) return;
    // Backspace on an already-empty box steps back and clears the previous one.
    // The TextField itself ignores backspace when empty, so there is nothing
    // to conflict with.
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _nodes[index - 1].requestFocus();
      _emit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (i) {
        final filled = _controllers[i].text.isNotEmpty;
        final focused = _nodes[i].hasFocus;
        final borderColor = widget.hasError
            ? NuruTheme.dangerRed
            : focused
                ? NuruTheme.primary
                : filled
                    ? NuruTheme.surfaceElevated
                    : NuruTheme.surfaceLight;

        return Flexible(
          child: Padding(
            padding: EdgeInsets.only(right: i == widget.length - 1 ? 0 : 8),
            child: AspectRatio(
              aspectRatio: 0.82,
              child: KeyboardListener(
                focusNode: _keyNodes[i],
                onKeyEvent: (event) => _onKey(i, event),
                child: Container(
                  decoration: BoxDecoration(
                    color: NuruTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: borderColor,
                      width: focused || widget.hasError ? 1.6 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    enabled: widget.enabled,
                    autofocus: i == 0,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: (context, editableTextState) {
                      final items = editableTextState.contextMenuButtonItems;
                      items.removeWhere(
                        (item) => item.type == ContextMenuButtonType.liveTextInput,
                      );
                      return AdaptiveTextSelectionToolbar.buttonItems(
                        anchors: editableTextState.contextMenuAnchors,
                        buttonItems: items,
                      );
                    },
                    // No maxLength/1-char formatter: a pasted code must reach
                    // _distribute intact instead of being truncated.
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: NuruTheme.textPrimary,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => _distribute(v, i),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
