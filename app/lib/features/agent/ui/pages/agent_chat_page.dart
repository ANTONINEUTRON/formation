import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:symbians/core/route/app_route.dart';
import 'package:symbians/core/theme/theme.dart';
import 'package:symbians/core/widgets/rounded_text_field.dart';
import 'package:symbians/domain/entity/chat_message.dart';
import 'package:symbians/features/agent/ui/widgets/action_icon_button.dart';
import 'package:symbians/features/agent/ui/widgets/attachment_preview.dart';
import 'package:symbians/features/agent/ui/widgets/message_bubble.dart';
import 'package:symbians/features/credits/ui/cubits/credits_cubit.dart';
import 'package:symbians/features/credits/ui/cubits/credits_state.dart';
import 'package:symbians/features/credits/ui/widgets/buy_credits_modal.dart';
import 'package:symbians/gen/assets.gen.dart';

/// Agent chat page - conversational interface with the agent.
@RoutePage()
class AgentChatPage extends StatefulWidget {
  const AgentChatPage({
    super.key,
    required this.agentId,
    required this.agentName,
  });

  final String agentId;
  final String agentName;

  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  bool _isRecording = false;
  List<PlatformFile> _attachments = [];

  // Mock messages for demo
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello! I\'m your trading agent. How can I help you today?',
      isUser: false,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
  ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty && _attachments.isEmpty) return;

    // Paywall guard — show purchase modal if out of credits.
    final creditsCubit = context.read<CreditsCubit>();
    if (!creditsCubit.state.canSend) {
      final purchased = await BuyCreditsModal.show(context);
      if (purchased != true) return; // user dismissed without buying
    }
    creditsCubit.deductCredit();

    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
        attachments: List.from(_attachments),
      ));
      _textController.clear();
      _attachments.clear();
    });

    // Scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Mock agent response
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Got it! I\'ll work on that for you. Is there anything else you\'d like me to consider?',
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
    });
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null) {
      setState(() {
        _attachments.addAll(result.files);
      });
    }
  }

  void _toggleVoiceRecording() {
    setState(() {
      _isRecording = !_isRecording;
    });

    if (!_isRecording) {
      // TODO: Process recorded audio
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Voice recording stopped. Processing...'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.agentName),
        centerTitle: false,
        actions: [
          // Credits balance chip
          BlocBuilder<CreditsCubit, CreditsState>(
            builder: (context, credits) => GestureDetector(
              onTap: () => BuyCreditsModal.show(context),
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: credits.canSend
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : AppColors.error.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: credits.canSend
                        ? AppColors.primary.withValues(alpha: 0.4)
                        : AppColors.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14,
                      color: credits.canSend
                          ? AppColors.primary
                          : AppColors.error,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${credits.balance}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: credits.canSend
                            ? AppColors.primary
                            : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.router.push(
              AgentConfigRoute(
                agentId: widget.agentId,
                agentName: widget.agentName,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return MessageBubble(message: message);
              },
            ),
          ),

          // Attachments preview
          if (_attachments.isNotEmpty)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _attachments.length,
                itemBuilder: (context, index) {
                  final file = _attachments[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: AttachmentPreview(
                      file: file,
                      onRemove: () => _removeAttachment(index),
                    ),
                  );
                },
              ),
            ),

          // Input area
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Text field
                  RoundedTextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    hintText: 'Ask Anything',
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (_) => _sendMessage(),
                  ),

                  const SizedBox(height: 12),

                  // Action buttons row
                  Row(
                    children: [
                      // Attachment button
                      ActionIconButton(
                        icon: Icons.attach_file,
                        onTap: _pickFiles,
                      ),

                      const SizedBox(width: 8),


                      const Spacer(),

                      // Voice button
                      GestureDetector(
                        onLongPressStart: (_) => _toggleVoiceRecording(),
                        onLongPressEnd: (_) => _toggleVoiceRecording(),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isRecording
                                ? AppColors.error
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _isRecording ? Icons.mic : Icons.mic_none_outlined,
                            color: _isRecording
                                ? AppColors.textPrimary
                                : AppColors.textMuted,
                            size: 22,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Send button
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.send,
                            color: AppColors.textInverse,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
