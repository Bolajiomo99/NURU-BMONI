import 'package:flutter/material.dart';

import '../theme/nuru_theme.dart';

/// A labelled form field.
///
/// Thin on purpose: `NuruTheme.darkTheme.inputDecorationTheme` already supplies
/// the fill, radius and focus border, so this only adds the floating label,
/// the optional password reveal toggle, and consistent spacing.
class NuruTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onSubmitted;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final String? errorText;
  final Iterable<String>? autofillHints;

  const NuruTextField({
    super.key,
    required this.label,
    required this.controller,
    this.focusNode,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.errorText,
    this.autofillHints,
  });

  @override
  State<NuruTextField> createState() => _NuruTextFieldState();
}

class _NuruTextFieldState extends State<NuruTextField> {
  late bool _obscured;
  late FocusNode _effectiveFocusNode;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void didUpdateWidget(covariant NuruTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      if (oldWidget.focusNode == null) {
        _effectiveFocusNode.dispose();
      }
      _effectiveFocusNode = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.enabled && !_effectiveFocusNode.hasFocus) {
          _effectiveFocusNode.requestFocus();
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: NuruTheme.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            autofillHints: widget.autofillHints,
            enableInteractiveSelection: true,
            autocorrect: !widget.obscureText &&
                widget.keyboardType != TextInputType.emailAddress,
            enableSuggestions: !widget.obscureText,
            textCapitalization: (widget.obscureText ||
                    widget.keyboardType == TextInputType.emailAddress)
                ? TextCapitalization.none
                : TextCapitalization.sentences,
            contextMenuBuilder: (context, editableTextState) {
              // Strip liveTextInput on iOS Simulator to avoid keyboard input freezes
              final items = editableTextState.contextMenuButtonItems;
              items.removeWhere(
                (item) => item.type == ContextMenuButtonType.liveTextInput,
              );
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems: items,
              );
            },
            style: const TextStyle(
              fontSize: 16,
              color: NuruTheme.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(widget.prefixIcon, size: 20, color: NuruTheme.textMuted),
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscured
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        size: 20,
                        color: NuruTheme.textMuted,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
