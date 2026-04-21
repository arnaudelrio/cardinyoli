import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../login/user_session.dart';
import '../style/palette.dart';

/// A top bar widget that shows user info and action buttons when logged in.
/// Displays settings and logout buttons in the top right corner.
class UserTopBar extends StatelessWidget implements PreferredSizeWidget {
  const UserTopBar({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final userSession = context.watch<UserSession>();
    final palette = context.watch<Palette>();

    if (!userSession.isLoggedIn) {
      return const SizedBox.shrink();
    }

    return Container(
      height: kToolbarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: palette.backgroundMain.withValues(alpha: 0.9),
        boxShadow: [
          BoxShadow(
            color: palette.ink.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - user info
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: palette.ink.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    userSession.username,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Right side - action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rules button
              IconButton(
                onPressed: () {
                  GoRouter.of(context).push('/rules');
                },
                icon: Icon(
                  Icons.book,
                  color: palette.ink.withValues(alpha: 0.8),
                ),
                tooltip: context.gameRulesToolip,
              ),
              // Settings button
              IconButton(
                onPressed: () {
                  GoRouter.of(context).push('/settings');
                },
                icon: Icon(
                  Icons.settings,
                  color: palette.ink.withValues(alpha: 0.8),
                ),
                tooltip: context.settingsTooltip,
              ),
              // Logout button
              IconButton(
                onPressed: () => _showLogoutDialog(context),
                icon: Icon(
                  Icons.logout,
                  color: palette.ink.withValues(alpha: 0.8),
                ),
                tooltip: context.logoutTooltip,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final palette = context.read<Palette>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.logoutFromDevice,
            style: TextStyle(color: palette.ink),
          ),
          content: Text(
            context.logoutDescription,
            style: TextStyle(color: palette.ink),
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
                Navigator.of(dialogContext).pop();
                final userSession = context.read<UserSession>();
                await userSession.logout();
                if (context.mounted) {
                  GoRouter.of(context).go('/login');
                }
              },
              child: Text(
                context.logout,
                style: TextStyle(color: palette.ink),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A simplified version of the top bar for use in body content (not as AppBar)
class UserTopBarInline extends StatelessWidget {
  const UserTopBarInline({super.key});

  @override
  Widget build(BuildContext context) {
    final userSession = context.watch<UserSession>();
    final palette = context.watch<Palette>();

    if (!userSession.isLoggedIn) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side - user info
          Expanded(
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: palette.ink.withValues(alpha: 0.7),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    userSession.username,
                    style: TextStyle(
                      color: palette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // Right side - action buttons
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rules button
              IconButton(
                onPressed: () {
                  GoRouter.of(context).push('/rules');
                },
                icon: Icon(
                  Icons.book,
                  color: palette.ink.withValues(alpha: 0.8),
                ),
                tooltip: 'Game Rules',
              ),
              // Settings button
              IconButton(
                onPressed: () {
                  GoRouter.of(context).push('/settings');
                },
                icon: Icon(
                  Icons.settings,
                  color: palette.ink.withValues(alpha: 0.8),
                ),
                tooltip: 'Settings',
              ),
              // Logout button
              IconButton(
                onPressed: () => _showLogoutDialog(context),
                icon: Icon(
                  Icons.logout,
                  color: palette.ink.withValues(alpha: 0.8),
                ),
                tooltip: 'Logout from Device',
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final palette = context.read<Palette>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: palette.backgroundMain,
          title: Text(
            context.logoutFromDevice,
            style: TextStyle(color: palette.ink),
          ),
          content: Text(
            context.logoutDescription,
            style: TextStyle(color: palette.ink),
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
                Navigator.of(dialogContext).pop();
                final userSession = context.read<UserSession>();
                if (context.mounted) {
                  GoRouter.of(context).go('/login');
                await userSession.logout();
                }
              },
              child: Text(
                context.logout,
                style: TextStyle(color: palette.ink),
              ),
            ),
          ],
        );
      },
    );
  }
}
