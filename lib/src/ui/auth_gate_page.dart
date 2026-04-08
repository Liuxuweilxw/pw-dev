import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/platform_api.dart';
import 'platform_shell.dart';

enum _AuthMode { login, register }

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key, required this.api});

  final PlatformApi api;

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  _AuthMode mode = _AuthMode.login;
  UserRole registerRole = UserRole.boss;
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController registerDisplayNameController =
      TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool submitting = false;
  String? error;
  bool authenticated = false;
  UserRole authenticatedRole = UserRole.boss;
  String authenticatedUserId = '';

  Future<void> _handleLogout() async {
    if (!mounted) {
      return;
    }
    setState(() {
      authenticated = false;
      mode = _AuthMode.login;
      passwordController.clear();
      error = null;
      submitting = false;
      authenticatedUserId = '';
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    registerDisplayNameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = usernameController.text.trim();
    final password = passwordController.text.trim();
    final registerDisplayName = registerDisplayNameController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      setState(() => error = '手机号和密码不能为空');
      return;
    }

    if (mode == _AuthMode.register && registerDisplayName.isEmpty) {
      setState(() => error = '注册时请填写用户名称');
      return;
    }

    setState(() {
      submitting = true;
      error = null;
    });

    try {
      final session = mode == _AuthMode.login
          ? await widget.api.loginWithSms(phone: phone, smsCode: password)
          : await widget.api.registerWithSms(
              phone: phone,
              smsCode: password,
              role: registerRole,
              displayName: registerDisplayName,
            );

      await widget.api.setAuthToken(session.accessToken);
      if (!mounted) {
        return;
      }

      setState(() {
        authenticated = true;
        authenticatedRole = session.role;
        authenticatedUserId = session.userId;
        submitting = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        error = e.toString();
        submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (authenticated) {
      return PlatformShell(
        api: widget.api,
        initialRole: authenticatedRole,
        initialUserId: authenticatedUserId,
        onLogout: _handleLogout,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFDFDFE), Color(0xFFF2F2F7)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -50,
                child: _GlowCircle(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                ),
              ),
              Positioned(
                left: -70,
                bottom: 120,
                child: _GlowCircle(
                  color: const Color(0xFF34C759).withValues(alpha: 0.08),
                ),
              ),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 28,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _BrandMark(),
                          const SizedBox(height: 22),
                          const Text(
                            '三角洲行动陪玩拼单平台',
                            style: TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.9,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            mode == _AuthMode.login
                                ? '使用用户名和密码快速进入，接着管理房间、订单和钱包。'
                                : '创建账户后可直接进入平台，体验完整的房间与资金流程。',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Color(0xFF6B7280),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _GlassPanel(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (mode == _AuthMode.register) ...[
                                    const Text(
                                      '请选择身份',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SegmentedButton<UserRole>(
                                      segments: const [
                                        ButtonSegment<UserRole>(
                                          value: UserRole.boss,
                                          label: Text('找陪玩'),
                                          icon: Icon(Icons.group_rounded),
                                        ),
                                        ButtonSegment<UserRole>(
                                          value: UserRole.companion,
                                          label: Text('陪玩'),
                                          icon: Icon(
                                            Icons.sports_esports_rounded,
                                          ),
                                        ),
                                      ],
                                      selected: <UserRole>{registerRole},
                                      showSelectedIcon: false,
                                      onSelectionChanged: (selection) {
                                        setState(() {
                                          registerRole = selection.first;
                                          error = null;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      '用户名称',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: registerDisplayNameController,
                                      decoration: const InputDecoration(
                                        hintText: '请输入用户名称',
                                        prefixIcon: Icon(Icons.badge_rounded),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  const Text(
                                    '手机号',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: usernameController,
                                    decoration: const InputDecoration(
                                      hintText: '请输入手机号',
                                      prefixIcon: Icon(
                                        Icons.phone_iphone_rounded,
                                      ),
                                    ),
                                    keyboardType: TextInputType.phone,
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '密码',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      hintText: '请输入密码',
                                      prefixIcon: Icon(Icons.lock_rounded),
                                    ),
                                  ),
                                  if (error != null) ...[
                                    const SizedBox(height: 14),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF5F5),
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: const Color(0xFFFFD4D4),
                                        ),
                                      ),
                                      child: Text(
                                        error!,
                                        style: const TextStyle(
                                          color: Color(0xFFC62828),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: submitting ? null : _submit,
                                      child: Text(
                                        submitting
                                            ? '处理中...'
                                            : mode == _AuthMode.login
                                            ? '进入平台'
                                            : '创建账户',
                                      ),
                                    ),
                                  ),
                                  if (mode == _AuthMode.login) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: GestureDetector(
                                        onTap: submitting
                                            ? null
                                            : () => setState(() {
                                                mode = _AuthMode.register;
                                                error = null;
                                              }),
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: '没有账号？',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                              TextSpan(
                                                text: '立即注册',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0071E3),
                                                ),
                                                recognizer:
                                                    TapGestureRecognizer()
                                                      ..onTap = submitting
                                                          ? null
                                                          : () => setState(() {
                                                              mode = _AuthMode
                                                                  .register;
                                                              error = null;
                                                            }),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (mode == _AuthMode.register) ...[
                                    const SizedBox(height: 16),
                                    Center(
                                      child: GestureDetector(
                                        onTap: submitting
                                            ? null
                                            : () => setState(() {
                                                mode = _AuthMode.login;
                                                error = null;
                                              }),
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const TextSpan(
                                                text: '已有账号？',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Color(0xFF6B7280),
                                                ),
                                              ),
                                              TextSpan(
                                                text: '返回登录',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0071E3),
                                                ),
                                                recognizer:
                                                    TapGestureRecognizer()
                                                      ..onTap = submitting
                                                          ? null
                                                          : () => setState(() {
                                                              mode = _AuthMode
                                                                  .login;
                                                              error = null;
                                                            }),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Text(
        'Delta Companion',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF0071E3),
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: const SizedBox.expand(),
      ),
    );
  }
}
