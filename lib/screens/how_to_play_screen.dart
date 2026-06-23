import 'package:flutter/material.dart';

import '../theme.dart';

class _Entry {
  final String asset;
  final String title;
  final String desc;
  const _Entry({
    this.asset = '',
    required this.title,
    required this.desc,
  });
}

class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  static const _objects = <_Entry>[
    _Entry(
      asset: 'assets/magma_fireball_projectile.webp',
      title: 'Magma Charge',
      desc:
          'Your weapon. Tap any tile to launch a charge and trigger a blast '
          'in the surrounding area. You only get a limited number per level — '
          'spend them wisely.',
    ),
    _Entry(
      asset: 'assets/magma_crystal.webp',
      title: 'Magma Crystal',
      desc:
          'The main target. When hit, it explodes and ignites the 8 tiles '
          'around it, setting off a chain reaction. Destroy every crystal to '
          'clear the level.',
    ),
    _Entry(
      asset: 'assets/power_amplifier_crystal.webp',
      title: 'Power Amplifier',
      desc:
          'A super crystal. When ignited it blasts across the entire row AND '
          'column it sits on. Perfect for clearing large boards in one chain.',
    ),
    _Entry(
      asset: 'assets/shield_blocker_crystal.webp',
      title: 'Shield Blocker',
      desc:
          'Absorbs a single blast and stops the chain from passing through it. '
          'It is then shattered. Use it to understand why a chain stops short.',
    ),
    _Entry(
      asset: 'assets/rock.webp',
      title: 'Rock',
      desc:
          'An indestructible obstacle. Blasts cannot destroy it or pass '
          'through it. Plan your chains around rocks.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.7)),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      _goalCard(),
                      const SizedBox(height: 16),
                      const Text(
                        'OBJECTS',
                        style: TextStyle(
                          color: MagmaColors.ember,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final e in _objects) _objectCard(e),
                      const SizedBox(height: 8),
                      _starsCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: MagmaColors.ash),
          ),
          const Text(
            'HOW TO PLAY',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: MagmaColors.ash,
            ),
          ),
        ],
      ),
    );
  }

  Widget _goalCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.flag_rounded, color: MagmaColors.lavaBright),
              SizedBox(width: 8),
              Text(
                'GOAL',
                style: TextStyle(
                  color: MagmaColors.lavaBright,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Destroy every magma crystal (and power amplifier) on the board '
            'before you run out of charges. Tap to start a blast, then let the '
            'chain reaction do the rest. Fewer charges used = more stars!',
            style: TextStyle(color: MagmaColors.ash, height: 1.4, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _objectCard(_Entry e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _card(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: e.asset.isNotEmpty
                  ? Image.asset(e.asset, fit: BoxFit.contain)
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    e.desc,
                    style: const TextStyle(
                      color: MagmaColors.ash,
                      height: 1.35,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _starsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.star_rounded, color: MagmaColors.ember),
              SizedBox(width: 8),
              Text(
                'STARS',
                style: TextStyle(
                  color: MagmaColors.ember,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'You earn up to 3 stars per level. The fewer charges you spend to '
            'clear the board, the more stars you keep.',
            style: TextStyle(color: MagmaColors.ash, height: 1.4, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: MagmaColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MagmaColors.rockLight.withValues(alpha: 0.8),
          width: 1.5,
        ),
      ),
      child: child,
    );
  }
}
