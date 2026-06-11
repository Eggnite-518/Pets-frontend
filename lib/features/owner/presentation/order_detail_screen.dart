import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pets/core/domain/pet_type.dart';
import 'package:go_router/go_router.dart';
import 'package:pets/core/network/api_client.dart';
import 'package:pets/core/network/api_exception.dart';
import 'package:pets/core/network/api_result.dart';
import 'package:pets/features/caretaker/presentation/alipay_checkout_screen.dart';
import 'package:pets/features/owner/data/datasources/order_remote_data_source.dart';
import 'package:pets/features/owner/data/datasources/review_remote_data_source.dart';
import 'package:pets/features/owner/data/repositories/order_repository_impl.dart';
import 'package:pets/features/owner/domain/entities/order_payment_page.dart';
import 'package:pets/features/owner/domain/entities/order_settlement.dart';
import 'package:pets/features/owner/domain/usecases/confirm_order_exception_resolved_use_case.dart';
import 'package:pets/features/owner/domain/usecases/confirm_order_completion_use_case.dart';
import 'package:pets/features/owner/domain/usecases/create_order_alipay_page_payment_use_case.dart';
import 'package:pets/features/owner/domain/usecases/get_order_candidates_use_case.dart';
import 'package:pets/features/owner/domain/usecases/get_order_by_id_use_case.dart';
import 'package:pets/features/owner/domain/usecases/get_order_settlement_use_case.dart';
import 'package:pets/features/owner/domain/usecases/get_provider_detail_use_case.dart';
import 'package:pets/features/owner/domain/usecases/select_provider_use_case.dart';
import 'package:pets/features/owner/domain/entities/order_candidate.dart';
import 'package:pets/features/owner/domain/entities/order_detail.dart';
import 'package:pets/features/owner/domain/entities/provider_detail.dart';
import 'package:pets/core/widgets/order_requirement_summary.dart';
import 'package:pets/features/owner/domain/entities/order_hard_filter_tag.dart';
import 'package:pets/features/owner/presentation/widgets/candidate_sort_bar.dart';
import 'package:pets/features/owner/presentation/widgets/provider_qualification_sheet.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final ApiClient _orderApiClient = ApiClient();
  final ApiClient _reviewApiClient = ApiClient();
  late final GetOrderByIdUseCase _getOrderByIdUseCase;
  late final GetOrderCandidatesUseCase _getOrderCandidatesUseCase;
  late final GetProviderDetailUseCase _getProviderDetailUseCase;
  late final SelectProviderUseCase _selectProviderUseCase;
  late final CreateOrderAlipayPagePaymentUseCase
  _createOrderAlipayPagePaymentUseCase;
  late final ConfirmOrderExceptionResolvedUseCase
  _confirmOrderExceptionResolvedUseCase;
  late final ConfirmOrderCompletionUseCase _confirmOrderCompletionUseCase;
  late final GetOrderSettlementUseCase _getOrderSettlementUseCase;
  late final OrderRemoteDataSource _orderRemoteDataSource;
  late final ReviewRemoteDataSource _reviewRemoteDataSource;
  bool _isLoading = true;
  bool _isLoadingCandidates = false;
  bool _isLoadingSettlement = false;
  bool _isPaying = false;
  bool _isConfirmingExceptionResolved = false;
  bool _isConfirmingCompletion = false;
  String? _error;
  String? _candidateError;
  String? _providerError;
  String? _settlementError;
  OrderDetail? _detail;
  OrderSettlement? _settlement;
  List<OrderCandidateItem> _candidates = const [];
  String _candidateSortBy = 'distance';
  bool _isCandidateSortLoading = false;
  bool _reviewSubmitted = false;
  String? _selectingProviderId;
  bool? _fulfillmentAllNodesCompleted;
  Timer? _fulfillmentPollTimer;

  bool get _canConfirmCompletion =>
      _detail?.status == 5 && _fulfillmentAllNodesCompleted == true;

  @override
  void initState() {
    super.initState();
    final repository = OrderRepositoryImpl(
      OrderRemoteDataSource(_orderApiClient),
    );
    _getOrderByIdUseCase = GetOrderByIdUseCase(repository);
    _getOrderCandidatesUseCase = GetOrderCandidatesUseCase(repository);
    _getProviderDetailUseCase = GetProviderDetailUseCase(repository);
    _selectProviderUseCase = SelectProviderUseCase(repository);
    _createOrderAlipayPagePaymentUseCase = CreateOrderAlipayPagePaymentUseCase(
      repository,
    );
    _confirmOrderExceptionResolvedUseCase =
        ConfirmOrderExceptionResolvedUseCase(repository);
    _confirmOrderCompletionUseCase = ConfirmOrderCompletionUseCase(repository);
    _getOrderSettlementUseCase = GetOrderSettlementUseCase(repository);
    _orderRemoteDataSource = OrderRemoteDataSource(_orderApiClient);
    _reviewRemoteDataSource = ReviewRemoteDataSource(_reviewApiClient);
    _loadDetail();
  }

  @override
  void dispose() {
    _fulfillmentPollTimer?.cancel();
    _orderApiClient.close();
    _reviewRemoteDataSource.close();
    _reviewApiClient.close();
    super.dispose();
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ApiResult<OrderDetail> result = await _getOrderByIdUseCase.call(
        widget.orderId,
      );
      if (!mounted) return;
      if (result is ApiSuccess<OrderDetail>) {
        final reviewed = result.data.status == 6 ? await _hasRating() : false;
        if (!mounted) return;
        setState(() {
          _detail = result.data;
          _candidateError = null;
          _candidates = result.data.status == 1
              ? const []
              : _fallbackCandidates(result.data.applications);
          _reviewSubmitted = reviewed;
          _isLoading = false;
        });
        if (_shouldLoadSettlement(result.data.status)) {
          await _loadSettlement();
        } else if (mounted) {
          setState(() {
            _settlement = null;
            _settlementError = null;
            _isLoadingSettlement = false;
          });
        }
        if (result.data.status == 1) {
          await _loadCandidates(result.data);
        } else if (result.data.applications.isNotEmpty) {
          setState(() {
            _candidates = _fallbackCandidates(result.data.applications);
          });
        }
        if (result.data.status == 4 || result.data.status == 5) {
          await _loadFulfillmentProgress();
        } else if (mounted) {
          setState(() => _fulfillmentAllNodesCompleted = null);
          _syncFulfillmentPolling();
        }
        return;
      }

      setState(() {
        _error = (result as ApiFailure).error.message;
        _isLoading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load order detail';
        _isLoading = false;
      });
    }
  }

  bool _shouldLoadSettlement(int status) {
    return status == 5 || status == 6 || status == 8;
  }

  Future<void> _loadFulfillmentProgress() async {
    try {
      final response = await _orderRemoteDataSource.getFulfillmentRecords(
        widget.orderId,
      );
      if (!mounted) return;
      if (!response.isSuccess || response.data == null) {
        setState(() => _fulfillmentAllNodesCompleted = false);
        _syncFulfillmentPolling();
        return;
      }
      final allNodesCompleted = response.data!['allNodesCompleted'] == true;
      setState(() => _fulfillmentAllNodesCompleted = allNodesCompleted);
      _syncFulfillmentPolling();
    } catch (_) {
      if (!mounted) return;
      setState(() => _fulfillmentAllNodesCompleted = false);
      _syncFulfillmentPolling();
    }
  }

  void _syncFulfillmentPolling() {
    _fulfillmentPollTimer?.cancel();
    _fulfillmentPollTimer = null;
    final detail = _detail;
    if (detail == null) return;
    final waiting =
        (detail.status == 4 || detail.status == 5) &&
        _fulfillmentAllNodesCompleted != true;
    if (!waiting) return;
    _fulfillmentPollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _loadFulfillmentProgress();
      if (!mounted) return;
      final current = _detail;
      if (current == null || current.status == 6) return;
      if (current.status == 4 || current.status == 5) {
        final result = await _getOrderByIdUseCase.call(widget.orderId);
        if (!mounted || result is! ApiSuccess<OrderDetail>) return;
        if (result.data.status != current.status) {
          await _loadDetail();
        }
      }
    });
  }

  Future<void> _loadCandidates(
    OrderDetail detail, {
    String? sortBy,
    bool sortOnly = false,
  }) async {
    final nextSort = sortBy ?? _candidateSortBy;
    setState(() {
      if (sortOnly) {
        _isCandidateSortLoading = true;
      } else {
        _isLoadingCandidates = true;
      }
      _candidateError = null;
    });

    final result = await _getOrderCandidatesUseCase.call(
      detail.orderId,
      sortBy: nextSort,
    );
    if (!mounted) return;

    if (result is ApiSuccess<OrderCandidateList>) {
      setState(() {
        _candidates = result.data.candidates;
        _candidateSortBy = result.data.sortBy.isNotEmpty
            ? result.data.sortBy
            : nextSort;
        _isLoadingCandidates = false;
        _isCandidateSortLoading = false;
      });
      return;
    }

    final fallback = sortCandidatesLocally(
      candidates: _fallbackCandidates(detail.applications),
      sortBy: nextSort,
      distanceKm: (item) => item.distanceKm,
      rating: (item) => item.rating,
      totalOrderCount: (item) => item.totalOrderCount,
    );
    setState(() {
      _candidateError = (result as ApiFailure).error.message;
      _candidates = fallback;
      _candidateSortBy = nextSort;
      _isLoadingCandidates = false;
      _isCandidateSortLoading = false;
    });
  }

  Future<void> _loadSettlement() async {
    setState(() {
      _isLoadingSettlement = true;
      _settlementError = null;
    });
    final result = await _getOrderSettlementUseCase.call(widget.orderId);
    if (!mounted) return;
    result.when(
      success: (settlement) {
        setState(() {
          _settlement = settlement;
          _isLoadingSettlement = false;
        });
      },
      failure: (error) {
        setState(() {
          _settlement = null;
          _settlementError = _isSettlementEmptyError(error.message)
              ? null
              : error.message;
          _isLoadingSettlement = false;
        });
      },
    );
  }

  bool _isSettlementEmptyError(String message) {
    return message.contains('Backend did not return settlement detail') ||
        message.contains('结算详情') && message.contains('为空') ||
        message.contains('暂无结算');
  }

  Future<void> _onCandidateSortChanged(String sortBy) async {
    if (_candidateSortBy == sortBy || _detail == null) return;
    await _loadCandidates(_detail!, sortBy: sortBy, sortOnly: true);
  }

  List<OrderCandidateItem> _fallbackCandidates(
    List<OrderDetailApplication> applications,
  ) {
    return applications
        .map(
          (application) => OrderCandidateItem(
            applicationId: application.applicationId,
            providerId: application.providerId,
            providerNickname: application.providerNickname,
            providerAvatarUrl: application.providerAvatarUrl,
            applyStatus: application.applyStatus,
            applyStatusDesc: application.applyStatus == 2 ? '已录用' : '',
            distanceKm: null,
            rating: null,
            totalOrderCount: 0,
            creditScore: 0,
          ),
        )
        .toList();
  }

  Future<bool> _hasRating() async {
    try {
      final response = await _reviewRemoteDataSource.getRating(
        orderId: widget.orderId,
      );
      return response.data != null;
    } catch (_) {
      return false;
    }
  }

  Future<void> _openReview() async {
    final submitted = await context.push<bool>(
      '/order/${widget.orderId}/review',
    );
    if (submitted == true) {
      setState(() => _reviewSubmitted = true);
      await _loadDetail();
    }
  }

  Future<void> _openDisputes() async {
    await context.push('/order/${widget.orderId}/disputes');
  }

  Future<void> _openFulfillmentRecords() async {
    await context.push('/order/${widget.orderId}/fulfillment');
    if (!mounted) return;
    final detail = _detail;
    if (detail != null && (detail.status == 4 || detail.status == 5)) {
      await _loadFulfillmentProgress();
      await _loadDetail();
    }
  }

  Future<void> _startAlipayPayment() async {
    if (_isPaying) return;
    setState(() => _isPaying = true);
    final result = await _createOrderAlipayPagePaymentUseCase.call(
      widget.orderId,
    );
    if (!mounted) return;

    if (result case ApiFailure<OrderPaymentPage>(error: final error)) {
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    final payment = (result as ApiSuccess<OrderPaymentPage>).data;
    if (payment.payUrl.trim().isEmpty) {
      setState(() => _isPaying = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('支付表单为空，请稍后重试')));
      return;
    }

    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            AlipayCheckoutScreen(payFormHtml: payment.payUrl, title: '订单支付'),
      ),
    );
    if (!mounted) return;
    setState(() => _isPaying = false);

    if (paid == true) {
      final statusUpdated = await _pollForPaymentResult();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(statusUpdated ? '支付成功，订单已进入待履约' : '已返回订单，支付状态可能稍后更新'),
        ),
      );
      return;
    }

    await _loadDetail();
  }

  Future<bool> _pollForPaymentResult() async {
    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      final result = await _getOrderByIdUseCase.call(widget.orderId);
      if (!mounted) return false;
      if (result case ApiSuccess<OrderDetail>(data: final detail)) {
        if (detail.status != 2) {
          await _loadDetail();
          return true;
        }
      }
    }
    await _loadDetail();
    return false;
  }

  Future<void> _confirmCompletion() async {
    if (_isConfirmingCompletion) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认服务已完成？'),
        content: const Text('确认后平台会立即完成结算，并将托管资金打入宠托师钱包。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('再看看'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认完成'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isConfirmingCompletion = true);
    final result = await _confirmOrderCompletionUseCase.call(widget.orderId);
    if (!mounted) return;
    setState(() => _isConfirmingCompletion = false);

    result.when(
      success: (settlement) async {
        setState(() => _settlement = settlement);
        await _loadDetail();
        if (!mounted) return;
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _SettlementSuccessSheet(settlement: settlement),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  Future<void> _confirmExceptionResolved() async {
    if (_isConfirmingExceptionResolved) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认异常已解决？'),
        content: const Text('确认后订单会恢复为服务中，宠托师可以继续完成后续履约。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('再看看'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认恢复服务'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isConfirmingExceptionResolved = true);
    final result = await _confirmOrderExceptionResolvedUseCase.call(
      widget.orderId,
    );
    if (!mounted) return;
    setState(() => _isConfirmingExceptionResolved = false);

    result.when(
      success: (_) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已通知宠托师继续服务，订单恢复为服务中')));
        await _loadDetail();
      },
      failure: (error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      },
    );
  }

  Future<void> _showProviderDetail(String providerId) async {
    if (_detail == null) return;

    setState(() => _providerError = null);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF004D36)),
      ),
    );

    final result = await _getProviderDetailUseCase.call(
      widget.orderId,
      providerId,
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (result is ApiSuccess<ProviderDetail>) {
      await showProviderQualificationSheet(context, result.data);
      return;
    }

    setState(() {
      _providerError = (result as ApiFailure).error.message;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_providerError ?? '获取宠托师档案失败')));
  }

  Future<void> _selectProvider(OrderCandidateItem candidate) async {
    final detail = _detail;
    if (detail == null || candidate.providerId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认录用这位宠托师？'),
        content: Text(
          candidate.providerNickname.isEmpty
              ? '录用后订单会进入待付款状态。'
              : '录用 ${candidate.providerNickname} 后，订单会进入待付款状态。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确认录用'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _selectingProviderId = candidate.providerId);
    final result = await _selectProviderUseCase.call(
      detail.orderId,
      candidate.providerId,
    );
    if (!mounted) return;
    setState(() => _selectingProviderId = null);

    if (result is ApiSuccess<void>) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已成功录用宠托师')));
      await _loadDetail();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text((result as ApiFailure).error.message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1A2621)),
        title: const Text(
          '订单详情',
          style: TextStyle(
            color: Color(0xFF1A2621),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _OrderStatusPill(status: detail.status),
            ),
        ],
      ),
      body: _buildBody(context),
      bottomNavigationBar: detail != null && !_isLoading && _error == null
          ? _buildBottomBar(detail)
          : null,
    );
  }

  Widget? _buildBottomBar(OrderDetail detail) {
    Widget bar({required Widget child}) {
      return Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: child,
      );
    }

    if (detail.status == 2) {
      return bar(
        child: FilledButton(
          onPressed: _isPaying ? null : _startAlipayPayment,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: _isPaying
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text('去支付 ¥${detail.totalAmount}'),
        ),
      );
    }
    if (detail.status == 5) {
      if (!_canConfirmCompletion) {
        return bar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '宠托师尚未完成全部打卡节点，请稍后再确认结算。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A6B62),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE8F2EF),
                  disabledBackgroundColor: const Color(0xFFE8F2EF),
                  disabledForegroundColor: const Color(0xFF8BA49A),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text('确认完成并结算'),
              ),
            ],
          ),
        );
      }
      return bar(
        child: FilledButton(
          onPressed: _isConfirmingCompletion ? null : _confirmCompletion,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: _isConfirmingCompletion
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('确认完成并结算'),
        ),
      );
    }
    if (detail.status == 7) {
      return bar(
        child: FilledButton(
          onPressed: _isConfirmingExceptionResolved
              ? null
              : _confirmExceptionResolved,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: _isConfirmingExceptionResolved
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('确认已解决，恢复服务'),
        ),
      );
    }
    if (detail.status == 6) {
      return bar(
        child: FilledButton(
          onPressed: _openReview,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF004D36),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          child: Text(_reviewSubmitted ? '查看评价' : '去评价'),
        ),
      );
    }
    return null;
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Color(0xFFB02A37),
              ),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadDetail, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    final detail = _detail!;
    return RefreshIndicator(
      color: const Color(0xFF004D36),
      onRefresh: _loadDetail,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _OwnerDetailBody(
              detail: detail,
              candidates: _candidates,
              isLoadingCandidates: _isLoadingCandidates,
              isCandidateSortLoading: _isCandidateSortLoading,
              candidateSortBy: _candidateSortBy,
              candidateError: _candidateError,
              reviewed: _reviewSubmitted,
              settlement: _settlement,
              isLoadingSettlement: _isLoadingSettlement,
              settlementError: _settlementError,
              fulfillmentAllNodesCompleted: _fulfillmentAllNodesCompleted,
              selectingProviderId: _selectingProviderId,
              onSortChanged: _onCandidateSortChanged,
              onProviderTap: _showProviderDetail,
              onSelectProvider: _selectProvider,
              onViewFulfillment: _openFulfillmentRecords,
              onOpenDisputes: _openDisputes,
              onRetrySettlement: _loadSettlement,
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _OwnerDetailBody extends StatelessWidget {
  final OrderDetail detail;
  final List<OrderCandidateItem> candidates;
  final bool isLoadingCandidates;
  final bool isCandidateSortLoading;
  final String candidateSortBy;
  final String? candidateError;
  final bool reviewed;
  final OrderSettlement? settlement;
  final bool isLoadingSettlement;
  final String? settlementError;
  final bool? fulfillmentAllNodesCompleted;
  final String? selectingProviderId;
  final ValueChanged<String> onSortChanged;
  final void Function(String providerId) onProviderTap;
  final void Function(OrderCandidateItem candidate) onSelectProvider;
  final VoidCallback onViewFulfillment;
  final VoidCallback onOpenDisputes;
  final VoidCallback onRetrySettlement;

  const _OwnerDetailBody({
    required this.detail,
    required this.candidates,
    required this.isLoadingCandidates,
    required this.isCandidateSortLoading,
    required this.candidateSortBy,
    required this.candidateError,
    required this.reviewed,
    required this.settlement,
    required this.isLoadingSettlement,
    required this.settlementError,
    required this.fulfillmentAllNodesCompleted,
    required this.selectingProviderId,
    required this.onSortChanged,
    required this.onProviderTap,
    required this.onSelectProvider,
    required this.onViewFulfillment,
    required this.onOpenDisputes,
    required this.onRetrySettlement,
  });

  OrderCandidateItem? get _selectedCaretaker {
    for (final item in candidates) {
      if (item.applyStatus == 2) return item;
    }
    for (final application in detail.applications) {
      if (application.applyStatus == 2) {
        return OrderCandidateItem(
          applicationId: application.applicationId,
          providerId: application.providerId,
          providerNickname: application.providerNickname,
          providerAvatarUrl: application.providerAvatarUrl,
          applyStatus: application.applyStatus,
          applyStatusDesc: '已录用',
          distanceKm: null,
          rating: null,
          totalOrderCount: 0,
          creditScore: 0,
        );
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final petTitle = detail.pets.isNotEmpty
        ? detail.pets.first.petName
        : '宠物';
    final selected = _selectedCaretaker;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected != null && detail.status != 1) ...[
          _ProviderSection(
            candidate: selected,
            orderId: detail.orderId,
            petName: petTitle,
            onTap: () => onProviderTap(selected.providerId),
            onChat: () => _openChat(context, selected),
          ),
          const _BlockDivider(),
        ],
        _InfoBlock(
          rows: [
            _InfoRow('服务类型', detail.serviceLabel.isEmpty ? '服务' : detail.serviceLabel),
            _InfoRow('服务日期', detail.serviceDate),
            _InfoRow(
              '订单金额',
              '¥${detail.totalAmount}',
              valueStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF003827),
              ),
            ),
          ],
        ),
        const _BlockDivider(),
        _AddressBlock(address: detail.addressSnapshot),
        if (detail.pets.isNotEmpty) ...[
          const _BlockDivider(),
          _PetsBlock(pets: detail.pets),
        ],
        if (detail.hasServiceRequirements) ...[
          const _BlockDivider(),
          _RequirementsBlock(detail: detail),
        ],
        if (detail.status == 1 &&
            (candidates.isNotEmpty ||
                detail.applications.isNotEmpty ||
                isLoadingCandidates)) ...[
          const _BlockDivider(),
          _RenderedApplicants(
            detail: detail,
            candidates: candidates,
            isLoading: isLoadingCandidates,
            isSortLoading: isCandidateSortLoading,
            sortBy: candidateSortBy,
            error: candidateError,
            onSortChanged: onSortChanged,
            onProviderTap: onProviderTap,
            onSelectProvider: onSelectProvider,
            selectingProviderId: selectingProviderId,
          ),
        ],
        if (_shouldShowStatusBlock(detail.status)) ...[
          const _BlockDivider(),
          _OwnerOrderActions(
            detail: detail,
            reviewed: reviewed,
            settlement: settlement,
            isLoadingSettlement: isLoadingSettlement,
            settlementError: settlementError,
            fulfillmentAllNodesCompleted: fulfillmentAllNodesCompleted,
            onRetrySettlement: onRetrySettlement,
          ),
        ],
        if (detail.status >= 4) ...[
          const _BlockDivider(),
          _ListEntryRow(
            icon: Icons.fact_check_outlined,
            title: '服务打卡记录',
            subtitle: '查看宠托师各履约节点的签到与留证',
            onTap: onViewFulfillment,
          ),
        ],
        if (detail.status >= 3) ...[
          const _BlockDivider(),
          _ListEntryRow(
            icon: Icons.gavel_outlined,
            title: '申诉与仲裁',
            subtitle: '对服务过程或判责结果有异议时可提交说明',
            onTap: onOpenDisputes,
          ),
        ],
        const _BlockDivider(),
        _FooterInfo(orderId: detail.orderId),
      ],
    );
  }

  bool _shouldShowStatusBlock(int status) {
    return status == 2 ||
        status == 5 ||
        status == 6 ||
        status == 7 ||
        status == 8 ||
        status == 9 ||
        status == 1 ||
        status == 3 ||
        status == 4;
  }

  void _openChat(BuildContext context, OrderCandidateItem application) {
    final peerName = application.providerNickname.isEmpty
        ? '宠托师'
        : application.providerNickname;
    final query = {
      'peerName': peerName,
      'peerId': application.providerId,
      if (application.providerAvatarUrl.isNotEmpty)
        'peerAvatarUrl': application.providerAvatarUrl,
      if (detail.pets.isNotEmpty && detail.pets.first.petName.isNotEmpty)
        'petName': detail.pets.first.petName,
      'orderId': detail.orderId,
    };
    context.push(
      Uri(path: '/messages/${detail.orderId}', queryParameters: query).toString(),
    );
  }
}

class _ProviderSection extends StatelessWidget {
  final OrderCandidateItem candidate;
  final String orderId;
  final String petName;
  final VoidCallback onTap;
  final VoidCallback onChat;

  const _ProviderSection({
    required this.candidate,
    required this.orderId,
    required this.petName,
    required this.onTap,
    required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final name = candidate.providerNickname.isEmpty ? '宠托师' : candidate.providerNickname;
    final hasAvatar = candidate.providerAvatarUrl.isNotEmpty;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE8F2EF),
              backgroundImage:
                  hasAvatar ? NetworkImage(candidate.providerAvatarUrl) : null,
              child: hasAvatar
                  ? null
                  : Text(
                      name.isNotEmpty ? name[0] : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF004D36),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2621),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (candidate.rating != null)
                        '评分 ${candidate.rating!.toStringAsFixed(1)}',
                      if (candidate.totalOrderCount > 0)
                        '服务 ${candidate.totalOrderCount} 单',
                      if (candidate.rating == null && candidate.totalOrderCount == 0)
                        '点击查看职业资格档案',
                    ].join(' · '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF8BA49A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Material(
            color: const Color(0xFFE8F2EF),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onChat,
              customBorder: const CircleBorder(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.chat_bubble_rounded,
                  size: 20,
                  color: Color(0xFF004D36),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;
  final TextStyle? valueStyle;
  const _InfoRow(this.label, this.value, {this.valueStyle});
}

class _InfoBlock extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoBlock({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: rows.asMap().entries.map((entry) {
          final isLast = entry.key == rows.length - 1;
          final row = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 68,
                  child: Text(
                    row.label,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    row.value.isNotEmpty ? row.value : '--',
                    style: row.valueStyle ??
                        const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1A2621),
                        ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AddressBlock extends StatelessWidget {
  final String address;
  const _AddressBlock({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF004D36)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              address.isEmpty ? '无地址快照' : address,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2621),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PetsBlock extends StatelessWidget {
  final List<OrderDetailPet> pets;
  const _PetsBlock({required this.pets});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '宠物档案',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 10),
          ...pets.asMap().entries.map((entry) {
            final pet = entry.value;
            final isLast = entry.key == pets.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFE8F2EF),
                    child: Icon(
                      pet.petType == 2 ? Icons.pets_rounded : Icons.cruelty_free_rounded,
                      size: 20,
                      color: const Color(0xFF004D36),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet.petName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A2621),
                          ),
                        ),
                        Text(
                          PetType.label(pet.petType),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9E9E9E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RequirementsBlock extends StatelessWidget {
  final OrderDetail detail;
  const _RequirementsBlock({required this.detail});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '服务要求',
            style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
          ),
          const SizedBox(height: 10),
          if (detail.requirementTags.isNotEmpty)
            OrderRequirementSummary(requirementTags: detail.requirementTags),
          if (detail.hardFilterTags.any(OrderHardFilterTag.isSafetyTag)) ...[
            const SizedBox(height: 10),
            _RequirementTagGroup(
              title: '安全属性',
              labels: detail.hardFilterTags
                  .where(OrderHardFilterTag.isSafetyTag)
                  .map((code) => OrderHardFilterTag.labels[code] ?? code)
                  .toList(),
            ),
          ],
          if (detail.hardFilterTags.any(OrderHardFilterTag.isBusinessTag)) ...[
            const SizedBox(height: 10),
            _RequirementTagGroup(
              title: '业务属性',
              labels: detail.hardFilterTags
                  .where(OrderHardFilterTag.isBusinessTag)
                  .map((code) => OrderHardFilterTag.labels[code] ?? code)
                  .toList(),
            ),
          ],
          if (detail.remark.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              detail.remark.trim(),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF3B564A),
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequirementTagGroup extends StatelessWidget {
  final String title;
  final List<String> labels;
  const _RequirementTagGroup({required this.title, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: labels
              .map(
                (label) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F2EF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF004D36)),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _ListEntryRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ListEntryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EF),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: const Color(0xFF004D36), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A2621),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8BA49A),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFC3D5CC)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterInfo extends StatelessWidget {
  final String orderId;
  const _FooterInfo({required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          const Text(
            '订单编号：',
            style: TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
          ),
          Expanded(
            child: Text(
              orderId,
              style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockDivider extends StatelessWidget {
  const _BlockDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 8, color: const Color(0xFFF2F3F5));
  }
}

class _RenderedApplicants extends StatelessWidget {
  final OrderDetail detail;
  final List<OrderCandidateItem> candidates;
  final bool isLoading;
  final bool isSortLoading;
  final String sortBy;
  final String? error;
  final ValueChanged<String> onSortChanged;
  final void Function(String providerId) onProviderTap;
  final void Function(OrderCandidateItem candidate) onSelectProvider;
  final String? selectingProviderId;

  const _RenderedApplicants({
    required this.detail,
    required this.candidates,
    required this.isLoading,
    required this.isSortLoading,
    required this.sortBy,
    required this.error,
    required this.onSortChanged,
    required this.onProviderTap,
    required this.onSelectProvider,
    required this.selectingProviderId,
  });

  void _openChat(BuildContext context, OrderCandidateItem application) {
    final peerName = application.providerNickname.isEmpty
        ? '宠托人'
        : application.providerNickname;
    final query = {
      'peerName': peerName,
      'peerId': application.providerId,
      if (application.providerAvatarUrl.isNotEmpty)
        'peerAvatarUrl': application.providerAvatarUrl,
      if (detail.pets.isNotEmpty && detail.pets.first.petName.isNotEmpty)
        'petName': detail.pets.first.petName,
      'orderId': detail.orderId,
    };
    final uri = Uri(
      path: '/messages/${detail.orderId}',
      queryParameters: query,
    );
    context.push(uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final candidateCount = candidates.isNotEmpty
        ? candidates.length
        : detail.applications.length;
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.status == 1
                ? '候选人列表 ($candidateCount)'
                : '已报名宠托师 ($candidateCount)',
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9E9E9E),
            ),
          ),
          const SizedBox(height: 12),
          if (detail.status == 1 && candidates.isNotEmpty) ...[
            CandidateSortBar(
              selectedSortBy: sortBy,
              onSortChanged: onSortChanged,
              isLoading: isSortLoading,
            ),
            const SizedBox(height: 12),
          ],
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (candidates.isEmpty)
            const Text(
              '暂无报名',
              style: TextStyle(fontSize: 14, color: Color(0xFF8BA49A)),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (error != null && error!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '候选人列表加载失败，当前展示为简版信息',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFB76E00),
                      ),
                    ),
                  ),
                ],
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: candidates.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final a = candidates[index];
                    return _CaretakerCard(
                      name: a.providerNickname.isEmpty
                          ? '宠托师'
                          : a.providerNickname,
                      avatarUrl: a.providerAvatarUrl,
                      tagText: a.applyStatusDesc,
                      tagColor: a.applyStatus == 2
                          ? const Color(0xFF005A40)
                          : const Color(0xFF4A7060),
                      isOutlinedTag: true,
                      rating: a.rating == null
                          ? '—'
                          : a.rating!.toStringAsFixed(1),
                      orderCount: '${a.totalOrderCount}',
                      description: [
                        if (a.distanceKm != null)
                          '距离 ${a.distanceKm!.toStringAsFixed(1)} km',
                        if (a.creditScore > 0) '信用分 ${a.creditScore}',
                      ].join(' · '),
                      onAvatarTap: () => onProviderTap(a.providerId),
                      onTap: () => onProviderTap(a.providerId),
                      isSelected: a.applyStatus == 2,
                      isActionLoading: selectingProviderId == a.providerId,
                      onChat: () => _openChat(context, a),
                      onSelect: detail.status == 1 && a.applyStatus != 2
                          ? () => onSelectProvider(a)
                          : null,
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OwnerOrderActions extends StatelessWidget {
  final OrderDetail detail;
  final bool reviewed;
  final OrderSettlement? settlement;
  final bool isLoadingSettlement;
  final String? settlementError;
  final bool? fulfillmentAllNodesCompleted;
  final VoidCallback onRetrySettlement;

  const _OwnerOrderActions({
    required this.detail,
    required this.reviewed,
    required this.settlement,
    required this.isLoadingSettlement,
    required this.settlementError,
    required this.fulfillmentAllNodesCompleted,
    required this.onRetrySettlement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: switch (detail.status) {
        2 => const _StatusHint(
          icon: Icons.wallet_outlined,
          title: '待支付',
          message: '宠托师已确认接单，请在下方完成支付后订单会进入待履约。',
        ),
        5 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusHint(
              icon: Icons.fact_check_outlined,
              title: fulfillmentAllNodesCompleted == true ? '待确认完成' : '等待宠托师完成打卡',
              message: fulfillmentAllNodesCompleted == true
                  ? '请先查看打卡记录，确认服务无误后在下方完成结算。'
                  : '宠托师尚未完成全部履约节点，完成后你才能确认结算。',
            ),
            const SizedBox(height: 14),
            _SettlementCard(
              settlement: settlement,
              isLoading: isLoadingSettlement,
              error: settlementError,
              onRetry: onRetrySettlement,
              emptyHint: '确认完成后，系统会自动完成结算',
            ),
          ],
        ),
        7 => const _StatusHint(
          icon: Icons.warning_amber_rounded,
          title: '履约受阻，等待你处理',
          message: '系统已提醒宠托师与您确认异常情况。若当前问题已经解决，可在下方恢复服务。',
        ),
        8 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _StatusHint(
              icon: Icons.assignment_late_outlined,
              title: '异常结束',
              message: '本单已按无责撤退规则完成处理，系统会按规则完成退款结算。',
            ),
            const SizedBox(height: 14),
            _SettlementCard(
              settlement: settlement,
              isLoading: isLoadingSettlement,
              error: settlementError,
              onRetry: onRetrySettlement,
              emptyHint: '异常结算完成后会更新处理状态',
            ),
          ],
        ),
        9 => const _StatusHint(
          icon: Icons.sos_outlined,
          title: '平台紧急介入中',
          message: '宠托师已发起紧急求助，订单暂时终止并转由平台人工介入，请尽快关注系统通知。',
        ),
        6 => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StatusHint(
              icon: Icons.check_circle_outline,
              title: '服务已完成',
              message: reviewed
                  ? '平台已完成本单结算，你可以在下方查看评价。'
                  : '平台已完成本单结算，请在下方提交服务评价。',
            ),
            const SizedBox(height: 14),
            _SettlementCard(
              settlement: settlement,
              isLoading: isLoadingSettlement,
              error: settlementError,
              onRetry: onRetrySettlement,
            ),
          ],
        ),
        _ => _StatusFooter(status: detail.status),
      },
    );
  }
}

class _StatusHint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StatusHint({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF004D36)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2621),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF8BA49A),
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final OrderSettlement? settlement;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final String emptyHint;

  const _SettlementCard({
    required this.settlement,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    this.emptyHint = '暂无结算信息',
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF005A40),
            ),
          ),
          SizedBox(width: 10),
          Text('正在获取结算信息...', style: TextStyle(fontSize: 13)),
        ],
      );
    }

    if (error != null && error!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '结算信息加载失败',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2621),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF8BA49A),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('重新获取')),
        ],
      );
    }

    final value = settlement;
    if (value == null) {
      return Text(
        emptyHint,
        style: const TextStyle(fontSize: 13, color: Color(0xFF8BA49A)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '结算状态',
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E)),
            ),
            const Spacer(),
            _SettlementStatusPill(
              status: value.settlementStatus,
              label: value.settlementStatusDesc,
            ),
          ],
        ),
        if (value.settledAt.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '完成时间 ${_formatDateTime(value.settledAt)}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF8BA49A)),
          ),
        ],
      ],
    );
  }
}

class _SettlementSuccessSheet extends StatelessWidget {
  final OrderSettlement settlement;

  const _SettlementSuccessSheet({required this.settlement});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFFF7F9F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F2EF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Color(0xFF005A40),
                  size: 30,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Center(
              child: Text(
                '确认完成',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0B2A1F),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '本单 ¥${settlement.grossAmount} 已完成结算，感谢你的信任。',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF5A6B62),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF005A40),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: const Text('我知道了'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3. 通用宠托师卡片
class _CaretakerCard extends StatelessWidget {
  final String name, tagText, rating, orderCount, description;
  final String avatarUrl;
  final Color tagColor;
  final bool isOutlinedTag;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onChat;
  final VoidCallback? onSelect;
  final bool isActionLoading;

  const _CaretakerCard({
    required this.name,
    required this.avatarUrl,
    required this.tagText,
    required this.rating,
    required this.orderCount,
    required this.description,
    required this.tagColor,
    required this.isOutlinedTag,
    required this.isSelected,
    required this.onTap,
    this.onAvatarTap,
    this.onChat,
    this.onSelect,
    this.isActionLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final canChat = onChat != null;
    final canSelect = onSelect != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onAvatarTap ?? onTap,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFFE8F2EF),
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: Color(0xFF004D36))
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        if (tagText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            tagText,
                            style: TextStyle(
                              fontSize: 11,
                              color: tagColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (canChat) ...[
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: onChat,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Color(0xFF004D36),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          color: Color(0xFFF9A826),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const Text(' · ', style: TextStyle(color: Colors.grey)),
                        Text(
                          '服务 $orderCount 单',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF666666),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF8BA49A),
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (canSelect || isSelected) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: const BorderSide(color: Color(0xFFE8E8E8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('查看档案', style: TextStyle(fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: isActionLoading
                        ? null
                        : isSelected
                        ? onChat
                        : onSelect,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF004D36),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: isActionLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isSelected
                                ? '聊天'
                                : canSelect
                                ? '立即录用'
                                : '已处理',
                            style: const TextStyle(fontSize: 14),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// 4. 底部等待提示区
class _OrderStatusPill extends StatelessWidget {
  final int status;

  const _OrderStatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = _statusScheme(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        scheme.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.foreground,
        ),
      ),
    );
  }
}

class _SettlementStatusPill extends StatelessWidget {
  final int status;
  final String label;

  const _SettlementStatusPill({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final background = status == 2
        ? const Color(0xFFE8F2EF)
        : const Color(0xFFFFF3E3);
    final foreground = status == 2
        ? const Color(0xFF005A40)
        : const Color(0xFF9C5A00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? (status == 2 ? '已结算' : '托管中') : label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}

class _StatusFooter extends StatelessWidget {
  final int status;

  const _StatusFooter({required this.status});

  @override
  Widget build(BuildContext context) {
    final icon = switch (status) {
      1 => Icons.hourglass_bottom,
      3 => Icons.schedule_outlined,
      4 => Icons.pets_outlined,
      7 => Icons.warning_amber_rounded,
      8 => Icons.assignment_late_outlined,
      9 => Icons.sos_outlined,
      _ => Icons.info_outline,
    };
    final title = switch (status) {
      1 => '正在等待宠托师响应',
      3 => '订单已支付',
      4 => '服务进行中',
      7 => '订单等待异常处理',
      8 => '订单已异常结束',
      9 => '平台正在紧急介入',
      _ => '订单处理中',
    };
    final message = switch (status) {
      1 => '我们会持续通知符合要求的宠托师，待更多人报名后你可以再回来挑选。',
      3 => '支付完成后，订单已进入待履约阶段，宠托师会在约定时间开始服务。',
      4 => '宠托师正在履约中，完成全部服务节点后，订单会进入待你确认的状态。',
      7 => '系统已就异常情况联系双方。若问题已经解决，你可以在上方恢复服务。',
      8 => '本单已按异常结束处理，平台会根据规则完成补偿与退款。',
      9 => '宠托师已发起紧急求助，平台将优先人工跟进处理。',
      _ => '订单状态已更新，请稍后查看最新进展。',
    };
    return _StatusHint(icon: icon, title: title, message: message);
  }
}

class _StatusScheme {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusScheme({
    required this.label,
    required this.background,
    required this.foreground,
  });
}

_StatusScheme _statusScheme(int status) {
  return switch (status) {
    1 => const _StatusScheme(
      label: '待处理',
      background: Color(0xFFFFF2DF),
      foreground: Color(0xFFC97C22),
    ),
    2 => const _StatusScheme(
      label: '待付款',
      background: Color(0xFFE8F2EF),
      foreground: Color(0xFF0F7A5A),
    ),
    3 => const _StatusScheme(
      label: '待履约',
      background: Color(0xFFEAF2FF),
      foreground: Color(0xFF246BCE),
    ),
    4 => const _StatusScheme(
      label: '服务中',
      background: Color(0xFFE8F2EF),
      foreground: Color(0xFF0F7A5A),
    ),
    5 => const _StatusScheme(
      label: '待确认',
      background: Color(0xFFFFF3E3),
      foreground: Color(0xFF9C5A00),
    ),
    6 => const _StatusScheme(
      label: '已完成',
      background: Color(0xFFE8F2EF),
      foreground: Color(0xFF005A40),
    ),
    7 => const _StatusScheme(
      label: '履约受阻',
      background: Color(0xFFFFF3E3),
      foreground: Color(0xFF9C5A00),
    ),
    8 => const _StatusScheme(
      label: '异常结束',
      background: Color(0xFFF1F3F2),
      foreground: Color(0xFF5A6B62),
    ),
    9 => const _StatusScheme(
      label: '平台介入',
      background: Color(0xFFFCE8EB),
      foreground: Color(0xFFB02A37),
    ),
    _ => const _StatusScheme(
      label: '处理中',
      background: Color(0xFFF1F3F2),
      foreground: Color(0xFF5A6B62),
    ),
  };
}

String _formatDateTime(String value) {
  if (value.trim().isEmpty) return value;
  return value.replaceFirst('T', ' ');
}
