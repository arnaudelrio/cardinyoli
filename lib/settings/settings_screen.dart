import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../l10n/localization_service.dart';
import '../login/user_session.dart';
import '../style/my_button.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';
import 'custom_name_dialog.dart';
import 'settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const _gap = SizedBox(height: 40);
  static const _smallGap = SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final palette = context.watch<Palette>();
    final userSession = context.watch<UserSession>();
    final localizationService = context.watch<LocalizationService>();

    return Scaffold(
      backgroundColor: palette.backgroundSettings,
      body: ResponsiveScreen(
        squarishMainArea: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: ListView(
            children: [
              _gap,
              Text(
                context.settings,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 40,
                  height: 1,
                ),
              ),
              const SizedBox(height: 20),
              // Divider for visual separation
              Divider(
                color: palette.ink.withValues(alpha: 0.2),
                thickness: 2,
                indent: 40,
                endIndent: 40,
              ),
              const SizedBox(height: 20),

              // Audio settings section
              _SectionHeader(context.soundFx.split(' ')[0]), // "Sound" or "Efectes"
              _smallGap,
              ValueListenableBuilder<bool>(
                valueListenable: settings.soundsOn,
                builder: (context, soundsOn, child) => _SettingsLine(
                  context.soundFx,
                  Icon(soundsOn ? Icons.graphic_eq : Icons.volume_off, size: 28),
                  onSelected: () => settings.toggleSoundsOn(),
                ),
              ),
              _smallGap,
              ValueListenableBuilder<bool>(
                valueListenable: settings.musicOn,
                builder: (context, musicOn, child) => _SettingsLine(
                  context.music,
                  Icon(musicOn ? Icons.music_note : Icons.music_off, size: 28),
                  onSelected: () => settings.toggleMusicOn(),
                ),
              ),

              const SizedBox(height: 32),

              // Visual settings section
              _SectionHeader('Visual'),
              _smallGap,
              ValueListenableBuilder<bool>(
                valueListenable: settings.usePokerCards,
                builder: (context, usePokerCards, child) => _SettingsLine(
                  context.usePokerCards,
                  _buildCardDeckIcon(usePokerCards, palette),
                  onSelected: () => settings.togglePokerCards(),
                ),
              ),

              const SizedBox(height: 32),

              // Profile section
              _SectionHeader('Profile'),
              _smallGap,
              _UserNameChangeLine(userSession.username),

              const SizedBox(height: 32),

              // Other settings section
              _SectionHeader(context.language),
              _smallGap,
              _SettingsLine(
                context.language,
                Icon(
                  Icons.language,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onSelected: () => _showLanguageDialog(context),
              ),
              _gap,
            ],
          ),
        ),
        rectangularMenuArea: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: MyButton(
            onPressed: () {
              GoRouter.of(context).pop();
            },
            child: Text(context.back),
          ),
        ),
      ),
    );
  }

  // Build card deck icon showing the four suits
  Widget _buildCardDeckIcon(bool usePokerCards, Palette palette) {
    if (usePokerCards) {
      // French poker cards: ♠ ♣ ♦ ♥
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('♠', style: TextStyle(fontSize: 22, color: palette.ink, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text('♣', style: TextStyle(fontSize: 22, color: palette.ink, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text('♦', style: const TextStyle(fontSize: 22, color: Colors.red, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Text('♥', style: const TextStyle(fontSize: 22, color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      );
    } else {
      // Catalan cards: Castellers, Diables, Sardanes, Bastoners
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/icons/castellers.jpg', width: 24, height: 24, fit: BoxFit.contain),
          const SizedBox(width: 3),
          Image.asset('assets/icons/diables.jpg', width: 24, height: 24, fit: BoxFit.contain),
          const SizedBox(width: 3),
          Image.asset('assets/icons/sardanes.jpg', width: 24, height: 24, fit: BoxFit.contain),
          const SizedBox(width: 3),
          Image.asset('assets/icons/bastoners.jpg', width: 24, height: 24, fit: BoxFit.contain),
        ],
      );
    }
  }

  void _showLanguageDialog(BuildContext context) {
    final palette = context.read<Palette>();
    final localizationService = context.read<LocalizationService>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.language,
            style: TextStyle(color: palette.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.selectPreferredLanguage,
                style: TextStyle(color: palette.ink),
              ),
              const SizedBox(height: 16),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await localizationService.setLanguage('ca');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  localizationService.isCatalan ? Colors.blue.withValues(alpha: 0.2) : null,
                ),
              ),
              child: Text(
                context.catalan,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: localizationService.isCatalan ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                await localizationService.setLanguage('en');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(
                  localizationService.isEnglish ? Colors.blue.withValues(alpha: 0.2) : null,
                ),
              ),
              child: Text(
                context.english,
                style: TextStyle(
                  color: palette.ink,
                  fontWeight: localizationService.isEnglish ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _NameChangeLine extends StatelessWidget {
  final String title;

  const _NameChangeLine(this.title);

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    return InkResponse(
      highlightShape: BoxShape.rectangle,
      onTap: () => showCustomNameDialog(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title,
                style: const TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 30,
                )),
            const Spacer(),
            ValueListenableBuilder(
              valueListenable: settings.playerName,
              builder: (context, name, child) => Text(
                '‘$name’',
                style: const TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 30,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Section header widget for organizing settings
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: palette.ink.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SettingsLine extends StatelessWidget {
  final String title;
  final Widget icon;
  final VoidCallback? onSelected;

  const _SettingsLine(this.title, this.icon, {this.onSelected});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: onSelected,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.ink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: palette.ink.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Permanent Marker',
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              icon,
            ],
          ),
        ),
      ),
    );
  }
}

class _UserNameChangeLine extends StatelessWidget {
  final String currentUsername;

  const _UserNameChangeLine(this.currentUsername);

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: InkWell(
        onTap: () => _showUsernameChangeDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: palette.ink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: palette.ink.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.changeUsername,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Permanent Marker',
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                currentUsername,
                style: TextStyle(
                  fontFamily: 'Permanent Marker',
                  fontSize: 15,
                  color: palette.ink.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  void _showUsernameChangeDialog(BuildContext context) {
    final palette = context.read<Palette>();
    final userSession = context.read<UserSession>();
    final controller = TextEditingController(text: currentUsername);

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.changeUsernameTitle,
            style: TextStyle(color: palette.ink),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.enterNewUsername,
                style: TextStyle(color: palette.ink),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: context.username,
                  hintText: context.usernamePlaceholder,
                  border: const OutlineInputBorder(),
                  labelStyle: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
                ),
                style: TextStyle(color: palette.ink),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Text(
                context.usernameNote,
                style: TextStyle(
                  fontSize: 12,
                  color: palette.ink.withValues(alpha: 0.6),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                context.cancel,
                style: TextStyle(color: palette.ink.withValues(alpha: 0.7)),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newUsername = controller.text.trim();
                if (newUsername.isEmpty || newUsername == currentUsername) {
                  Navigator.of(dialogContext).pop();
                  return;
                }

                try {
                  Navigator.of(dialogContext).pop();

                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      backgroundColor: palette.backgroundMain,
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            context.updatingUsername,
                            style: TextStyle(color: palette.ink),
                          ),
                        ],
                      ),
                    ),
                  );

                  await userSession.changeUsername(newUsername);

                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${context.usernameUpdated} "$newUsername"'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    Navigator.of(context).pop(); // Close loading dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${context.usernameUpdateFailed} $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(
                context.update,
                style: TextStyle(color: palette.ink),
              ),
            ),
          ],
        );
      },
    );
  }
}
