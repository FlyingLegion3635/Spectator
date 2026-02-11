import 'package:flutter/material.dart';
import 'package:spectator/something.dart';
import 'package:spectator/screens/home/color.dart';

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  final dynamic colors = Colorings();
  final dynamic measurements = Measurements();
  final Functions backend = Functions();
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({String? teamNumber}) async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      await backend.fetchAboutProfile(teamNumber: teamNumber);
    } catch (error) {
      _error = error.toString().replaceFirst('Exception: ', '');
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openEditDialog() async {
    final current = backend.aboutProfile;
    final titleController = TextEditingController(text: '${current['title'] ?? ''}');
    final missionController = TextEditingController(text: '${current['mission'] ?? ''}');
    final sponsorsController =
        TextEditingController(text: ((current['sponsors'] as List<dynamic>?) ?? []).join(', '));
    final websiteController = TextEditingController(text: '${current['website'] ?? ''}');

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit About Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _input('Title', titleController),
                _input('Mission', missionController, maxLines: 5),
                _input('Sponsors (comma separated)', sponsorsController),
                _input('Website', websiteController),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (save == true) {
      try {
        await backend.saveAboutProfile(
          title: titleController.text.trim(),
          mission: missionController.text.trim(),
          sponsors: sponsorsController.text
              .split(',')
              .map((s) => s.trim())
              .where((s) => s.isNotEmpty)
              .toList(),
          website: websiteController.text.trim(),
        );

        if (!mounted) return;
        setState(() {});
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }

    titleController.dispose();
    missionController.dispose();
    sponsorsController.dispose();
    websiteController.dispose();
  }

  Widget _input(String label, TextEditingController controller, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = backend.aboutProfile;
    final sponsors = (profile['sponsors'] as List<dynamic>? ?? [])
        .map((e) => '$e')
        .where((e) => e.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: colors.baseColors[4],
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: AboutBackgroundPainter(colors: colors)),
          ),
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(measurements.largePadding),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!backend.isAuthenticated)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Search team number (e.g. 3635)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          FilledButton(
                            onPressed: () => _loadProfile(
                              teamNumber: _searchController.text.trim(),
                            ),
                            child: const Text('Search'),
                          ),
                        ],
                      ),
                    ),
                  if (backend.canEditAbout)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10.0),
                      child: OutlinedButton.icon(
                        onPressed: _openEditDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit About Page'),
                      ),
                    ),
                  if (_loading)
                    const CircularProgressIndicator()
                  else if (_error.isNotEmpty)
                    Text(_error, style: const TextStyle(color: Colors.redAccent))
                  else
                    Container(
                      padding: EdgeInsets.all(measurements.largePadding),
                      decoration: BoxDecoration(
                        color: colors.mainColors[2].withOpacity(0.8),
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: colors.mainColors[1], width: 2.0),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${profile['title'] ?? 'ABOUT SPECTATOR'}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              color: colors.accentColors[0],
                              fontFamily: 'Monospace',
                            ),
                          ),
                          SizedBox(height: measurements.mediumPadding),
                          Text(
                            '${profile['mission'] ?? ''}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: colors.baseColors[2],
                            ),
                          ),
                          if (sponsors.isNotEmpty) ...[
                            SizedBox(height: measurements.largePadding),
                            Text(
                              'Sponsors',
                              style: TextStyle(
                                color: colors.accentColors[0],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: measurements.smallPadding),
                            for (final sponsor in sponsors)
                              Text(
                                sponsor,
                                style: TextStyle(color: colors.baseColors[2]),
                              ),
                          ],
                          if ('${profile['website'] ?? ''}'.isNotEmpty) ...[
                            SizedBox(height: measurements.mediumPadding),
                            Text(
                              '${profile['website']}',
                              style: TextStyle(
                                color: colors.accentColors[0],
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ],
                      ),
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

class AboutBackgroundPainter extends CustomPainter {
  final dynamic colors;
  AboutBackgroundPainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    paint.color = colors.mainColors[0].withOpacity(0.2);
    canvas.drawCircle(Offset(size.width, 0), size.width * 0.5, paint);

    paint.color = colors.accentColors[0].withOpacity(0.15);
    canvas.drawCircle(Offset(0, size.height), size.width * 0.6, paint);

    paint.color = colors.mainColors[1].withOpacity(0.5);
    paint.strokeWidth = 3;
    paint.style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(size.width * 0.2, 0);
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.5,
      size.width,
      size.height * 0.3,
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
