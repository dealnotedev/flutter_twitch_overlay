import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:obssource/music/music_player_visuals.dart';

/// Desktop controls use the overlay palette, without Material input chrome.
class NeonSettingsButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool? selected;
  final bool busy;
  final bool _section;
  const NeonSettingsButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.selected,
    this.busy = false,
  }) : _section = false;

  const NeonSettingsButton.section({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  }) : busy = false,
       _section = true;
  @override
  State<NeonSettingsButton> createState() => _NeonSettingsButtonState();
}

class _NeonSettingsButtonState extends State<NeonSettingsButton> {
  bool _focused = false;
  bool _hovered = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final color =
        !enabled
            ? MusicPlayerPalette.textSecondary.withValues(alpha: 0.45)
            : widget.selected == false && !widget._section
            ? MusicPlayerPalette.textSecondary
            : MusicPlayerPalette.neonPinkBright;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      label: widget.label,
      child: FocusableActionDetector(
        enabled: enabled,
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        onShowHoverHighlight: (v) => setState(() => _hovered = v),
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child:
              widget._section
                  ? _buildSection(color)
                  : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ExcludeFocus(
                        child: ExcludeSemantics(
                          child: NeonMusicIconButton(
                            icon:
                                widget.busy
                                    ? Icons.more_horiz_rounded
                                    : widget.icon ??
                                        (widget.selected == true
                                            ? Icons.radio_button_checked
                                            : Icons.radio_button_unchecked),
                            onPressed: widget.onPressed,
                            size: 34,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          widget.label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight:
                                widget.selected == true
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                            decoration:
                                _focused ? TextDecoration.underline : null,
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildSection(Color color) {
    final active = widget.selected == true || _focused || _hovered;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: MusicPlayerPalette.neonPink.withValues(
          alpha: active ? 0.16 : 0.05,
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: color.withValues(alpha: active ? 0.75 : 0.25),
        ),
        boxShadow:
            active
                ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.12),
                    blurRadius: 12,
                  ),
                ]
                : [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 17, color: color),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              widget.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NeonSettingsInput extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback? onSubmitted;
  const NeonSettingsInput({
    super.key,
    required this.controller,
    required this.label,
    this.enabled = true,
    this.onSubmitted,
  });
  @override
  State<NeonSettingsInput> createState() => _NeonSettingsInputState();
}

class _NeonSettingsInputState extends State<NeonSettingsInput> {
  final _focus = FocusNode();
  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _focus.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.label,
    textField: true,
    child: GestureDetector(
      onTap: widget.enabled ? _focus.requestFocus : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: MusicPlayerPalette.voidBlack.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color:
                _focus.hasFocus
                    ? MusicPlayerPalette.neonPinkBright
                    : MusicPlayerPalette.neonBlue.withValues(alpha: 0.3),
          ),
        ),
        child: EditableText(
          controller: widget.controller,
          focusNode: _focus,
          readOnly: !widget.enabled,
          style: const TextStyle(
            color: MusicPlayerPalette.textPrimary,
            fontSize: 13,
            fontFamily: 'RobotoMono',
          ),
          cursorColor: MusicPlayerPalette.neonPinkBright,
          backgroundCursorColor: MusicPlayerPalette.midnight,
          selectionColor: MusicPlayerPalette.neonPink.withValues(alpha: 0.3),
          selectionControls: desktopTextSelectionControls,
          keyboardType: TextInputType.text,
          autocorrect: false,
          enableSuggestions: false,
          onSubmitted: (_) => widget.onSubmitted?.call(),
        ),
      ),
    ),
  );
}
