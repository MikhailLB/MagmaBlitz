import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/magma_button.dart';
import 'how_to_play_screen.dart';
import 'level_select_screen.dart';
import 'webview_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/bg.webp', fit: BoxFit.cover),
          Container(color: Colors.black.withValues(alpha: 0.35)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Image.asset('assets/logo.webp', fit: BoxFit.contain),
                  const Spacer(flex: 3),
                  MagmaButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    big: true,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LevelSelectScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  MagmaButton(
                    label: 'HOW TO PLAY',
                    icon: Icons.help_outline_rounded,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const HowToPlayScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: MagmaButton(
                          label: 'Privacy',
                          icon: Icons.privacy_tip_outlined,
                          onTap: () => _openWeb(
                            context,
                            'Privacy Policy',
                            'https://magmablitz.com/privacy-policy.html',
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: MagmaButton(
                          label: 'Support',
                          icon: Icons.support_agent_outlined,
                          onTap: () => _openWeb(
                            context,
                            'Support',
                            'https://magmablitz.com/support.html',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  const Text(
                    'Tap a crystal to ignite a chain reaction',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MagmaColors.ember,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openWeb(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WebViewScreen(title: title, url: url),
      ),
    );
  }
}
