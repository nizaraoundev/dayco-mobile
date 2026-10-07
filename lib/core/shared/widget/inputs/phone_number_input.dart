import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import '../../../theme/app_theme.dart';

class PhoneNumberInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? Function(String?) validator;
  final ValueChanged<String>? onChanged;
  final double height;
  final String texthint;
  final Color color;
  final bool enabled;
  final String? initialCountryCode;
  final ValueChanged<CountryCode>? onCountryChanged;

  const PhoneNumberInput({
    super.key,
    this.controller,
    required this.validator,
    this.onChanged,
    required this.height,
    required this.texthint,
    this.color = const Color.fromARGB(225, 255, 255, 255),
    this.enabled = true,
    this.initialCountryCode = '+216', // Default to Tunisia
    this.onCountryChanged,
  });

  @override
  State<PhoneNumberInput> createState() => _PhoneNumberInputState();
}

class _PhoneNumberInputState extends State<PhoneNumberInput> {
  String selectedCountryCode = '+216';

  @override
  void initState() {
    super.initState();
    selectedCountryCode = widget.initialCountryCode ?? '+216';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, right: 5, top: 10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5),
          boxShadow: [
            BoxShadow(
              color: ColorManager.backgroundColor.withOpacity(0.2),
              spreadRadius: 0,
              blurStyle: BlurStyle.normal,
              blurRadius: 10,
              offset: Offset(2, 1),
            ),
          ],
        ),
        child: TextFormField(
          enabled: widget.enabled,
          controller: widget.controller,
          textAlign: TextAlign.left,
          keyboardType: TextInputType.phone,
          keyboardAppearance: Brightness.dark,
          onChanged: widget.onChanged,
          style: TextStyle(
            color: ColorManager.textPrimary,
            fontSize: 14, // Smaller font size for input text
          ),
          validator: (value) {
            return widget.validator(value);
          },
          decoration: InputDecoration(
            iconColor: ColorManager.darkTextPrimary,
            fillColor: widget.color,
            filled: true,
            constraints: BoxConstraints(maxHeight: widget.height),
            counterStyle: const TextStyle(
              height: double.minPositive,
            ),
            enabledBorder: OutlineInputBorder(
              borderSide:
                  BorderSide(color: ColorManager.backgroundColor, width: 2.0),
              borderRadius: BorderRadius.circular(15),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(
                  color: ColorManager.primaryColor, width: 2.0),
              borderRadius: BorderRadius.circular(10),
            ),
            hintText: widget.texthint,
            hintStyle: TextStyle(
              color: ColorManager.textSecondary,
              fontSize: 14, // Slightly smaller font for hint
            ),
            prefixIcon: IntrinsicWidth(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120, // Fixed width for country code picker
                      child: CountryCodePicker(
                        onChanged: (countryCode) {
                          setState(() {
                            selectedCountryCode = countryCode.dialCode!;
                          });
                          if (widget.onCountryChanged != null) {
                            widget.onCountryChanged!(countryCode);
                          }
                        },
                        initialSelection: 'TN', // Tunisia as default
                        favorite: const ['+216', 'TN', '+33', 'FR', '+1', 'US'],
                        showFlag: true,
                        showCountryOnly: false,
                        showOnlyCountryWhenClosed: false,
                        alignLeft: false,
                        textStyle: TextStyle(
                          color: ColorManager.textPrimary,
                          fontSize: 13, // Slightly smaller font
                        ),
                        dialogTextStyle: TextStyle(
                          color: ColorManager.textPrimary,
                        ),
                        searchStyle: TextStyle(
                          color: ColorManager.textPrimary,
                        ),
                        searchDecoration: InputDecoration(
                          hintText: 'Rechercher un pays...',
                          hintStyle: TextStyle(
                            color: ColorManager.textSecondary,
                          ),
                        ),
                        showDropDownButton: true,
                        padding: EdgeInsets.zero,
                        backgroundColor: widget.color,
                        barrierColor: Colors.black54,
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: ColorManager.textSecondary.withOpacity(0.3),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ],
                ),
              ),
            ),
            // Add content padding to make phone number input area smaller
            contentPadding: const EdgeInsets.only(
              left: 140, // Adjust based on prefix width
              right: 12,
              top: 12,
              bottom: 12,
            ),
          ),
        ),
      ),
    );
  }

  String get fullPhoneNumber {
    if (widget.controller != null && widget.controller!.text.isNotEmpty) {
      return '$selectedCountryCode${widget.controller!.text}';
    }
    return '';
  }
}
