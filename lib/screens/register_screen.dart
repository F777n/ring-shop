import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/api_exceptions.dart';
import '../forms/validators.dart';
import '../state/auth_notifier.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  String _passwordNow = '';
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _username.dispose();
    _name.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_form.currentState?.validate() != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthNotifier>().register(
            username: _username.text,
            password: _password.text,
            fullName: _name.text,
          );
    } on ValidationException catch (error) {
      if (mounted) {
        setState(() => _error = error.errors.values.join('\n').ifEmpty(error.message));
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Не удалось зарегистрироваться.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rules = PasswordRules.of(_passwordNow);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Регистрация', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    const Text('Новая учётка получает роль покупателя.'),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Имя'),
                      validator: (value) =>
                          value == null || value.trim().length < 2 ? 'Укажите имя' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _username,
                      decoration: const InputDecoration(labelText: 'Логин'),
                      validator: (value) =>
                          value == null || value.trim().length < 3 ? 'Логин от 3 символов' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                      onChanged: (value) => setState(() => _passwordNow = value),
                      validator: passwordText,
                    ),
                    const SizedBox(height: 8),
                    _rule('Не короче 8 символов', rules.length),
                    _rule('Есть цифра', rules.digit),
                    _rule('Есть специальный символ', rules.special),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _repeat,
                      decoration: const InputDecoration(labelText: 'Пароль ещё раз'),
                      obscureText: true,
                      validator: (value) => value == _password.text ? null : 'Пароли не совпадают',
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? 'Создаём...' : 'Зарегистрироваться'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      child: const Text('Уже есть логин'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _rule(String text, bool ok) {
    final color = _passwordNow.isEmpty
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : ok
            ? Colors.green.shade700
            : Theme.of(context).colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text('• $text', style: TextStyle(color: color)),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
