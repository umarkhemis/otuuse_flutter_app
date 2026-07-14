import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _phoneNumber;
  String _role = 'passenger';
  bool _isLoading = false;
  String? _errorMessage;

  bool get _isDriver => _role == 'driver';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneNumber == null) {
      setState(() => _errorMessage = 'Enter your phone number.');
      return;
    }
    if (!_isDriver) {
      final formValid = _formKey.currentState?.validate() ?? false;
      if (!formValid) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).requestOtp(
            phoneNumber: _phoneNumber!,
            name: _isDriver ? 'Driver' : _nameController.text.trim(),
            role: _role,
          );
      if (!mounted) return;
      context.push('/verify-otp', extra: _phoneNumber);
    } catch (e) {
      final msg = e.toString();
      setState(() {
        if (msg.contains('invite') || msg.contains('403') || msg.contains('admin')) {
          _errorMessage =
              'This number is not registered as a driver. '
              'Contact your Otuuse administrator to be added.';
        } else {
          _errorMessage = msg;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Otuuse Transport',
                      style: TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isDriver
                          ? 'Driver login'
                          : 'Get a boda boda or send a delivery, just by chatting.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // Role selector
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'passenger', label: Text('Passenger')),
                        ButtonSegment(
                            value: 'driver', label: Text('Driver')),
                      ],
                      selected: {_role},
                      onSelectionChanged: (selection) => setState(() {
                        _role = selection.first;
                        _errorMessage = null;
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Name field - only for passengers
                    if (!_isDriver) ...[
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Your name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                                ? 'Enter your name'
                                : null,
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Driver info banner
                    if (_isDriver) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 18,
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Driver accounts are registered by your '
                                'Otuuse administrator. Enter your '
                                'registered phone number to continue.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Phone field
                    IntlPhoneField(
                      initialCountryCode: 'UG',
                      decoration: const InputDecoration(
                        labelText: 'Phone number',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (phone) =>
                          _phoneNumber = phone.completeNumber,
                    ),
                    const SizedBox(height: 24),

                    if (_errorMessage != null) ...[
                      Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                    ],

                    FilledButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2),
                            )
                          : const Text('Continue'),
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
}
