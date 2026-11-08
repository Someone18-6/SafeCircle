import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/app_services.dart';
import '../theme.dart';
import '../utils/helpers.dart';
import '../widgets/common.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});

  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  Position? _position;
  DateTime? _fetchedAt;
  bool _loading = false;
  String? _error;

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await AppServices.currentPosition();
      if (!mounted) return;
      setState(() {
        _position = result;
        _fetchedAt = DateTime.now();
      });
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _link => mapsLink(_position!.latitude, _position!.longitude);

  @override
  Widget build(BuildContext context) {
    final position = _position;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeader(
          title: 'My location',
          subtitle: 'Find where you are and share it with your circle.',
        ),
        AppCard(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: position == null ? coralSoft : successSoft,
                child: Icon(
                  position == null
                      ? Icons.location_searching
                      : Icons.location_on,
                  size: 38,
                  color: position == null ? coral : success,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                position == null
                    ? 'Location not retrieved yet'
                    : 'Location found',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: navy,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                position == null
                    ? 'Tap the button below. Your browser or device will ask '
                          'for permission to use your location.'
                    : 'Updated ${timeAgo(_fetchedAt!)}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                ErrorNotice(_error!),
              ],
              if (position != null) ...[
                const SizedBox(height: 22),
                _CoordinateRow(
                  label: 'Latitude',
                  value: position.latitude.toStringAsFixed(6),
                ),
                const SizedBox(height: 10),
                _CoordinateRow(
                  label: 'Longitude',
                  value: position.longitude.toStringAsFixed(6),
                ),
                const SizedBox(height: 10),
                _CoordinateRow(
                  label: 'Accuracy',
                  value:
                      '\u00B1 ${position.accuracy.toStringAsFixed(0)} metres',
                ),
              ],
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: coral),
                    onPressed: _loading ? null : _fetch,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            position == null
                                ? Icons.my_location
                                : Icons.refresh_rounded,
                            size: 20,
                          ),
                    label: Text(
                      _loading
                          ? 'Locating...'
                          : (position == null
                                ? 'Get my location'
                                : 'Refresh location'),
                    ),
                  ),
                  if (position != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => openOrWarn(
                        context,
                        Uri.parse(_link),
                        failure: 'Could not open Google Maps.',
                      ),
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('Open in Maps'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => copyWithFeedback(
                        context,
                        _link,
                        message: 'Map link copied',
                      ),
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      label: const Text('Copy link'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => showShareSheet(
                        context,
                        title: 'Share my location',
                        message: buildLocationMessage(
                          name: AppServices.displayName,
                          latitude: position.latitude,
                          longitude: position.longitude,
                        ),
                      ),
                      icon: const Icon(Icons.share_outlined, size: 20),
                      label: const Text('Share with contacts'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const AppCard(
          color: blueSoft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: navy, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your location is only read when you press a button on this '
                  'page, or when you send an SOS or share your location. It '
                  'is never tracked in the background.',
                  style: TextStyle(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoordinateRow extends StatelessWidget {
  final String label;
  final String value;

  const _CoordinateRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: muted)),
          const Spacer(),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700, color: navy),
          ),
        ],
      ),
    );
  }
}
