import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../style/palette.dart';
import '../settings/settings.dart';

/// A screen that displays the complete rules of the Borifarra card game.
/// Rules are displayed in Catalan as the game is a traditional Catalan card game.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  static const _gap = SizedBox(height: 12);
  static const _sectionGap = SizedBox(height: 20);
  static const _contentPadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0);

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();
    final isMobile = MediaQuery.of(context).size.width < 600;
    final poker = context.watch<SettingsController>().pokerCards;

    return Scaffold(
      backgroundColor: palette.backgroundSettings,
      appBar: AppBar(
        backgroundColor: palette.backgroundSettings,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: Text(
          '📖 Normes de la Botifarra',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Permanent Marker',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: EdgeInsets.all(isMobile ? 12 : 24),
        children: [
          _buildSection(
            palette: palette,
            icon: '👥',
            title: '1. Jugadors',
            backgroundColor: Color(0xFFE3F2FD),
            accentColor: palette.pen,
            content: [
              "La Borifarra es juga amb 4 jugadors dividits en 2 equips.",
              "Els jugadors de cada equip es van alternant per jugar.",
              "Cadascun dels jugadors rep 12 cartes al començar el joc.",
              "A cada basa, cada jugador ha de jugar una carta.",
              "Les rondes estaran formades per 12 bases, és a dir, fins que s'acabin les cartes.",
              "És important que no es poden donar senyals o pistes al jugador del teu equip durant el joc."
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '🃏',
            title: '2. Cartes',
            backgroundColor: Color(0xFFF3E5F5),
            accentColor: palette.redPen,
            content: [
            if (poker) ...[
                "Es juga amb una baralla de 48 cartes, eliminant els 10.",
                "Els valors de les cartes per ordre de força són:",
                "Nou • As • Rei • Reina • Cavall • 8 • 7 • 6 • 5 • 4 • 3 • 2",
              ] else ...[
                "Es juga amb una baralla típica de 48 cartes.",
                "Els valors de les cartes per ordre de força són:",
                "Nou • As • Rei • Cavall • Sota • 8 • 7 • 6 • 5 • 4 • 3 • 2",
              ],
              "El nou s'acostuma a anomenar 'Manilla'.",
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '👑',
            title: '3. Escollir triomf',
            backgroundColor: Color(0xFFECEFF1),
            accentColor: Color(0xFF455A64),
            content: [
              if (poker) ...[
                "Al començar el joc, el jugador amb el 5 de piques pot escollir el triomf.",
              ] else ...[
                "Al començar el joc, el jugador amb el 5 de bastons pot escollir el triomf.",
              ],
              "A cada ronda, el següent jugador podrà triar el triomf.",
              "A més a més de poder triar un pal entre els quatre de la baralla, el jugador pot decidir delegar la elecció al seu company (que no podrà tornar a delegar).",
              "Finalment, també es pot cantar 'Botifarra' per triar el triomf, que aleshores no hi haurà cap pal que predominarà, i els punts finals valdran el doble."
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '💪',
            title: '4. Contro, Recontro i Sant Vicenç',
            backgroundColor: Color(0xFFFFE0B2),
            accentColor: Color(0xFFF57F17),
            content: [
              "Un cop triat el triomf, el jugador següent al què canta (sense comptar delegacions) pot decidir si contrar, i llavors els punts valen el doble. Si el jugador contra, el següent pot recontar, i així successivament, de forma que:",
              "• CONTRO: Doble de punts.",
              "• RECONTRO: Quatre vegades els punts.",
              "• SANT VICENÇ: Es multiplica per 8 els punts.",
              "• BARRACA: Són 16 vegades els punts que es guanyen.",
              "Aquest multiplicador també es té en compte si s'ha cantat botifarra en lloc del triomf, per obtenir el multiplicador màxim possible de 32.",
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '🎪',
            title: '5. Jugar les cartes',
            backgroundColor: Color(0xFFE0F2F1),
            accentColor: Color(0xFF009688),
            content: [
              "El primer jugador (el de la dreta del què ha cantat) comença tirant una carta.",
              "El pal de la primera carta és el pal de sortida, i determina el pal de la basa."
              "La prioritat és seguir el pal de sortida.",
              "Si pots, estas obligat a assegurar que el teu equip guanyi la basa.",
              "Si no pots seguir el pal de sortida, el pal triomf pot guanyar la basa.",
              "Si el teu equip ja va guanyant la basa, no és necessari guanyar-lo, però sí que s'ha de seguir el pal de sortida.",
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '⭐',
            title: '6. Valors de les cartes',
            backgroundColor: Color(0xFFFFF3E0),
            accentColor: Color(0xFFFF9800),
            content: [
              "Nou: 5 PUNTS",
              "As: 4 PUNTS",
              "Rei: 3 PUNTS",
              if (poker) ...[
                "Reina: 2 PUNTS",
                "Cavall: 1 PUNTS",
              ] else ...[
                "Cavall: 2 PUNTS",
                "Sota: 1 PUNTS",
              ],
              "La resta de cartes: 0 PUNTS",
              "A més a més, cada basa (cada quatre cartes) té un punt més per aquell equip.",
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '🏆',
            title: '7. Puntuació',
            backgroundColor: Color(0xFFFFF3E0),
            accentColor: Color(0xFFFF9800),
            content: [
              "Per calcular la puntuació final, el equip amb més punts aplica la fórmula:",
              "Puntuació final = (Punts obtinguts - 36) * Multiplicador",
              "Aquesta puntuació indica els punts que se li sumen al equip guanyador.",
              "L'equip que perd no guanya ni perd punts."
            ],
          ),
          _sectionGap,
          _buildSection(
            palette: palette,
            icon: '🎯',
            title: '8. Objectiu i final de la partida',
            backgroundColor: Color(0xFFE8F5E9),
            accentColor: palette.accept,
            content: [
              "Acumular més punts que l'altre equip fins arribar a 101 punts.",
              "El joc es juga per rondes, i s'acumulen els punts.",
              "A cada ronda només un dels equips suma punts."
              "El primer equip que arriba a 101 punts guanya la partida.",
            ],
          ),
        ],
      ),
    );
  }

  /// Builds a formatted section with icon, title, and content.
  static Widget _buildSection({
    required Palette palette,
    required String icon,
    required String title,
    required Color backgroundColor,
    required Color accentColor,
    required List<String> content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: _contentPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with icon
            Row(
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Permanent Marker',
                    ),
                  ),
                ),
              ],
            ),
            _gap,
            // Divider
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor.withValues(alpha: 0.3), Colors.transparent],
                ),
              ),
            ),
            _gap,
            // Content
            ...content.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        entry.value,
                        style: TextStyle(
                          color: palette.ink,
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
