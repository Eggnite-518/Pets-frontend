import 'package:go_router/go_router.dart';
import 'package:pets/core/auth/auth_token_store.dart';

import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/admin/presentation/admin_review_appeals_screen.dart';
import '../features/dispute/presentation/order_disputes_screen.dart';
import '../features/auth/presentation/password_settings_screen.dart';
import '../features/caretaker/presentation/caretaker_exam_screen.dart';
import '../features/caretaker/presentation/caretaker_review_detail_screen.dart';
import '../features/caretaker/presentation/caretaker_reviews_screen.dart';
import '../features/caretaker/presentation/caretaker_study_material_screen.dart';
import '../features/caretaker/data/models/caretaker_review_models.dart';
import '../features/caretaker/presentation/caretaker_study_screen.dart';
import '../features/caretaker/presentation/caretaker_training_screen.dart';
import '../features/caretaker/presentation/caretaker_verification_screen.dart';
import '../features/caretaker/presentation/all_active_orders_screen.dart';
import '../features/caretaker/presentation/today_completed_orders_screen.dart';
import '../features/caretaker/presentation/all_applications_screen.dart';
import '../features/caretaker/presentation/caretaker_chat_screen.dart';
import '../features/caretaker/presentation/caretaker_home_screen.dart';
import '../features/caretaker/presentation/caretaker_income_screen.dart';
import '../features/caretaker/presentation/caretaker_order_detail_screen.dart';
import '../features/caretaker/presentation/caretaker_deposit_screen.dart';
import '../features/caretaker/presentation/caretaker_withdraw_screen.dart';
import '../features/caretaker/presentation/wallet_recharge_screen.dart';
import '../features/caretaker/presentation/caretaker_messages_screen.dart';
import '../features/caretaker/presentation/caretaker_order_hall_screen.dart';
import '../features/caretaker/presentation/caretaker_profile_screen.dart';
import '../features/caretaker/presentation/caretaker_main_layout.dart';
import '../features/caretaker/presentation/service_check_in_screen.dart';
import '../features/owner/presentation/add_pet_screen.dart';
import '../features/owner/presentation/address_location_picker_screen.dart';
import '../features/owner/presentation/address_template_editor_screen.dart';
import '../features/owner/presentation/create_address_template_screen.dart';
import '../features/owner/presentation/create_order_flow_screen.dart';
import '../features/owner/presentation/order_detail_screen.dart';
import '../features/owner/presentation/owner_fulfillment_records_screen.dart';
import '../features/owner/presentation/order_list_screen.dart';
import '../features/owner/presentation/order_review_screen.dart';
import '../features/owner/presentation/order_success_screen.dart';
import '../features/owner/presentation/owner_chat_screen.dart';
import '../features/owner/presentation/owner_home_screen.dart';
import '../features/owner/presentation/owner_main_layout.dart';
import '../features/owner/presentation/owner_messages_screen.dart';
import '../features/owner/presentation/owner_profile_screen.dart';

class AppRoutes {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    redirect: (context, state) async {
      final token = await AuthTokenStore.instance.readToken();
      final hasToken = token != null && token.isNotEmpty;
      final location = state.matchedLocation;
      final isAuthPublicPage =
          location == '/login' || location == '/forgot-password';

      if (!hasToken && !isAuthPublicPage) return '/login';

      final roleType = await AuthTokenStore.instance.readRoleType();
      final userId = await AuthTokenStore.instance.readUserId();
      final isAdminRoute = state.matchedLocation.startsWith('/admin');
      if (hasToken && isAdminRoute && userId != 999999) {
        if (roleType == 2) return '/caretaker/profile';
        return '/profile';
      }

      // 有 token 但停在登录页（如 App 被系统回收后重启），自动跳转到对应主页
      if (hasToken && location == '/login') {
        if (roleType == 2 || roleType == 3) return '/caretaker';
        return '/home';
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/admin/review-appeals',
        builder: (_, __) => const AdminReviewAppealsScreen(),
      ),
      GoRoute(
        path: '/admin/review-appeals/:appealId',
        builder: (_, state) => AdminReviewAppealDetailScreen(
          appealId: state.pathParameters['appealId']!,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return OwnerMainLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (_, __) => const OwnerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/orders',
                builder: (_, __) => const OrderListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages',
                builder: (_, __) => const OwnerMessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, __) => const OwnerProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return CaretakerMainLayout(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caretaker',
                builder: (_, __) => const CaretakerHomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caretaker/orders',
                builder: (_, __) => const CaretakerOrderHallScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caretaker/messages',
                builder: (_, __) => const CaretakerMessagesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/caretaker/profile',
                builder: (_, __) => const CaretakerProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/profile/add-pet',
        builder: (_, state) {
          final petIdText = state.uri.queryParameters['petId'];
          final petId = int.tryParse(petIdText ?? '');
          return AddPetScreen(petId: petId);
        },
      ),
      GoRoute(
        path: '/profile/address-template/create',
        builder: (_, state) {
          final extra = state.extra;
          final selectMode = extra is Map && extra['selectMode'] == true;
          return CreateAddressTemplateScreen(selectMode: selectMode);
        },
      ),
      GoRoute(
        path: '/profile/address-template/editor',
        builder: (_, state) {
          final addressIdText = state.uri.queryParameters['addressId'];
          final addressId = addressIdText == null
              ? null
              : int.tryParse(addressIdText);
          return AddressTemplateEditorScreen(addressId: addressId);
        },
      ),
      GoRoute(
        path: '/profile/address-template/location-picker',
        builder: (_, state) {
          final extra = state.extra;
          final data = extra is Map
              ? Map<String, dynamic>.from(extra)
              : <String, dynamic>{};
          return AddressLocationPickerScreen(
            initialLatitude: (data['latitude'] as num?)?.toDouble(),
            initialLongitude: (data['longitude'] as num?)?.toDouble(),
          );
        },
      ),
      GoRoute(
        path: '/profile/real-name-verify',
        builder: (_, __) =>
            const CaretakerVerificationScreen(isCaretaker: false),
      ),
      GoRoute(
        path: '/profile/password',
        builder: (_, __) => const PasswordSettingsScreen(),
      ),
      GoRoute(
        path: '/order/create',
        builder: (_, state) => CreateOrderFlowScreen(
          fromOrderId: state.uri.queryParameters['fromOrderId'],
        ),
      ),
      GoRoute(
        path: '/order/success',
        builder: (_, state) {
          final orderId = state.uri.queryParameters['orderId'];
          return OrderSuccessScreen(orderId: orderId);
        },
      ),
      GoRoute(
        path: '/order/:id',
        builder: (_, state) =>
            OrderDetailScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/order/:id/fulfillment',
        builder: (_, state) => OwnerFulfillmentRecordsScreen(
          orderId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/order/:id/review',
        builder: (_, state) =>
            OrderReviewScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/order/:id/disputes',
        builder: (_, state) =>
            OrderDisputesScreen(orderId: state.pathParameters['id']!, isCaretaker: false),
      ),
      GoRoute(
        path: '/messages/:conversationId',
        builder: (_, state) => OwnerChatScreen(
          conversationId: state.pathParameters['conversationId']!,
          peerName: state.uri.queryParameters['peerName'] ?? '',
          peerAvatarUrl: state.uri.queryParameters['peerAvatarUrl'] ?? '',
          peerId: state.uri.queryParameters['peerId'] ?? '',
          petName: state.uri.queryParameters['petName'],
          orderId: state.uri.queryParameters['orderId'],
        ),
      ),
      GoRoute(
        path: '/caretaker/service/:id',
        builder: (_, state) {
          final extra = state.extra;
          final checklistNodeTypes = extra is List
              ? extra
                    .map((e) => int.tryParse(e.toString()))
                    .whereType<int>()
                    .toList()
              : const <int>[];
          return ServiceCheckInScreen(
            serviceId: state.pathParameters['id']!,
            checklistNodeTypes: checklistNodeTypes,
          );
        },
      ),
      GoRoute(
        path: '/caretaker/active-orders',
        builder: (_, __) => const AllActiveOrdersScreen(),
      ),
      GoRoute(
        path: '/caretaker/today-completed',
        builder: (_, __) => const TodayCompletedOrdersScreen(),
      ),
      GoRoute(
        path: '/caretaker/applications',
        builder: (_, __) => const AllApplicationsScreen(),
      ),
      GoRoute(
        path: '/caretaker/messages/:conversationId',
        builder: (_, state) => CaretakerChatScreen(
          conversationId: state.pathParameters['conversationId']!,
          peerName: state.uri.queryParameters['peerName'] ?? '',
          peerAvatarUrl: state.uri.queryParameters['peerAvatarUrl'] ?? '',
          petName: state.uri.queryParameters['petName'],
          orderId: state.uri.queryParameters['orderId'],
        ),
      ),
      GoRoute(
        path: '/caretaker/withdraw',
        builder: (_, state) => CaretakerWithdrawScreen(
          currentBalance: state.uri.queryParameters['balance'] ?? '0.00',
        ),
      ),
      GoRoute(
        path: '/wallet/withdraw',
        builder: (_, state) => CaretakerWithdrawScreen(
          currentBalance: state.uri.queryParameters['balance'] ?? '0.00',
        ),
      ),
      GoRoute(
        path: '/wallet/recharge',
        builder: (_, state) => WalletRechargeScreen(
          currentBalance: state.uri.queryParameters['balance'] ?? '0.00',
        ),
      ),
      GoRoute(
        path: '/caretaker/deposit',
        builder: (_, __) => const CaretakerDepositScreen(),
      ),
      GoRoute(
        path: '/caretaker/income',
        builder: (_, __) => const CaretakerIncomeScreen(),
      ),
      GoRoute(
        path: '/caretaker/order/:orderId',
        builder: (_, state) {
          final extra = state.extra;
          final initialHasApplied = extra == true;
          return CaretakerOrderDetailScreen(
            orderId: state.pathParameters['orderId']!,
            initialHasApplied: initialHasApplied,
          );
        },
      ),
      GoRoute(
        path: '/caretaker/order/:orderId/disputes',
        builder: (_, state) => OrderDisputesScreen(
          orderId: state.pathParameters['orderId']!,
          isCaretaker: true,
        ),
      ),
      GoRoute(
        path: '/caretaker/auth',
        builder: (_, state) {
          final canSkip = state.uri.queryParameters['canSkip'] == 'true';
          return CaretakerVerificationScreen(canSkip: canSkip);
        },
      ),
      GoRoute(
        path: '/caretaker/training',
        builder: (_, __) => const CaretakerTrainingScreen(),
      ),
      GoRoute(
        path: '/caretaker/training/study',
        builder: (_, state) => CaretakerStudyScreen(
          readOnly: state.uri.queryParameters['readOnly'] == 'true',
        ),
      ),
      GoRoute(
        path: '/caretaker/training/study/:materialId',
        builder: (_, state) => CaretakerStudyMaterialScreen(
          materialId: state.pathParameters['materialId']!,
          readOnly: state.uri.queryParameters['readOnly'] == 'true',
        ),
      ),
      GoRoute(
        path: '/caretaker/training/exam',
        builder: (_, __) => const CaretakerExamScreen(),
      ),
      GoRoute(
        path: '/caretaker/reviews',
        builder: (_, __) => const CaretakerReviewsScreen(),
      ),
      GoRoute(
        path: '/caretaker/reviews/:reviewId',
        builder: (_, state) {
          final extra = state.extra;
          return CaretakerReviewDetailScreen(
            reviewId: state.pathParameters['reviewId']!,
            initialReview:
                extra is CaretakerReviewItem ? extra : null,
          );
        },
      ),
    ],
  );
}
