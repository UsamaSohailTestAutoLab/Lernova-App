import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/service_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/exercise.dart';
import '../application/lesson_session_controller.dart';
import 'widgets/option_choice_list.dart';

class ListeningExercise extends ConsumerStatefulWidget {
  final ListeningPayload payload;
  final ExerciseFeedback feedback;
  final ValueChanged<int> onSelect;

  const ListeningExercise({
    super.key,
    required this.payload,
    required this.feedback,
    required this.onSelect,
  });

  @override
  ConsumerState<ListeningExercise> createState() => _ListeningExerciseState();
}

class _ListeningExerciseState extends ConsumerState<ListeningExercise> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    ref
        .read(ttsServiceProvider)
        .speak(widget.payload.audioText, locale: widget.payload.ttsLocale);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.payload.prompt, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: GestureDetector(
            onTap: _play,
            child: Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 40),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        OptionChoiceList(
          options: widget.payload.options,
          correctIndex: widget.payload.correctIndex,
          feedback: widget.feedback,
          onSelect: widget.onSelect,
        ),
      ],
    );
  }
}
