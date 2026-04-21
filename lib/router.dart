import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'game_internals/score.dart';
import 'lobby/lobby_screen.dart';
import 'login/login_screen.dart';
import 'login/user_session.dart';
import 'main_menu/main_menu_screen.dart';
import 'play_session/multiplayer_play_session_screen.dart';
import 'rules/rules_screen.dart';
import 'settings/settings_screen.dart';
import 'style/my_transition.dart';
import 'style/palette.dart';
import 'win_game/win_game_screen.dart';
import 'win_game/lose_game_screen.dart';
import 'win_game/tie_game_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final userSession = context.read<UserSession>();
    final isLoggedIn = userSession.isLoggedIn;
    final currentLocation = state.matchedLocation;

    // If not logged in and trying to access protected routes, redirect to login
    if (!isLoggedIn && (currentLocation == '/lobby' || currentLocation == '/play')) {
      return '/login';
    }

    // If logged in and on login page, redirect to main menu
    if (isLoggedIn && currentLocation == '/login') {
      return '/';
    }

    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(key: Key('login')),
    ),
    GoRoute(
      path: '/lobby',
      builder: (context, state) => const LobbyScreen(key: Key('lobby')),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const MainMenuScreen(key: Key('main menu')),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(key: Key('settings')),
        ),
        GoRoute(
          path: 'rules',
          builder: (context, state) => const RulesScreen(key: Key('rules')),
        ),
      ],
    ),
    GoRoute(
      path: '/play',
      pageBuilder: (context, state) => buildMyTransition<void>(
        key: const ValueKey('play'),
        color: context.watch<Palette>().backgroundPlaySession,
        child: const MultiplayerPlaySessionScreen(
          key: Key('multiplayer play session'),
        ),
      ),
      routes: [
        GoRoute(
          path: 'win',
          redirect: (context, state) {
            if (state.extra == null) {
              return '/';
            }
            return null;
          },
          pageBuilder: (context, state) {
            final map = state.extra! as Map<String, dynamic>;
            final score = map['score'] as int;
            final winnerName1 = map['winnerName1'] as String;
            final winnerName2 = map['winnerName2'] as String;
            final cumulatedScore = map['cumulatedScore'] as Score;

            return buildMyTransition<void>(
              key: const ValueKey('win'),
              color: context.watch<Palette>().backgroundPlaySession,
              child: WinGameScreen(
                key: const Key('win game'),
                score: score,
                winnerName1: winnerName1,
                winnerName2: winnerName2,
                cumulatedScore: cumulatedScore,
              ),
            );
          },
        ),
        GoRoute(
          path: 'lost',
          redirect: (context, state) {
            if (state.extra == null) {
              return '/';
            }

            // Otherwise, do not redirect.
            return null;
          },
          pageBuilder: (context, state) {
            final map = state.extra! as Map<String, dynamic>;
            final score = map['score'] as int;
            final winnerName1 = map['winnerName1'] as String;
            final winnerName2 = map['winnerName2'] as String;
            final cumulatedScore = map['cumulatedScore'] as Score;

            return buildMyTransition<void>(
              key: const ValueKey('lost'),
              color: context.watch<Palette>().backgroundPlaySession,
              child: LoseGameScreen(
                score: score,
                winnerName1: winnerName1,
                winnerName2: winnerName2,
                cumulatedScore: cumulatedScore,
                key: const Key('lost game'),
              ),
            );
          },
        ),
        GoRoute(
          path: 'tie',
          redirect: (context, state) {
            if (state.extra == null) {
              return '/';
            }
            return null;
          },
          pageBuilder: (context, state) {
            final map = state.extra! as Map<String, dynamic>;
            final cumulatedScore = map['cumulatedScore'] as Score;

            return buildMyTransition<void>(
              key: const ValueKey('tie'),
              color: context.watch<Palette>().backgroundPlaySession,
              child: TieGameScreen(
                key: const Key('tie game'),
                cumulatedScore: cumulatedScore,
              ),
            );
          },
        ),
      ],
    ),
  ],
);
