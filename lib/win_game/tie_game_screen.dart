import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../game_internals/score.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localization_service.dart';
import '../login/user_session.dart';
import '../style/my_button.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';

class TieGameScreen extends StatefulWidget {
  final Score cumulatedScore;

  const TieGameScreen({
    super.key,
    required this.cumulatedScore,
  });

  @override
  State<TieGameScreen> createState() => _TieGameScreenState();
}

class _TieGameScreenState extends State<TieGameScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 600),
    vsync: this,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeIn,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continueGame() async {
    final userSession = context.read<UserSession>();
    await userSession.gameRoomController?.restartRound();
    if (mounted) {
      GoRouter.of(context).go('/play');
    }
  }

  Future<void> _leaveGame() async {
    final palette = context.read<Palette>();

    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.leaveGameTitle,
            style: TextStyle(color: palette.ink),
          ),
          content: Text(
            context.leaveGameConfirmAll,
            style: TextStyle(color: palette.ink),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                context.cancel,
                style: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                context.leave,
                style: TextStyle(color: palette.ink),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLeave == true && mounted) {
      final userSession = context.read<UserSession>();
      await userSession.leaveGame();
      if (mounted) {
        GoRouter.of(context).go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    context.watch<LocalizationService>();

    return Scaffold(
      backgroundColor: palette.backgroundMain,
      body: FadeTransition(
        opacity: _fade,
        child: ResponsiveScreen(
          squarishMainArea: Center(
            child: _buildContent(context, palette),
          ),
          rectangularMenuArea: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MyButton(
                  onPressed: _continueGame,
                  child: Text(context.continueButton),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _leaveGame,
                  child: Text(
                    context.leaveGame,
                    style: TextStyle(
                      color: palette.ink.withValues(alpha: 0.6),
                      fontFamily: 'Permanent Marker',
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Palette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('👊', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),

          Text(
            context.tie,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Permanent Marker',
              fontSize: 42,
              color: palette.inkFullOpacity,
            ),
          ),
          const SizedBox(height: 24),

          Divider(color: palette.ink.withValues(alpha: 0.15), thickness: 1),
          const SizedBox(height: 20),

          Text(
            context.scores.replaceAll(':', '').toUpperCase(),
            style: TextStyle(
              fontFamily: 'Permanent Marker',
              fontSize: 12,
              color: palette.ink.withValues(alpha: 0.45),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${widget.cumulatedScore.team1Score}',
                style: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 28,
                  color: palette.inkFullOpacity,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '—',
                  style: TextStyle(
                    fontFamily: 'Permanent Marker',
                    fontSize: 20,
                    color: palette.ink.withValues(alpha: 0.3),
                  ),
                ),
              ),
              Text(
                '${widget.cumulatedScore.team2Score}',
                style: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 28,
                  color: palette.inkFullOpacity,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
