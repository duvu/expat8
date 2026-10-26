import 'package:flutter/material.dart';

// Register / sign-in dialog and the auth progress bar.
class IdentityCredentials {
  const IdentityCredentials({
    required this.identifier,
    required this.password,
    this.displayName,
  });

  final String identifier;
  final String password;
  final String? displayName;
}

Future<IdentityCredentials?> showIdentityDialog({
  required BuildContext context,
  required String title,
  bool includeDisplayName = false,
}) {
  return showDialog<IdentityCredentials>(
    context: context,
    builder: (context) {
      return IdentityDialog(
        title: title,
        includeDisplayName: includeDisplayName,
        onSubmit: (credentials) => Navigator.of(context).pop(credentials),
      );
    },
  );
}

class IdentityDialog extends StatefulWidget {
  const IdentityDialog({
    required this.title,
    required this.onSubmit,
    this.includeDisplayName = false,
    super.key,
  });

  final String title;
  final bool includeDisplayName;
  final ValueChanged<IdentityCredentials> onSubmit;

  @override
  State<IdentityDialog> createState() => _IdentityDialogState();
}

class _IdentityDialogState extends State<IdentityDialog> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();
  String? _identifierError;
  String? _passwordError;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _identifierController,
            decoration: InputDecoration(
              labelText: 'Email',
              errorText: _identifierError,
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.username],
          ),
          if (widget.includeDisplayName)
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofillHints: const [AutofillHints.name],
            ),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(
              labelText: 'Password',
              errorText: _passwordError,
            ),
            obscureText: true,
            autofillHints: const [AutofillHints.password],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.title),
        ),
      ],
    );
  }

  void _submit() {
    final identifier = _identifierController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final identifierError = _validateIdentifier(identifier);
    final passwordError =
        password.length < 8 ? 'Password must be at least 8 characters.' : null;

    setState(() {
      _identifierError = identifierError;
      _passwordError = passwordError;
    });

    if (identifierError != null || passwordError != null) {
      return;
    }

    final displayName = _displayNameController.text.trim();
    widget.onSubmit(
      IdentityCredentials(
        identifier: identifier,
        password: password,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    );
  }

  String? _validateIdentifier(String identifier) {
    if (identifier.isEmpty) {
      return 'Enter an email address.';
    }
    final emailLikePattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailLikePattern.hasMatch(identifier)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}

class AuthProgressIndicator extends StatelessWidget {
  const AuthProgressIndicator({required this.isVisible, super.key});

  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }
    return const LinearProgressIndicator(minHeight: 4);
  }
}
