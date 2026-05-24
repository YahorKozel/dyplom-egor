import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import '../core/input_limits.dart';
import '../models/city_location.dart';

class CitySearchField extends StatelessWidget {
  final TextEditingController controller;
  final Future<List<CityLocation>> Function(String) onSearch;
  final void Function(CityLocation) onSelected;
  final String? Function(String?)? validator;

  const CitySearchField({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onSelected,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<CityLocation>(
      controller: controller,
      suggestionsCallback: onSearch,
      itemBuilder: (context, city) => ListTile(
        title: Text(
          city.name,
          style: const TextStyle(fontSize: 18),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          city.country,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: const Icon(Icons.location_city, color: Colors.grey),
      ),
      onSelected: onSelected,
      builder: (context, controller, focusNode) => TextFormField(
        controller: controller,
        focusNode: focusNode,
        validator: validator,
        maxLength: InputLimits.cityName,
        inputFormatters: [
          LengthLimitingTextInputFormatter(InputLimits.cityName),
          FilteringTextInputFormatter.deny(RegExp(r'[\n\r\t]')),
        ],
        decoration: const InputDecoration(
          labelText: 'Miasto',
          prefixIcon: Icon(Icons.search),
          counterText: '',
        ),
      ),
    );
  }
}
