import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// A reusable, theme-aware [DropdownButton2] used across PeraKo.
///
/// Wraps `dropdown_button2` so every dropdown in the app shares the same
/// look-and-feel: a rounded, outlined button with a hint and a chevron icon.
///
/// State lives in a [ValueListenable]. When [valueListenable] is provided the
/// caller owns the notifier; otherwise an internal notifier seeded from
/// [initialValue] is used and [onChanged] is called on every selection, so
/// existing `setState`-based form screens keep their current pattern.
class CustomDropdownButton2<T> extends StatefulWidget {
  const CustomDropdownButton2({
    super.key,
    required this.hint,
    required this.dropdownItems,
    required this.itemLabel,
    this.onChanged,
    this.valueListenable,
    this.initialValue,
    this.selectedItemBuilder,
    this.hintAlignment,
    this.valueAlignment,
    this.buttonHeight,
    this.buttonWidth,
    this.buttonPadding,
    this.buttonDecoration,
    this.buttonElevation,
    this.icon,
    this.iconSize,
    this.iconEnabledColor,
    this.iconDisabledColor,
    this.itemHeight,
    this.itemPadding,
    this.dropdownHeight,
    this.dropdownWidth,
    this.dropdownPadding,
    this.dropdownDecoration,
    this.dropdownElevation,
    this.scrollbarRadius,
    this.scrollbarThickness,
    this.scrollbarAlwaysShow,
    this.offset = Offset.zero,
  });

  /// Placeholder shown until a value is chosen.
  final String hint;

  /// The selectable values.
  final List<T> dropdownItems;

  /// Renders the human-readable label for each [T] value.
  final String Function(T) itemLabel;

  /// Called with the newly selected value (or null).
  final ValueChanged<T?>? onChanged;

  /// Optional externally-owned notifier. When null, an internal notifier
  /// seeded from [initialValue] is managed by this widget.
  final ValueListenable<T?>? valueListenable;

  /// Seeds the internal notifier when [valueListenable] is not provided.
  final T? initialValue;

  final DropdownButton2Builder? selectedItemBuilder;
  final Alignment? hintAlignment;
  final Alignment? valueAlignment;
  final double? buttonHeight, buttonWidth;
  final EdgeInsetsGeometry? buttonPadding;
  final BoxDecoration? buttonDecoration;
  final int? buttonElevation;
  final Widget? icon;
  final double? iconSize;
  final Color? iconEnabledColor;
  final Color? iconDisabledColor;
  final double? itemHeight;
  final EdgeInsetsGeometry? itemPadding;
  final double? dropdownHeight, dropdownWidth;
  final EdgeInsetsGeometry? dropdownPadding;
  final BoxDecoration? dropdownDecoration;
  final int? dropdownElevation;
  final Radius? scrollbarRadius;
  final double? scrollbarThickness;
  final bool? scrollbarAlwaysShow;
  final Offset offset;

  @override
  State<CustomDropdownButton2<T>> createState() =>
      _CustomDropdownButton2State<T>();
}

class _CustomDropdownButton2State<T> extends State<CustomDropdownButton2<T>> {
  ValueNotifier<T?>? _internal;

  @override
  void initState() {
    super.initState();
    if (widget.valueListenable == null) {
      _internal = ValueNotifier<T?>(widget.initialValue);
    }
  }

  @override
  void didUpdateWidget(covariant CustomDropdownButton2<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The caller started owning the notifier (or vice versa): reset state.
    if ((widget.valueListenable == null) != (oldWidget.valueListenable == null)) {
      _internal?.dispose();
      _internal = widget.valueListenable == null
          ? ValueNotifier<T?>(widget.initialValue)
          : null;
    } else if (widget.valueListenable == null) {
      // Reflect externally-driven initialValue changes (e.g. async form loads
      // that populate fields after the first build).
      if (_internal!.value != widget.initialValue) {
        _internal!.value = widget.initialValue;
      }
    }
  }

  @override
  void dispose() {
    _internal?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listenable = widget.valueListenable ?? _internal!;
    return DropdownButtonHideUnderline(
      child: DropdownButton2<T>(
        isExpanded: true,
        hint: Container(
          alignment: widget.hintAlignment,
          child: Text(
            widget.hint,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(fontSize: 14, color: theme.hintColor),
          ),
        ),
        valueListenable: listenable,
        items: [
          for (final item in widget.dropdownItems)
            DropdownItem<T>(
              value: item,
              height: widget.itemHeight ?? 40,
              child: Container(
                alignment: widget.valueAlignment,
                child: Text(
                  widget.itemLabel(item),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
        onChanged: (value) {
          _internal?.value = value;
          widget.onChanged?.call(value);
        },
        selectedItemBuilder: widget.selectedItemBuilder,
        buttonStyleData: ButtonStyleData(
          height: widget.buttonHeight ?? 48,
          width: widget.buttonWidth ?? double.infinity,
          padding:
              widget.buttonPadding ?? const EdgeInsets.symmetric(horizontal: 14),
          decoration:
              widget.buttonDecoration ??
              BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.outline),
              ),
          elevation: widget.buttonElevation,
        ),
        iconStyleData: IconStyleData(
          icon: widget.icon ?? const Icon(Icons.arrow_forward_ios_outlined),
          iconSize: widget.iconSize ?? 12,
          iconEnabledColor:
              widget.iconEnabledColor ?? theme.colorScheme.onSurfaceVariant,
          iconDisabledColor: widget.iconDisabledColor,
        ),
        dropdownStyleData: DropdownStyleData(
          // Max height for the dropdown menu; it becomes scrollable if there
          // are more items. Null takes the max height possible for the items.
          maxHeight: widget.dropdownHeight ?? 200,
          width: widget.dropdownWidth,
          padding: widget.dropdownPadding,
          decoration:
              widget.dropdownDecoration ??
              BoxDecoration(borderRadius: BorderRadius.circular(12)),
          elevation: widget.dropdownElevation ?? 8,
          // Offset(0, 0) opens just under the button.
          offset: widget.offset,
          scrollbarTheme: ScrollbarThemeData(
            radius: widget.scrollbarRadius ?? const Radius.circular(40),
            thickness: widget.scrollbarThickness != null
                ? WidgetStateProperty.all<double>(widget.scrollbarThickness!)
                : null,
            thumbVisibility: widget.scrollbarAlwaysShow != null
                ? WidgetStateProperty.all<bool>(widget.scrollbarAlwaysShow!)
                : null,
          ),
        ),
        menuItemStyleData: MenuItemStyleData(
          padding: widget.itemPadding ?? const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}
