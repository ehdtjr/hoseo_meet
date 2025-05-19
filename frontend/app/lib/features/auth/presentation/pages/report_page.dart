import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/user_profile_provider.dart';

class ReportPage extends ConsumerStatefulWidget {
  final int reportedUserId;
  final String reportedUserName;
  final String? reportedUserProfile;

  const ReportPage({
    super.key,
    required this.reportedUserId,
    required this.reportedUserName,
    this.reportedUserProfile,
  });

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    bool success = false;

    try {
      await ref.read(userProfileNotifierProvider.notifier).reportUser(
        reportedUserId: widget.reportedUserId,
        reason: _reasonController.text.trim(),
      );
      success = true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);

      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수되었습니다. 감사합니다.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final errorMessage = ref.watch(userProfileNotifierProvider).errorMessage;
    final hasProfile = widget.reportedUserProfile != null &&
        widget.reportedUserProfile!.isNotEmpty &&
        Uri.tryParse(widget.reportedUserProfile!)?.hasAbsolutePath == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('신고하기'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0.5,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundImage:
                    hasProfile ? NetworkImage(widget.reportedUserProfile!) : null,
                    backgroundColor: Colors.grey.shade300,
                    child: hasProfile
                        ? null
                        : const Icon(Icons.person, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.reportedUserName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '신고 사유를 작성해주세요.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _reasonController,
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: '신고 내용을 입력하세요',
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '신고 사유를 입력해주세요';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              if (errorMessage != null && errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE72410),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    '신고하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
