import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../l10n/app_localizations.dart';
import '../l10n/localization_service.dart';
import '../login/user_session.dart';
import '../settings/settings.dart';
import '../style/my_button.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';
import '../style/user_top_bar.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    final settingsController = context.watch<SettingsController>();
    final audioController = context.watch<AudioController>();
    final userSession = context.watch<UserSession>();
    // Watch LocalizationService to rebuild when language changes
    context.watch<LocalizationService>();

    return Scaffold(
      backgroundColor: palette.backgroundMain,
      body: Column(
        children: [
          // Top bar with user actions when logged in
          if (userSession.isLoggedIn) const UserTopBarInline(),
          // Main content
          Expanded(
            child: ResponsiveScreen(
              squarishMainArea: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(
                    child: Transform.rotate(
                      angle: -0.1,
                      child: const Text(
                        'Cardinyoli',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Permanent Marker',
                          fontSize: 55,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  _gap,
                  Center(
                    child: Text(
                      context.gameSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'Permanent Marker',
                        fontSize: 40,
                        height: 2,
                      ),
                    ),
                  ),
                ],
              ),
              rectangularMenuArea: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (userSession.isLoggedIn) ...[
                    MyButton(
                      onPressed: () {
                        audioController.playSfx(SfxType.buttonTap);
                        GoRouter.of(context).go('/lobby');
                      },
                      child: Text(context.joinGame),
                    ),
                  ] else ...[
                    MyButton(
                      onPressed: () {
                        audioController.playSfx(SfxType.buttonTap);
                        GoRouter.of(context).go('/login');
                      },
                      child: Text(context.loginToPlay),
                    ),
                  ],
                  _gap,
                  MyButton(
                    onPressed: () => GoRouter.of(context).push('/rules'),
                    child: Text(context.gameRules),
                  ),
                  _gap,
                  MyButton(
                    onPressed: () => GoRouter.of(context).push('/settings'),
                    child: Text(context.settings),
                  ),
                  _gap,
                  if (kDebugMode) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            '🐛 DEBUG MODE ACTIVE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Games can start with fewer than 4 players.\nUse the "Force Start Game" button in lobby.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    _gap,
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: settingsController.audioOn,
                      builder: (context, audioOn, child) {
                        return IconButton(
                          onPressed: () => settingsController.toggleAudioOn(),
                          icon: Icon(audioOn ? Icons.volume_up : Icons.volume_off),
                        );
                      },
                    ),
                  ),
                  _gap,
                  Text(context.createdBy),
                  _gap,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _gap = SizedBox(height: 10);
}
