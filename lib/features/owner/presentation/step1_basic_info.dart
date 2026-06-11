import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pets/features/owner/domain/entities/order_address.dart';
import 'package:pets/features/owner/presentation/pet_archive_model.dart';

class Step1BasicInfo extends StatefulWidget {
  final List<int> selectedPetIds;
  final List<PetArchiveModel> petArchives;
  final bool isPetArchiveLoading;
  final String? petArchiveError;
  final int serviceType;
  final String serviceDate;
  final String serviceStartTime;
  final String serviceEndTime;
  final OrderAddress? selectedAddress;
  final ValueChanged<List<int>> onSelectedPetIdsChanged;
  final ValueChanged<int> onServiceTypeChanged;
  final ValueChanged<String> onServiceDateChanged;
  final void Function(String startTime, String endTime)
  onServiceTimeRangeChanged;
  final VoidCallback onPickAddress;
  final VoidCallback onAddPet;

  const Step1BasicInfo({
    super.key,
    required this.selectedPetIds,
    required this.petArchives,
    required this.isPetArchiveLoading,
    this.petArchiveError,
    required this.serviceType,
    required this.serviceDate,
    required this.serviceStartTime,
    required this.serviceEndTime,
    this.selectedAddress,
    required this.onSelectedPetIdsChanged,
    required this.onServiceTypeChanged,
    required this.onServiceDateChanged,
    required this.onServiceTimeRangeChanged,
    required this.onPickAddress,
    required this.onAddPet,
  });

  @override
  State<Step1BasicInfo> createState() => _Step1BasicInfoState();
}

class _Step1BasicInfoState extends State<Step1BasicInfo> {
  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(widget.serviceDate) ?? DateTime.now();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate.isBefore(now) ? now : initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );

    if (!mounted || picked == null) return;

    final dateString =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    widget.onServiceDateChanged(dateString);
  }

  Future<void> _pickTimeRange() async {
    final selection = await showModalBottomSheet<_TimeRangeSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimeRangePickerSheet(
        initialStartTime: widget.serviceStartTime,
        initialEndTime: widget.serviceEndTime,
      ),
    );
    if (!mounted || selection == null) return;

    if (!selection.end.isAfter(selection.start)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('结束时间必须晚于开始时间')));
      return;
    }

    widget.onServiceTimeRangeChanged(selection.startLabel, selection.endLabel);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- 模块 1：选择宠物 ---
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '选择宠物',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2621),
              ),
            ),
            Text(
              '已选择 ${widget.selectedPetIds.length}',
              style: const TextStyle(fontSize: 14, color: Color(0xFF004D36)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // 添加宠物按钮
              InkWell(
                onTap: widget.onAddPet,
                borderRadius: BorderRadius.circular(36),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFC3D5CC),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Color(0xFF5A6B62),
                        size: 26,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const SizedBox(
                      width: 76,
                      child: Text(
                        '添加宠物',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A6B62),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              if (widget.isPetArchiveLoading)
                const SizedBox(
                  width: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.petArchiveError != null)
                Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF2D2D0)),
                  ),
                  child: Text(
                    widget.petArchiveError!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFFB02A37),
                    ),
                  ),
                )
              else if (widget.petArchives.isEmpty)
                Container(
                  width: 220,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F6F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD7E5DD)),
                  ),
                  child: const Text(
                    '暂无宠物档案，请先添加宠物',
                    style: TextStyle(fontSize: 14, color: Color(0xFF5A6B62)),
                  ),
                )
              else
                ...widget.petArchives.map((pet) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: _buildPetItem(
                      pet.petId,
                      pet.petName,
                      pet.displayImagePath,
                    ),
                  );
                }),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // --- 模块 2：服务类型 ---
        const Text(
          '服务类型',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildServiceTypeCard(
                0,
                '喂',
                'Feeding & Care',
                Icons.pets_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildServiceTypeCard(
                1,
                '遛',
                'Outdoor Walking',
                Icons.directions_walk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // --- 模块 3：服务时间 ---
        const Text(
          '服务时间',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(16),
          child: _TimeRowItem(
            icon: Icons.calendar_today_outlined,
            title: '服务日期',
            value: widget.serviceDate,
            trailingIcon: Icons.chevron_right,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: _pickTimeRange,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFF7D8C9), width: 1.5),
            ),
            child: _TimeRowItem(
              icon: Icons.access_time,
              title: '首选时段',
              value: '${widget.serviceStartTime} - ${widget.serviceEndTime}',
              trailingIcon: Icons.unfold_more_rounded,
              bgColor: Colors.transparent,
              hasBorder: false,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // --- 模块 4：服务地址 ---
        const Text(
          '服务地址',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A2621),
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: widget.onPickAddress,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFEBEBEB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF004D36),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.selectedAddress?.fullAddress ?? '请选择地址模板',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A2621),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.selectedAddress?.contactName ?? '暂无联系人',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5A6B62),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.selectedAddress?.contactPhone ?? '暂无电话',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5A6B62),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF999999),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildPetItem(int id, String name, String avatarPath) {
    final isSelected = widget.selectedPetIds.contains(id);
    final imageProvider =
        avatarPath.startsWith('http://') || avatarPath.startsWith('https://')
        ? NetworkImage(avatarPath)
        : AssetImage(avatarPath) as ImageProvider;

    return InkWell(
      onTap: () {
        final selected = List<int>.from(widget.selectedPetIds);
        if (isSelected) {
          selected.remove(id);
        } else {
          selected.add(id);
        }
        widget.onSelectedPetIdsChanged(selected);
      },
      borderRadius: BorderRadius.circular(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF004D36)
                    : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: CircleAvatar(backgroundImage: imageProvider),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isSelected
                  ? const Color(0xFF004D36)
                  : const Color(0xFF1A2621),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceTypeCard(
    int index,
    String title,
    String subtitle,
    IconData icon,
  ) {
    final isSelected = widget.serviceType == index;
    return InkWell(
      onTap: () => widget.onServiceTypeChanged(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE8F2EF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF004D36)
                : const Color(0xFFEBEBEB),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? const Color(0xFF004D36)
                  : const Color(0xFF5A6B62),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF004D36)
                    : const Color(0xFF1A2621),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? const Color(0xFF4A7060)
                    : const Color(0xFF8BA49A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeRangeSelection {
  final TimeOfDay start;
  final TimeOfDay end;

  const _TimeRangeSelection({required this.start, required this.end});

  String get startLabel => _format(start);
  String get endLabel => _format(end);

  static String _format(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _TimeRangePickerSheet extends StatefulWidget {
  final String initialStartTime;
  final String initialEndTime;

  const _TimeRangePickerSheet({
    required this.initialStartTime,
    required this.initialEndTime,
  });

  @override
  State<_TimeRangePickerSheet> createState() => _TimeRangePickerSheetState();
}

class _TimeRangePickerSheetState extends State<_TimeRangePickerSheet> {
  late int _startHour;
  late int _startMinute;
  late int _endHour;
  late int _endMinute;

  late final FixedExtentScrollController _startHourController;
  late final FixedExtentScrollController _startMinuteController;
  late final FixedExtentScrollController _endHourController;
  late final FixedExtentScrollController _endMinuteController;

  @override
  void initState() {
    super.initState();
    final start = _parseTime(widget.initialStartTime, fallbackHour: 10);
    final end = _parseTime(widget.initialEndTime, fallbackHour: 11);
    _startHour = start.hour;
    _startMinute = start.minute;
    _endHour = end.hour;
    _endMinute = end.minute;
    _startHourController = FixedExtentScrollController(initialItem: _startHour);
    _startMinuteController = FixedExtentScrollController(
      initialItem: _startMinute,
    );
    _endHourController = FixedExtentScrollController(initialItem: _endHour);
    _endMinuteController = FixedExtentScrollController(initialItem: _endMinute);
  }

  @override
  void dispose() {
    _startHourController.dispose();
    _startMinuteController.dispose();
    _endHourController.dispose();
    _endMinuteController.dispose();
    super.dispose();
  }

  TimeOfDay _parseTime(String value, {required int fallbackHour}) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? fallbackHour;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  TimeOfDay get _startTime => TimeOfDay(hour: _startHour, minute: _startMinute);
  TimeOfDay get _endTime => TimeOfDay(hour: _endHour, minute: _endMinute);

  Duration get _duration {
    final start = Duration(hours: _startHour, minutes: _startMinute);
    final end = Duration(hours: _endHour, minutes: _endMinute);
    return end - start;
  }

  bool get _isValid => _duration.inMinutes > 0;

  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String get _durationLabel {
    if (!_isValid) return '结束时间需晚于开始时间';
    final totalMinutes = _duration.inMinutes;
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '服务时长 $hours 小时';
    }
    if (hours == 0) {
      return '服务时长 $minutes 分钟';
    }
    return '服务时长 $hours 小时 $minutes 分钟';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F9F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E3DF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '选择服务时段',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2621),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '上下滑动选择开始和结束时间。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF5A6B62),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TimePreviewCard(
                        label: '开始',
                        value: _formatTime(_startTime),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimePreviewCard(
                        label: '结束',
                        value: _formatTime(_endTime),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: _isValid
                        ? const Color(0xFFE8F2EF)
                        : const Color(0xFFFFF2EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _durationLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _isValid
                          ? const Color(0xFF004D36)
                          : const Color(0xFFB55635),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TimeWheelGroup(
                        title: '开始时间',
                        hour: _startHour,
                        minute: _startMinute,
                        hourController: _startHourController,
                        minuteController: _startMinuteController,
                        onHourChanged: (value) =>
                            setState(() => _startHour = value),
                        onMinuteChanged: (value) =>
                            setState(() => _startMinute = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _TimeWheelGroup(
                        title: '结束时间',
                        hour: _endHour,
                        minute: _endMinute,
                        hourController: _endHourController,
                        minuteController: _endMinuteController,
                        onHourChanged: (value) =>
                            setState(() => _endHour = value),
                        onMinuteChanged: (value) =>
                            setState(() => _endMinute = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: Color(0xFFD6E2DD)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text(
                          '取消',
                          style: TextStyle(color: Color(0xFF1A2621)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop(
                            _TimeRangeSelection(
                              start: _startTime,
                              end: _endTime,
                            ),
                          );
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF004D36),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('确认时段'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimePreviewCard extends StatelessWidget {
  final String label;
  final String value;

  const _TimePreviewCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF003827),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeWheelGroup extends StatelessWidget {
  final String title;
  final int hour;
  final int minute;
  final FixedExtentScrollController hourController;
  final FixedExtentScrollController minuteController;
  final ValueChanged<int> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _TimeWheelGroup({
    required this.title,
    required this.hour,
    required this.minute,
    required this.hourController,
    required this.minuteController,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: Row(
              children: [
                Expanded(
                  child: _SingleTimeWheel(
                    controller: hourController,
                    values: [for (int i = 0; i < 24; i++) i],
                    suffix: '时',
                    selectedValue: hour,
                    onSelectedItemChanged: onHourChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _SingleTimeWheel(
                    controller: minuteController,
                    values: [for (int i = 0; i < 60; i++) i],
                    suffix: '分',
                    selectedValue: minute,
                    onSelectedItemChanged: onMinuteChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SingleTimeWheel extends StatelessWidget {
  final FixedExtentScrollController controller;
  final List<int> values;
  final String suffix;
  final int selectedValue;
  final ValueChanged<int> onSelectedItemChanged;

  const _SingleTimeWheel({
    required this.controller,
    required this.values,
    required this.suffix,
    required this.selectedValue,
    required this.onSelectedItemChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: Container(
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF5F2),
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        CupertinoPicker(
          scrollController: controller,
          itemExtent: 42,
          useMagnifier: true,
          magnification: 1.06,
          squeeze: 1.15,
          selectionOverlay: const SizedBox.shrink(),
          onSelectedItemChanged: (index) =>
              onSelectedItemChanged(values[index]),
          children: values.map((value) {
            final isSelected = value == selectedValue;
            return Center(
              child: Text(
                '${value.toString().padLeft(2, '0')}$suffix',
                style: TextStyle(
                  fontSize: isSelected ? 18 : 16,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF003827)
                      : const Color(0xFF7A8C84),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _TimeRowItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final IconData trailingIcon;
  final Color bgColor;
  final bool hasBorder;

  const _TimeRowItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.trailingIcon,
    this.bgColor = Colors.white,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: hasBorder ? Border.all(color: const Color(0xFFEBEBEB)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF5A6B62), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8BA49A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A2621),
                  ),
                ),
              ],
            ),
          ),
          Icon(trailingIcon, color: const Color(0xFF999999), size: 20),
        ],
      ),
    );
  }
}
