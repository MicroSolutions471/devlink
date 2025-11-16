// ignore_for_file: deprecated_member_use

import 'package:devlink/utility/customTheme.dart';
import 'package:flutter/material.dart';
import 'package:ming_cute_icons/ming_cute_icons.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final String? label;
  final int? maxLines;
  final IconData? prefixIcon;
  final bool isPassword;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final TextInputAction textInputAction;

  const CustomTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.label,
    this.maxLines,
    this.prefixIcon,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.enabled = true,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _obscure = false;

  @override
  void initState() {
    super.initState();
    _obscure = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderColor = scheme.outlineVariant;

    final isMultiline = (widget.maxLines ?? 1) > 1 && !widget.isPassword;

    return SizedBox(
      width: double.infinity,
      child: TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        obscureText: _obscure,

        minLines: widget.maxLines ?? 1,
        maxLines: widget.maxLines ?? 1,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        validator: widget.validator,
        cursorColor: primaryColor,
        cursorHeight: isMultiline ? null : 20,
        cursorWidth: 1,
        onChanged: widget.onChanged,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hintText,
          hintStyle: TextStyle(color: scheme.onSurface.withOpacity(0.5)),
          prefixIcon: widget.prefixIcon != null
              ? Icon(
                  widget.prefixIcon,
                  color: scheme.onSurface.withOpacity(0.7),
                  size: 16,
                )
              : null,
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon: Icon(
                    _obscure
                        ? MingCuteIcons.mgc_eye_close_line
                        : MingCuteIcons.mgc_eye_line,
                    color: scheme.onSurface.withOpacity(0.7),
                    size: 16,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,

          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isMultiline ? 12 : 8,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: primaryColor, width: 0.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              width: 0.5,
              color: borderColor.withOpacity(0.5),
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: scheme.error, width: 0.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: scheme.error, width: 0.5),
          ),
        ),
      ),
    );
  }
}
