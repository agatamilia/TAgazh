import 'package:flutter/material.dart';

class SuggestionChips extends StatelessWidget {
  final Function(String) onSuggestionSelected;

  const SuggestionChips({
    super.key,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      "Cara menanam padi",
      "Hama tanaman",
      "Pupuk organik",
      "Teknik irigasi",
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: suggestions.map((suggestion) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(suggestion),
              backgroundColor: Colors.green[50],
              side: BorderSide(color: Colors.green[200]!),
              labelStyle: TextStyle(
                color: Colors.green[800],
                fontSize: 12,
              ),
              onPressed: () => onSuggestionSelected(suggestion),
            ),
          );
        }).toList(),
      ),
    );
  }
}

