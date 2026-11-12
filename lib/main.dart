import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

void main() => runApp(const ChatLabApp());

enum ChatErrorType { unauthorized401, rateLimit429, server500, timeout }

extension ChatErrorTypeX on ChatErrorType {
  String get label {
    switch (this) {
      case ChatErrorType.unauthorized401:
        return '401 Unauthorized';
      case ChatErrorType.rateLimit429:
        return '429 Too Many Requests';
      case ChatErrorType.server500:
        return '500 Server Error';
      case ChatErrorType.timeout:
        return 'Timeout';
    }
  }

  String get message {
    switch (this) {
      case ChatErrorType.unauthorized401:
        return '인증에 실패했어요. 다시 시도해 주세요.';
      case ChatErrorType.rateLimit429:
        return '요청이 많아요. 잠시 후 다시 시도해 주세요.';
      case ChatErrorType.server500:
        return '서버에 문제가 발생했어요. 다시 시도해 주세요.';
      case ChatErrorType.timeout:
        return '응답 시간이 초과되었어요. 다시 시도해 주세요.';
    }
  }
}

class ChatLabApp extends StatelessWidget {
  const ChatLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Chat — 실습 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F6FE4),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF2B2B2B),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2B2B2B),
          foregroundColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const ChatPage(),
    );
  }
}

/// 대화 한 줄. 서버 없이 화면만 만들기 위한 최소 모델.
class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _controller = TextEditingController();
  bool _isThinking = false;
  ChatErrorType? _errorType;
  String? _pendingText;
  int _requestCount = 0;
  int _rateLimitRetryStage = 0;
  final Random _random = Random();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _errorType = null;
      _pendingText = null;
      _rateLimitRetryStage = 0;
      _messages.add(ChatMessage(text: text, isUser: true));
    });
    _controller.clear();
    await _requestAiResponse(text);
  }

  Future<void> _retryLastMessage() async {
    final text = _pendingText;
    if (text == null || _isThinking) return;
    await _requestAiResponse(text, isRetry: true);
  }

  Future<void> _requestAiResponse(String text, {bool isRetry = false}) async {
    var delay = const Duration(milliseconds: 900);
    if (isRetry && _errorType == ChatErrorType.rateLimit429) {
      delay = Duration(seconds: _rateLimitRetryStage == 0 ? 1 : 2);
    }

    setState(() {
      _errorType = null;
      _isThinking = true;
    });

    await Future<void>.delayed(delay);
    if (!mounted) return;

    final outcome = _simulateOutcome();
    setState(() {
      _isThinking = false;
      if (outcome == null) {
        _pendingText = null;
        _rateLimitRetryStage = 0;
        _messages.add(
          ChatMessage(text: '"$text"에 대해 더 자세히 알려주세요.', isUser: false),
        );
      } else {
        _errorType = outcome;
        _pendingText = text;
        if (outcome == ChatErrorType.rateLimit429) {
          _rateLimitRetryStage = (_rateLimitRetryStage + 1).clamp(0, 1);
        } else {
          _rateLimitRetryStage = 0;
        }
      }
    });
  }

  ChatErrorType? _simulateOutcome() {
    _requestCount++;
    // Demonstrate all required error states, then succeed.
    const sequence = <ChatErrorType?>[
      ChatErrorType.unauthorized401,
      ChatErrorType.rateLimit429,
      ChatErrorType.rateLimit429,
      ChatErrorType.server500,
      ChatErrorType.timeout,
      null,
    ];
    return sequence[(_requestCount - 1) % sequence.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('AI 김준한')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      '오늘 무엇을 도와드릴까요?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount:
                          _messages.length +
                          ((_isThinking || _errorType != null) ? 1 : 0),
                      itemBuilder: (context, index) {
                        final hasStatus = _isThinking || _errorType != null;
                        if (hasStatus && index == 0) {
                          return AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _isThinking
                                ? const _ThinkingBubble(
                                    key: ValueKey('thinking'),
                                  )
                                : _ErrorBubble(
                                    key: ValueKey(_errorType),
                                    errorType: _errorType!,
                                    onRetry: _retryLastMessage,
                                  ),
                          );
                        }
                        final offset = hasStatus ? 1 : 0;
                        final messageIndex =
                            _messages.length - 1 - (index - offset);
                        final message = _messages[messageIndex];
                        return _Bubble(message: message);
                      },
                    ),
                  ),
                ],
              ),
            ),
            _InputBar(controller: _controller, onSend: _sendMessage),
          ],
        ),
      ),
    );
  }
}

/// 사용자 메시지는 오른쪽, AI 메시지는 왼쪽에 표시하는 말풍선.
class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: isUser ? Colors.lightGreen : Colors.lightBlueAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.black87),
        ),
      ),
    );
  }
}

/// AI가 응답을 준비 중일 때 표시하는 애니메이션 말풍선.
class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble({super.key});

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: Colors.lightBlueAccent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List<Widget>.generate(3, (index) {
                final t = (_controller.value + index * 0.2) % 1.0;
                final scale = 0.6 + 0.4 * (1 - (2 * t - 1).abs());
                final opacity = 0.3 + 0.7 * (1 - (2 * t - 1).abs());
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Opacity(
                    opacity: opacity.clamp(0.3, 1.0),
                    child: Transform.scale(
                      scale: scale,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.black87,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

/// 오류 상태를 보여 주고 다시 시도를 제공하는 말풍선.
class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({
    super.key,
    required this.errorType,
    required this.onRetry,
  });

  final ChatErrorType errorType;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: const Color(0xFF5A2A2A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.redAccent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              errorType.label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorType.message,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('다시 시도'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 입력창과 전송 버튼.
class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(
                hintText: '메시지를 입력하세요',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: const Icon(Icons.send),
            tooltip: '전송',
          ),
        ],
      ),
    );
  }
}
