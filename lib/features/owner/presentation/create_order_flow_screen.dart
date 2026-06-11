import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/features/owner/data/datasources/order_remote_data_source.dart';
import 'package:pets/features/owner/data/models/create_order_request.dart';
import 'package:pets/features/owner/data/models/order_quote_request.dart';
import 'package:pets/features/owner/data/repositories/order_repository_impl.dart';
import 'package:pets/features/owner/domain/entities/order_address.dart';
import 'package:pets/features/owner/domain/entities/order_quote.dart';
import 'package:pets/features/owner/domain/entities/order_requirement_tags_data.dart';
import 'package:pets/features/owner/data/datasources/order_quick_fill_remote_data_source.dart';
import 'package:pets/features/owner/domain/entities/address_family_sop.dart';
import 'package:pets/features/owner/domain/entities/reorder_prefill.dart';
import 'package:pets/features/owner/domain/usecases/create_order_use_case.dart';
import 'package:pets/features/owner/domain/usecases/get_order_quote_use_case.dart';
import 'package:pets/features/owner/presentation/pet_archive_model.dart';

import 'step1_basic_info.dart';
import 'step2_service_req.dart';
import 'step3_fee_confirm.dart';

String _formatDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

String _formatTime(DateTime dateTime) =>
    '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

class _OrderFormData {
  List<int> petIds;
  int serviceType;
  OrderAddress? selectedAddress;
  String serviceDate;
  String serviceStartTime;
  String serviceEndTime;
  String remark;
  String finalAmount;
  List<String> hardFilterTags;
  OrderRequirementTagsData requirementTags;

  _OrderFormData({
    required this.petIds,
    required this.serviceType,
    this.selectedAddress,
    required this.serviceDate,
    required this.serviceStartTime,
    required this.serviceEndTime,
    required this.remark,
    required this.finalAmount,
    required this.hardFilterTags,
    required this.requirementTags,
  });
}

/// 发布订单主框架 (只负责顶部进度条、底部按钮和页面调度)
class CreateOrderFlowScreen extends StatefulWidget {
  final String? fromOrderId;

  const CreateOrderFlowScreen({super.key, this.fromOrderId});

  @override
  State<CreateOrderFlowScreen> createState() => _CreateOrderFlowScreenState();
}

class _CreateOrderFlowScreenState extends State<CreateOrderFlowScreen> {
  int _currentStep = 0; // 0: 基础信息, 1: 服务要求, 2: 费用确认
  bool _isSubmitting = false;
  bool _isQuoteLoading = false;
  bool _isFinalAmountValid = true;
  String? _quoteError;
  OrderQuote? _orderQuote;
  late final CreateOrderUseCase _createOrderUseCase;
  late final GetOrderQuoteUseCase _getOrderQuoteUseCase;
  late final OrderQuickFillRemoteDataSource _quickFillDataSource;
  final ApiClient _petArchiveClient = ApiClient();
  bool _isPetArchiveLoading = true;
  bool _isPrefillLoading = false;
  bool _isSavingFamilySop = false;
  String? _prefillSourceLabel;
  String? _petArchiveError;
  List<PetArchiveModel> _petArchives = const [];
  final _OrderFormData _orderFormData = _OrderFormData(
    petIds: const [],
    serviceType: 0,
    selectedAddress: null,
    serviceDate: _formatDate(DateTime.now()),
    serviceStartTime: _formatTime(DateTime.now().add(const Duration(hours: 1))),
    serviceEndTime: _formatTime(DateTime.now().add(const Duration(hours: 2))),
    remark: '',
    finalAmount: '0.00',
    hardFilterTags: const [],
    requirementTags: const OrderRequirementTagsData(),
  );

  @override
  void initState() {
    super.initState();
    final repository = OrderRepositoryImpl(OrderRemoteDataSource(ApiClient()));
    _createOrderUseCase = CreateOrderUseCase(repository);
    _getOrderQuoteUseCase = GetOrderQuoteUseCase(repository);
    _quickFillDataSource = OrderQuickFillRemoteDataSource(ApiClient());
    _loadPetArchives();
    if (widget.fromOrderId != null && widget.fromOrderId!.isNotEmpty) {
      _loadReorderPrefill(widget.fromOrderId!);
    }
  }

  @override
  void dispose() {
    _petArchiveClient.close();
    super.dispose();
  }

  DateTime _defaultServiceStart() {
    final base = DateTime.now().add(const Duration(days: 1));
    return DateTime(base.year, base.month, base.day, 10, 0);
  }

  Future<void> _loadReorderPrefill(String orderId) async {
    setState(() {
      _isPrefillLoading = true;
      _prefillSourceLabel = null;
    });
    final response = await _quickFillDataSource.getReorderPrefill(orderId);
    if (!mounted) return;
    if (!response.isSuccess || response.data == null) {
      setState(() => _isPrefillLoading = false);
      _showSnackBar(response.message.isEmpty ? '加载历史订单失败' : response.message);
      return;
    }
    _applyReorderPrefill(response.data!);
    setState(() {
      _isPrefillLoading = false;
      _prefillSourceLabel = response.data!.addressId == null
          ? '已载入历史参数，原地址已失效，请重新选择地址并修改服务时间'
          : '已载入历史订单，请修改服务时间后发布';
    });
  }

  void _applyReorderPrefill(ReorderPrefill prefill) {
    final start = _defaultServiceStart();
    final end = start.add(const Duration(hours: 1));
    setState(() {
      _orderFormData.petIds = List<int>.from(prefill.petIds);
      _orderFormData.serviceType = prefill.uiServiceType;
      _orderFormData.selectedAddress = prefill.toOrderAddress();
      _orderFormData.serviceDate = _formatDate(start);
      _orderFormData.serviceStartTime = _formatTime(start);
      _orderFormData.serviceEndTime = _formatTime(end);
      _orderFormData.remark = prefill.remark;
      _orderFormData.hardFilterTags = List<String>.from(prefill.hardFilterTags);
      _orderFormData.requirementTags = prefill.requirementTags;
      _orderQuote = null;
      _quoteError = null;
    });
  }

  void _applyFamilySop(AddressFamilySop sop) {
    setState(() {
      _orderFormData.requirementTags = sop.requirementTags;
      _orderFormData.hardFilterTags = List<String>.from(sop.hardFilterTags);
      if (sop.remark.trim().isNotEmpty) {
        _orderFormData.remark = sop.remark;
      }
      _orderQuote = null;
      _quoteError = null;
    });
  }

  Future<void> _maybeOfferFamilySop(int addressId) async {
    final response = await _quickFillDataSource.getFamilySop(addressId);
    if (!mounted || !response.isSuccess || response.data == null) return;
    final sop = response.data!;
    if (!sop.hasSop) return;

    final apply = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('带入家庭 SOP？'),
        content: const Text(
          '检测到该地址已保存家庭 SOP（位置指引、入户方式、收尾要求等），是否自动填充到本次服务要求？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('暂不'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF004D36),
            ),
            child: const Text('确认带入'),
          ),
        ],
      ),
    );

    if (apply == true && mounted) {
      _applyFamilySop(sop);
      _showSnackBar('已带入家庭 SOP');
    }
  }

  Future<void> _saveFamilySop() async {
    final address = _orderFormData.selectedAddress;
    if (address == null) {
      _showSnackBar('请先在第一步选择服务地址');
      return;
    }
    if (_orderFormData.requirementTags.isEmpty &&
        _orderFormData.hardFilterTags.isEmpty &&
        _orderFormData.remark.trim().isEmpty) {
      _showSnackBar('请先填写服务要求后再保存');
      return;
    }
    if (_isSavingFamilySop) return;

    setState(() => _isSavingFamilySop = true);
    final body = AddressFamilySop(
      addressId: address.addressId,
      hasSop: true,
    ).toSaveBody(
      requirementTags: _orderFormData.requirementTags,
      hardFilterTags: _orderFormData.hardFilterTags,
      remark: _orderFormData.remark,
    );
    final response = await _quickFillDataSource.saveFamilySop(
      addressId: address.addressId,
      body: body,
    );
    if (!mounted) return;
    setState(() => _isSavingFamilySop = false);
    if (response.isSuccess) {
      _showSnackBar('已保存为该地址的家庭 SOP');
      return;
    }
    _showSnackBar(response.message.isEmpty ? '保存家庭 SOP 失败' : response.message);
  }

  Future<void> _submitOrder() async {
    if (_isSubmitting) return;
    if (!_isFinalAmountValid) {
      _showSnackBar('订单价格低于行业底价保护标准，请调整。');
      return;
    }
    setState(() => _isSubmitting = true);

    final request = CreateOrderRequest(
      serviceType: _orderFormData.serviceType + 1, // 0->1, 1->2
      petIds: _orderFormData.petIds.map((id) => id.toString()).toList(),
      addressId: _orderFormData.selectedAddress!.addressId.toString(),
      serviceDate: _orderFormData.serviceDate,
      serviceStartTime: _orderFormData.serviceStartTime,
      serviceEndTime: _orderFormData.serviceEndTime,
      finalAmount: _orderFormData.finalAmount,
      remark: _orderFormData.remark.isEmpty ? null : _orderFormData.remark,
      hardFilterTags: _orderFormData.hardFilterTags.isEmpty
          ? null
          : _orderFormData.hardFilterTags,
      requirementTags: _orderFormData.requirementTags.isEmpty
          ? null
          : _orderFormData.requirementTags.toJson(),
    );

    final result = await _createOrderUseCase(request);

    if (!mounted) return;

    result.when(
      success: (data) {
        context.go('/order/success?orderId=${data.orderId}');
      },
      failure: (error) {
        _showSnackBar(error.message);
      },
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAddressSelection() async {
    final result = await context.push<Map<String, dynamic>>(
      '/profile/address-template/create',
      extra: {'selectMode': true},
    );

    if (!mounted || result == null) return;

    final selectedAddress = OrderAddress.fromMap(result);
    setState(() {
      _orderFormData.selectedAddress = selectedAddress;
      _orderQuote = null;
      _quoteError = null;
    });
    await _maybeOfferFamilySop(selectedAddress.addressId);
  }

  Future<void> _openAddPet() async {
    await context.push('/profile/add-pet');
    if (mounted) {
      _loadPetArchives();
    }
  }

  Future<void> _loadPetArchives() async {
    setState(() {
      _isPetArchiveLoading = true;
      _petArchiveError = null;
    });

    try {
      final response = await _petArchiveClient.get<List<PetArchiveModel>>(
        path: '/api/v1/pet-archives',
        dataParser: (data) {
          final list = data as List<dynamic>;
          return list
              .map(
                (item) => PetArchiveModel.fromJson(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();
        },
      );

      if (!mounted) return;

      if (response.isSuccess) {
        setState(() {
          _petArchives = response.data ?? const [];
          _isPetArchiveLoading = false;
        });
        return;
      }

      setState(() {
        _petArchiveError = response.message.isEmpty
            ? '加载宠物档案失败'
            : response.message;
        _isPetArchiveLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _petArchiveError = error.message;
        _isPetArchiveLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _petArchiveError = '加载宠物档案失败';
        _isPetArchiveLoading = false;
      });
    }
  }

  Future<void> _fetchQuote() async {
    setState(() {
      _isQuoteLoading = true;
      _quoteError = null;
    });

    final request = OrderQuoteRequest(
      petIds: _orderFormData.petIds.map((id) => id.toString()).toList(),
      serviceType: _orderFormData.serviceType + 1, // 0->1, 1->2
      addressId: _orderFormData.selectedAddress!.addressId.toString(),
      serviceDate: _orderFormData.serviceDate,
      serviceStartTime: _orderFormData.serviceStartTime,
      serviceEndTime: _orderFormData.serviceEndTime,
      remark: _orderFormData.remark.isEmpty ? null : _orderFormData.remark,
      hardFilterTags: _orderFormData.hardFilterTags.isEmpty
          ? null
          : _orderFormData.hardFilterTags,
      requirementTags: _orderFormData.requirementTags.isEmpty
          ? null
          : _orderFormData.requirementTags.toJson(),
    );

    final result = await _getOrderQuoteUseCase(request);
    if (!mounted) return;

    result.when(
      success: (quote) {
        setState(() {
          _orderQuote = quote;
          _orderFormData.finalAmount = quote.totalAmount;
          _isFinalAmountValid = true;
          _isQuoteLoading = false;
        });
      },
      failure: (error) {
        setState(() {
          _quoteError = error.message;
          _orderQuote = null;
          _isFinalAmountValid = true;
          _isQuoteLoading = false;
        });
      },
    );
  }

  Future<void> _nextStep() async {
    if (_currentStep == 1) {
      setState(() => _currentStep = 2);
      await _fetchQuote();
      return;
    }

    if (_currentStep < 1) {
      // 验证第一步的必填信息
      if (_orderFormData.petIds.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请选择至少一只宠物')));
        return;
      }

      if (_orderFormData.selectedAddress == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请选择服务地址')));
        return;
      }

      setState(() => _currentStep += 1);
      return;
    }

    if (_isQuoteLoading) {
      return;
    }

    await _submitOrder();
  }

  // --- 核心切换逻辑 ---
  // 根据当前的步骤数，返回对应的组件文件
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return Step1BasicInfo(
          selectedPetIds: _orderFormData.petIds,
          petArchives: _petArchives,
          isPetArchiveLoading: _isPetArchiveLoading,
          petArchiveError: _petArchiveError,
          serviceType: _orderFormData.serviceType,
          serviceDate: _orderFormData.serviceDate,
          serviceStartTime: _orderFormData.serviceStartTime,
          serviceEndTime: _orderFormData.serviceEndTime,
          selectedAddress: _orderFormData.selectedAddress,
          onSelectedPetIdsChanged: (selectedPetIds) {
            setState(() => _orderFormData.petIds = selectedPetIds);
          },
          onServiceTypeChanged: (type) {
            setState(() => _orderFormData.serviceType = type);
          },
          onServiceDateChanged: (date) {
            setState(() => _orderFormData.serviceDate = date);
          },
          onServiceTimeRangeChanged: (startTime, endTime) {
            setState(() {
              _orderFormData.serviceStartTime = startTime;
              _orderFormData.serviceEndTime = endTime;
            });
          },
          onPickAddress: _openAddressSelection,
          onAddPet: _openAddPet,
        );
      case 1:
        return Step2ServiceReq(
          remark: _orderFormData.remark,
          onRemarkChanged: (remark) {
            _orderFormData.remark = remark;
          },
          hardFilterTags: _orderFormData.hardFilterTags,
          onHardFilterTagsChanged: (tags) {
            setState(() => _orderFormData.hardFilterTags = tags);
          },
          requirementTags: _orderFormData.requirementTags,
          onRequirementTagsChanged: (data) {
            setState(() => _orderFormData.requirementTags = data);
          },
          addressLabel: _orderFormData.selectedAddress?.fullAddress,
          onSaveFamilySop: _saveFamilySop,
          isSavingFamilySop: _isSavingFamilySop,
        );
      case 2:
        return Step3FeeConfirm(
          initialFinalAmount: _orderFormData.finalAmount,
          quote: _orderQuote,
          isLoading: _isQuoteLoading,
          errorMessage: _quoteError,
          onRetryQuote: _fetchQuote,
          onFinalAmountChanged: (finalAmount) {
            _orderFormData.finalAmount = finalAmount;
          },
          onPriceValidityChanged: (isValid) {
            if (_isFinalAmountValid == isValid) return;
            setState(() => _isFinalAmountValid = isValid);
          },
          serviceType: _orderFormData.serviceType,
          serviceDate: _orderFormData.serviceDate,
          serviceStartTime: _orderFormData.serviceStartTime,
          serviceEndTime: _orderFormData.serviceEndTime,
          selectedAddress: _orderFormData.selectedAddress,
          hardFilterTags: _orderFormData.hardFilterTags,
          requirementTags: _orderFormData.requirementTags,
          remark: _orderFormData.remark,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep -= 1); // 点左上角也能退回上一步
            } else {
              context.pop();
            }
          },
        ),
        title: const Text(
          '发布订单',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF5A6B62)),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 顶部固定的进度条
          _StepIndicator(currentStep: _currentStep),
          if (_isPrefillLoading)
            const LinearProgressIndicator(
              minHeight: 2,
              color: Color(0xFF004D36),
              backgroundColor: Color(0xFFE2E8E5),
            ),
          if (_prefillSourceLabel != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFE8F2EF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                _prefillSourceLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF004D36),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          // 滚动区域：在这里调用我们写好的切换逻辑
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildCurrentStep(),
            ),
          ),
        ],
      ),
      // 底部操作栏
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 10,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 第一步不显示返回按钮，第二/三步显示
            if (_currentStep > 0) ...[
              OutlinedButton(
                onPressed: () => setState(() => _currentStep -= 1),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  side: const BorderSide(color: Color(0xFFE2E8E5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  '返回',
                  style: TextStyle(fontSize: 16, color: Color(0xFF1A2621)),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // 绿色的下一步按钮
            Expanded(
              child: FilledButton(
                onPressed:
                    _isSubmitting || (_currentStep == 2 && !_isFinalAmountValid)
                    ? null
                    : _nextStep,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF004D36),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isSubmitting)
                      const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    if (_isSubmitting) const SizedBox(width: 8),
                    Text(
                      _currentStep == 0
                          ? '下一步：填写服务要求'
                          : (_currentStep == 1 ? '下一步：确认费用' : '提交订单'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部步骤指示器
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const titles = ['基础信息', '服务要求', '费用确认'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP 0${currentStep + 1}',
                style: const TextStyle(
                  color: Color(0xFF004D36),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${currentStep + 1}/3',
                style: const TextStyle(color: Color(0xFF5A6B62), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            titles[currentStep],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF003827),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(3, (index) {
              final isActive = index <= currentStep;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFF004D36)
                        : const Color(0xFFE2E8E5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
