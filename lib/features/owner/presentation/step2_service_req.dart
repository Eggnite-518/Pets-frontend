import 'package:flutter/material.dart';
import 'package:pets/features/owner/domain/entities/order_hard_filter_tag.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tag.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';

class Step2ServiceReq extends StatefulWidget {
  final String remark;
  final ValueChanged<String> onRemarkChanged;
  final List<String> hardFilterTags;
  final ValueChanged<List<String>> onHardFilterTagsChanged;
  final OrderRequirementTagsData requirementTags;
  final ValueChanged<OrderRequirementTagsData> onRequirementTagsChanged;
  final String? addressLabel;
  final Future<void> Function()? onSaveFamilySop;
  final bool isSavingFamilySop;

  const Step2ServiceReq({
    super.key,
    required this.remark,
    required this.onRemarkChanged,
    required this.hardFilterTags,
    required this.onHardFilterTagsChanged,
    required this.requirementTags,
    required this.onRequirementTagsChanged,
    this.addressLabel,
    this.onSaveFamilySop,
    this.isSavingFamilySop = false,
  });

  @override
  State<Step2ServiceReq> createState() => _Step2ServiceReqState();
}

class _Step2ServiceReqState extends State<Step2ServiceReq> {
  late final TextEditingController _remarkController;
  late final TextEditingController _accessNoteController;
  late final TextEditingController _emergencyNameController;
  late final TextEditingController _emergencyPhoneController;

  @override
  void initState() {
    super.initState();
    _remarkController = TextEditingController(text: widget.remark);
    _accessNoteController = TextEditingController(text: widget.requirementTags.accessNote);
    _emergencyNameController =
        TextEditingController(text: widget.requirementTags.emergencyContactName);
    _emergencyPhoneController =
        TextEditingController(text: widget.requirementTags.emergencyContactPhone);

    _remarkController.addListener(() => widget.onRemarkChanged(_remarkController.text));
    _accessNoteController.addListener(_notifyRequirementChanged);
    _emergencyNameController.addListener(_notifyRequirementChanged);
    _emergencyPhoneController.addListener(_notifyRequirementChanged);
  }

  @override
  void dispose() {
    _remarkController.dispose();
    _accessNoteController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Step2ServiceReq oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.remark != widget.remark &&
        _remarkController.text != widget.remark) {
      _remarkController.text = widget.remark;
    }
    if (oldWidget.requirementTags != widget.requirementTags) {
      if (_accessNoteController.text != widget.requirementTags.accessNote) {
        _accessNoteController.text = widget.requirementTags.accessNote;
      }
      if (_emergencyNameController.text !=
          widget.requirementTags.emergencyContactName) {
        _emergencyNameController.text =
            widget.requirementTags.emergencyContactName;
      }
      if (_emergencyPhoneController.text !=
          widget.requirementTags.emergencyContactPhone) {
        _emergencyPhoneController.text =
            widget.requirementTags.emergencyContactPhone;
      }
    }
  }

  void _notifyRequirementChanged() {
    widget.onRequirementTagsChanged(
      widget.requirementTags.copyWith(
        accessNote: _accessNoteController.text,
        emergencyContactName: _emergencyNameController.text,
        emergencyContactPhone: _emergencyPhoneController.text,
      ),
    );
  }

  void _toggleHardFilterTag(String tagCode) {
    final updated = List<String>.from(widget.hardFilterTags);
    if (updated.contains(tagCode)) {
      updated.remove(tagCode);
    } else {
      updated.add(tagCode);
    }
    widget.onHardFilterTagsChanged(updated);
  }

  void _toggleRequirementTag(String tagCode) {
    final updated = List<String>.from(widget.requirementTags.tags);
    if (updated.contains(tagCode)) {
      updated.remove(tagCode);
    } else {
      updated.add(tagCode);
    }
    widget.onRequirementTagsChanged(
      widget.requirementTags.copyWith(tags: updated),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionCard(
          icon: Icons.inventory_2_outlined,
          title: '物品引导',
          subtitle: '勾选本次服务需要宠托师了解的物品位置',
          child: _TagSelector(
            tags: OrderRequirementTag.itemGuideTags,
            selectedTags: widget.requirementTags.tags,
            onToggle: _toggleRequirementTag,
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          icon: Icons.door_front_door_outlined,
          title: '环境交代',
          subtitle: '勾选门禁获取方式，并补充说明与紧急联系人',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TagSelector(
                tags: OrderRequirementTag.environmentTags,
                selectedTags: widget.requirementTags.tags,
                onToggle: _toggleRequirementTag,
              ),
              const SizedBox(height: 16),
              const Text(
                '门禁/入户补充说明',
                style: TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
              ),
              const SizedBox(height: 8),
              _GreenTextField(
                controller: _accessNoteController,
                maxLines: 2,
                hintText: '例如：门禁密码 1234#，钥匙放在门口地垫下',
              ),
              const SizedBox(height: 16),
              const Text(
                '紧急联系人',
                style: TextStyle(fontSize: 13, color: Color(0xFF5A6B62)),
              ),
              const SizedBox(height: 8),
              _GreenTextField(
                controller: _emergencyNameController,
                hintText: '联系人姓名',
              ),
              const SizedBox(height: 10),
              _GreenTextField(
                controller: _emergencyPhoneController,
                hintText: '联系人电话',
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          icon: Icons.videocam_outlined,
          title: '视频/拍照要求',
          subtitle: '勾选入户、离户及过程留档要求',
          child: _TagSelector(
            tags: OrderRequirementTag.videoCheckinTags,
            selectedTags: widget.requirementTags.tags,
            onToggle: _toggleRequirementTag,
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          icon: Icons.sports_esports_outlined,
          title: '服务选项',
          subtitle: '陪玩 +5 元/次，清洁 +10 元/次，勾选后计入报价',
          child: _TagSelector(
            tags: OrderRequirementTag.serviceOptionTags,
            selectedTags: widget.requirementTags.tags,
            onToggle: _toggleRequirementTag,
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          icon: Icons.restaurant,
          title: '服务说明',
          child: _GreenTextField(
            controller: _remarkController,
            maxLines: 4,
            hintText: '补充其他个性化要求（可选）',
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          icon: Icons.shield_outlined,
          title: '安全属性',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '针对独居女性雇主的定向隐私保护，勾选后仅匹配女性宠托师',
                style: TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: OrderHardFilterTag.ownerSafetySelectable.map((tagCode) {
                  final label = OrderHardFilterTag.labels[tagCode] ?? tagCode;
                  final selected = widget.hardFilterTags.contains(tagCode);
                  return _SelectableTagChip(
                    label: label,
                    selected: selected,
                    onTap: () => _toggleHardFilterTag(tagCode),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        _SectionCard(
          icon: Icons.verified_user_outlined,
          title: '业务属性要求',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '选择后仅推送给具备对应能力的宠托师',
                style: TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: OrderHardFilterTag.ownerBusinessSelectable.map((tagCode) {
                  final label = OrderHardFilterTag.labels[tagCode] ?? tagCode;
                  final selected = widget.hardFilterTags.contains(tagCode);
                  return _SelectableTagChip(
                    label: label,
                    selected: selected,
                    onTap: () => _toggleHardFilterTag(tagCode),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        if (widget.onSaveFamilySop != null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: widget.isSavingFamilySop ? null : widget.onSaveFamilySop,
            icon: widget.isSavingFamilySop
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.bookmark_add_outlined, size: 18),
            label: Text(
              widget.addressLabel == null || widget.addressLabel!.isEmpty
                  ? '保存为家庭 SOP（需先选地址）'
                  : '保存为该地址的家庭 SOP',
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF004D36),
              side: const BorderSide(color: Color(0xFF004D36)),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          if (widget.addressLabel != null && widget.addressLabel!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '绑定地址：${widget.addressLabel}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
            ),
          ],
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

class _TagSelector extends StatelessWidget {
  final List<String> tags;
  final List<String> selectedTags;
  final ValueChanged<String> onToggle;

  const _TagSelector({
    required this.tags,
    required this.selectedTags,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((tagCode) {
        final label = OrderRequirementTag.labels[tagCode] ?? tagCode;
        final selected = selectedTags.contains(tagCode);
        return _SelectableTagChip(
          label: label,
          selected: selected,
          onTap: () => onToggle(tagCode),
        );
      }).toList(),
    );
  }
}

class _SelectableTagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF004D36) : const Color(0xFFE8F2EF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF004D36) : const Color(0xFFD4EDE4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: selected ? Colors.white : const Color(0xFF5A6B62),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFF5A6B62),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEBEBEB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF004D36), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2621),
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 34),
              child: Text(
                subtitle!,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _GreenTextField extends StatelessWidget {
  final TextEditingController? controller;
  final int maxLines;
  final String? hintText;
  final TextInputType? keyboardType;

  const _GreenTextField({
    this.controller,
    this.maxLines = 1,
    this.hintText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF8BA49A)),
        filled: true,
        fillColor: const Color(0xFFE8F2EF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      style: const TextStyle(fontSize: 15, color: Color(0xFF1A2621)),
    );
  }
}
