import 'package:flutter/material.dart';
import 'package:pets/core/domain/pet_profile_tags.dart';

class PetProfileTagsForm extends StatefulWidget {
  final PetProfileTags tags;
  final ValueChanged<PetProfileTags> onChanged;

  const PetProfileTagsForm({
    super.key,
    required this.tags,
    required this.onChanged,
  });

  @override
  State<PetProfileTagsForm> createState() => _PetProfileTagsFormState();
}

class _PetProfileTagsFormState extends State<PetProfileTagsForm> {
  late final TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(
      text: _formatWeight(widget.tags.weightKg),
    );
  }

  @override
  void didUpdateWidget(covariant PetProfileTagsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = _formatWeight(widget.tags.weightKg);
    if (_weightController.text != nextText) {
      _weightController.text = nextText;
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  String _formatWeight(double? weightKg) {
    if (weightKg == null) return '';
    return weightKg.toString();
  }

  PetProfileTags get tags => widget.tags;

  void onChanged(PetProfileTags value) => widget.onChanged(value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('基础属性'),
        const SizedBox(height: 8),
        const Text('体型体重（kg）', style: TextStyle(fontSize: 13, color: Color(0xFF8BA49A))),
        const SizedBox(height: 8),
        TextFormField(
          controller: _weightController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: _inputDecoration('精确至 kg，如 4.50'),
          onChanged: (value) {
            final parsed = double.tryParse(value.trim());
            onChanged(PetProfileTags(
              weightKg: parsed,
              ageGroup: tags.ageGroup,
              physiologicalStates: tags.physiologicalStates,
              socialFriendliness: tags.socialFriendliness,
              aggressionLevel: tags.aggressionLevel,
              outdoorBehaviors: tags.outdoorBehaviors,
              indoorBehaviors: tags.indoorBehaviors,
              healthTags: tags.healthTags,
            ));
          },
        ),
        const SizedBox(height: 16),
        _SingleSelectChips(
          title: '年龄段',
          options: PetAgeGroup.options,
          selected: tags.ageGroup,
          onSelect: (code) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: code,
            physiologicalStates: tags.physiologicalStates,
            socialFriendliness: tags.socialFriendliness,
            aggressionLevel: tags.aggressionLevel,
            outdoorBehaviors: tags.outdoorBehaviors,
            indoorBehaviors: tags.indoorBehaviors,
            healthTags: tags.healthTags,
          )),
        ),
        const SizedBox(height: 12),
        _MultiSelectChips(
          title: '生理状态',
          options: PetPhysiologicalState.options,
          selected: tags.physiologicalStates,
          onChanged: (selected) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: tags.ageGroup,
            physiologicalStates: selected,
            socialFriendliness: tags.socialFriendliness,
            aggressionLevel: tags.aggressionLevel,
            outdoorBehaviors: tags.outdoorBehaviors,
            indoorBehaviors: tags.indoorBehaviors,
            healthTags: tags.healthTags,
          )),
        ),
        const SizedBox(height: 24),
        _SectionTitle('性格行为特征'),
        const SizedBox(height: 12),
        _StarRating(
          title: '社交友好度',
          value: tags.socialFriendliness,
          onChanged: (value) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: tags.ageGroup,
            physiologicalStates: tags.physiologicalStates,
            socialFriendliness: value,
            aggressionLevel: tags.aggressionLevel,
            outdoorBehaviors: tags.outdoorBehaviors,
            indoorBehaviors: tags.indoorBehaviors,
            healthTags: tags.healthTags,
          )),
        ),
        const SizedBox(height: 12),
        _SingleSelectChips(
          title: '攻击性预警',
          options: PetAggressionLevel.options,
          selected: tags.aggressionLevel,
          onSelect: (code) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: tags.ageGroup,
            physiologicalStates: tags.physiologicalStates,
            socialFriendliness: tags.socialFriendliness,
            aggressionLevel: code,
            outdoorBehaviors: tags.outdoorBehaviors,
            indoorBehaviors: tags.indoorBehaviors,
            healthTags: tags.healthTags,
          )),
        ),
        const SizedBox(height: 12),
        _MultiSelectChips(
          title: '户外行为',
          options: PetOutdoorBehavior.options,
          selected: tags.outdoorBehaviors,
          onChanged: (selected) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: tags.ageGroup,
            physiologicalStates: tags.physiologicalStates,
            socialFriendliness: tags.socialFriendliness,
            aggressionLevel: tags.aggressionLevel,
            outdoorBehaviors: selected,
            indoorBehaviors: tags.indoorBehaviors,
            healthTags: tags.healthTags,
          )),
        ),
        const SizedBox(height: 12),
        _MultiSelectChips(
          title: '室内行为',
          options: PetIndoorBehavior.options,
          selected: tags.indoorBehaviors,
          onChanged: (selected) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: tags.ageGroup,
            physiologicalStates: tags.physiologicalStates,
            socialFriendliness: tags.socialFriendliness,
            aggressionLevel: tags.aggressionLevel,
            outdoorBehaviors: tags.outdoorBehaviors,
            indoorBehaviors: selected,
            healthTags: tags.healthTags,
          )),
        ),
        const SizedBox(height: 24),
        _SectionTitle('健康医疗标签'),
        const SizedBox(height: 12),
        _MultiSelectChips(
          title: '健康标签',
          options: PetHealthTag.options,
          selected: tags.healthTags,
          onChanged: (selected) => onChanged(PetProfileTags(
            weightKg: tags.weightKg,
            ageGroup: tags.ageGroup,
            physiologicalStates: tags.physiologicalStates,
            socialFriendliness: tags.socialFriendliness,
            aggressionLevel: tags.aggressionLevel,
            outdoorBehaviors: tags.outdoorBehaviors,
            indoorBehaviors: tags.indoorBehaviors,
            healthTags: selected,
          )),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1A2621),
      ),
    );
  }
}

class _SingleSelectChips extends StatelessWidget {
  final String title;
  final List<PetTagOption> options;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _SingleSelectChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selected == option.code;
            return GestureDetector(
              onTap: () => onSelect(isSelected ? null : option.code),
              child: _chip(option.label, isSelected),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _MultiSelectChips extends StatelessWidget {
  final String title;
  final List<PetTagOption> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _MultiSelectChips({
    required this.title,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: options.map((option) {
            final isSelected = selected.contains(option.code);
            return GestureDetector(
              onTap: () {
                final updated = List<String>.from(selected);
                if (isSelected) {
                  updated.remove(option.code);
                } else {
                  updated.add(option.code);
                }
                onChanged(updated);
              },
              child: _chip(option.label, isSelected),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _StarRating extends StatelessWidget {
  final String title;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _StarRating({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A))),
        const SizedBox(height: 8),
        Row(
          children: List.generate(5, (index) {
            final star = index + 1;
            final filled = value != null && star <= value!;
            return IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => onChanged(filled && star == value ? null : star),
              icon: Icon(
                filled ? Icons.star_rounded : Icons.star_outline_rounded,
                color: filled ? const Color(0xFFF9A826) : const Color(0xFFB0C4BC),
              ),
            );
          }),
        ),
      ],
    );
  }
}

Widget _chip(String label, bool selected) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 150),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: selected ? const Color(0xFF004D36) : const Color(0xFFF0F4F2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: selected ? Colors.white : const Color(0xFF5A6B62),
      ),
    ),
  );
}

InputDecoration _inputDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB0BDB7)),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xFFE2E8E5)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: const BorderSide(color: Color(0xFF004D36)),
    ),
  );
}
