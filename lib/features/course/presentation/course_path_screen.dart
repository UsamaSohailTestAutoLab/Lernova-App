import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_background.dart';
import '../../../core/widgets/state_views.dart';
import '../../../data/models/course.dart';
import '../../../data/models/user_progress.dart';
import '../../../data/repositories/content_providers.dart';
import '../../lessons/application/lesson_nav_args.dart';
import '../../onboarding/application/user_controller.dart';
import '../../progress/application/progress_controller.dart';
import '../application/course_progress.dart';
import '../application/path_layout.dart';
import 'widgets/path_node.dart';
import 'widgets/path_unit_banner.dart';

class CoursePathScreen extends ConsumerWidget {
  const CoursePathScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    if (user.currentCourseId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final courseAsync = ref.watch(courseByIdProvider(user.currentCourseId!));

    return AppBackground(
      variant: AppBackdrop.journey,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Your path')),
        body: courseAsync.when(
          loading: () => const _PathLoading(),
          error: (e, st) => ErrorStateView(
            message: 'Could not load your path.',
            onRetry: () => ref.invalidate(courseByIdProvider(user.currentCourseId!)),
          ),
          data: (course) {
            if (course == null) {
              return const EmptyStateView(title: 'No course', message: 'Pick a course in settings.');
            }
            return _PathList(course: course);
          },
        ),
      ),
    );
  }
}

class _PathLoading extends StatelessWidget {
  const _PathLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl, horizontal: AppSpacing.xl),
      children: const [
        SkeletonPathNode(size: 80),
        SizedBox(height: AppSpacing.lg),
        SkeletonPathNode(),
        SizedBox(height: AppSpacing.lg),
        SkeletonPathNode(),
      ],
    );
  }
}

class _PathList extends ConsumerStatefulWidget {
  final Course course;
  const _PathList({required this.course});

  @override
  ConsumerState<_PathList> createState() => _PathListState();
}

class _PathListState extends ConsumerState<_PathList> {
  late final ScrollController _controller;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(progressProvider);
    final items = PathLayout.flatten(widget.course);
    final direction = Directionality.of(context);

    if (!_didInitialScroll) {
      _didInitialScroll = true;
      final current = CourseProgress.findCurrentLesson(widget.course, progress);
      if (current != null) {
        final targetIndex = PathLayout.indexForLesson(items, current.$1, current.$2);
        if (targetIndex != null) {
          final target = PathLayout.offsetForIndex(targetIndex, items) - 160;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_controller.hasClients) {
              _controller.jumpTo(target.clamp(0, _controller.position.maxScrollExtent));
            }
          });
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = PathGeometry.forWidth(constraints.maxWidth, direction);

        return ListView.builder(
          controller: _controller,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.xl),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];

            if (item is PathUnitBanner) {
              final unit = widget.course.units[item.unitIndex];
              final completed =
                  unit.lessons.where((l) => progress.completedLessonIds.contains(l.id)).length;
              final reachable = CourseProgress.isUnitReachable(item.unitIndex, progress);
              final incomingDx = item.unitIndex == 0
                  ? 0.0
                  : geometry.dxFor(widget.course.units[item.unitIndex - 1].lessons.length - 1);
              return PathUnitBannerCard(
                unit: unit,
                unitIndex: item.unitIndex,
                completedCount: completed,
                totalCount: unit.lessons.length,
                reachable: reachable,
                incomingDx: incomingDx,
              );
            }

            final node = item as PathNodeItem;
            final lesson = widget.course.units[node.unitIndex].lessons[node.lessonIndex];
            final state = CourseProgress.lessonState(
              course: widget.course,
              unitIndex: node.unitIndex,
              lessonIndex: node.lessonIndex,
              progress: progress,
            );
            final playable = CourseProgress.isLessonPlayable(state);
            final dx = geometry.dxFor(node.lessonIndex);
            final incomingDx = node.lessonIndex == 0 ? 0.0 : geometry.dxFor(node.lessonIndex - 1);

            return PathNode(
              lesson: lesson,
              state: state,
              dx: dx,
              incomingDx: incomingDx,
              nodeSize: geometry.nodeSize,
              currentNodeSize: geometry.currentNodeSize,
              lockedMessage: playable
                  ? null
                  : _lockedMessageFor(widget.course, node.unitIndex, node.lessonIndex, progress),
              onTap: playable
                  ? () => context.push(
                        AppRoutes.lessonIntro,
                        extra: LessonNavArgs(
                          course: widget.course,
                          unitIndex: node.unitIndex,
                          lessonIndex: node.lessonIndex,
                          lesson: lesson,
                        ),
                      )
                  : null,
            );
          },
        );
      },
    );
  }

  String _lockedMessageFor(Course course, int unitIndex, int lessonIndex, UserProgress progress) {
    if (!CourseProgress.isUnitReachable(unitIndex, progress)) {
      return 'Complete Unit $unitIndex to unlock this.';
    }
    if (lessonIndex > 0) {
      final previous = course.units[unitIndex].lessons[lessonIndex - 1];
      return "Complete '${previous.title}' first.";
    }
    return 'Complete earlier lessons to unlock this.';
  }
}
