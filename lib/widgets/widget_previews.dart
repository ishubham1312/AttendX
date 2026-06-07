import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../providers/app_provider.dart';

class SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.present
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Scale and replicate M2,18 C30,22 45,14 60,12 C75,10 90,4 118,3 from the vector drawable
    // Viewport is 120 x 24. We map it to the actual width and height.
    final double sx = size.width / 120.0;
    final double sy = size.height / 24.0;

    path.moveTo(2.0 * sx, 18.0 * sy);
    path.cubicTo(
      30.0 * sx, 22.0 * sy,
      45.0 * sx, 14.0 * sy,
      60.0 * sx, 12.0 * sy,
    );
    path.cubicTo(
      75.0 * sx, 10.0 * sy,
      90.0 * sx, 4.0 * sy,
      118.0 * sx, 3.0 * sy,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class Widget1x1Preview extends StatelessWidget {
  final String status; // 'present', 'halfDay', 'absent', 'pending'
  final String time;

  const Widget1x1Preview({
    super.key,
    required this.status,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'present':
        statusColor = AppColors.present;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'PRESENT';
        break;
      case 'halfDay':
        statusColor = AppColors.halfDay;
        statusIcon = Icons.timelapse_rounded;
        statusLabel = 'HALF DAY';
        break;
      case 'absent':
        statusColor = AppColors.absent;
        statusIcon = Icons.cancel_rounded;
        statusLabel = 'ABSENT';
        break;
      case 'holiday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusLabel = 'HOLIDAY';
        break;
      case 'sunday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusLabel = 'SUNDAY';
        break;
      default:
        statusColor = AppColors.textSubtle;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'PENDING';
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(statusIcon, size: 36, color: statusColor),
            const SizedBox(height: 8),
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: statusColor,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              (status == 'pending') ? 'Mark Today' : (status == 'sunday' || status == 'holiday') ? 'Day Off' : time,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class Widget2x1Preview extends StatelessWidget {
  final String status;
  final String time;
  final String dateStr;
  final String scoreStr;

  const Widget2x1Preview({
    super.key,
    required this.status,
    required this.time,
    required this.dateStr,
    required this.scoreStr,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == 'pending';
    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusSubtitle;

    switch (status) {
      case 'present':
        statusColor = AppColors.present;
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'Present';
        statusSubtitle = 'Today marked at $time';
        break;
      case 'halfDay':
        statusColor = AppColors.halfDay;
        statusIcon = Icons.timelapse_rounded;
        statusTitle = 'Half Day';
        statusSubtitle = 'Today marked at $time';
        break;
      case 'absent':
        statusColor = AppColors.absent;
        statusIcon = Icons.cancel_rounded;
        statusTitle = 'Absent';
        statusSubtitle = 'Today marked at $time';
        break;
      case 'holiday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusTitle = 'Holiday';
        statusSubtitle = 'Day Off';
        break;
      case 'sunday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusTitle = 'Sunday';
        statusSubtitle = 'Day Off';
        break;
      default:
        statusColor = AppColors.textSubtle;
        statusIcon = Icons.help_outline_rounded;
        statusTitle = 'Attendance Pending';
        statusSubtitle = 'Tap to mark attendance';
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  statusIcon,
                  size: 36,
                  color: isPending ? AppColors.textSubtle : statusColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: isPending ? AppColors.textPrimary : statusColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusSubtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 1,
            color: const Color(0xFFF1F5F9),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
              if (isPending)
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                )
              else
                Text(
                  scoreStr.isNotEmpty ? 'Attendance • $scoreStr' : 'Attendance • Marked',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.present,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class Widget2x2Preview extends StatelessWidget {
  final String name;
  final String status;
  final String time;
  final String presentCount;
  final String halfDayCount;
  final String absentCount;
  final String scoreStr;

  const Widget2x2Preview({
    super.key,
    required this.name,
    required this.status,
    required this.time,
    required this.presentCount,
    required this.halfDayCount,
    required this.absentCount,
    required this.scoreStr,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == 'pending';
    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    switch (status) {
      case 'present':
        statusColor = AppColors.present;
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'Present';
        break;
      case 'halfDay':
        statusColor = AppColors.halfDay;
        statusIcon = Icons.timelapse_rounded;
        statusTitle = 'Half Day';
        break;
      case 'absent':
        statusColor = AppColors.absent;
        statusIcon = Icons.cancel_rounded;
        statusTitle = 'Absent';
        break;
      case 'holiday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusTitle = 'Holiday';
        break;
      case 'sunday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusTitle = 'Sunday';
        break;
      default:
        statusColor = AppColors.textSubtle;
        statusIcon = Icons.help_outline_rounded;
        statusTitle = 'Pending';
    }

    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Good Morning, $name',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Status Card
            Row(
              children: [
                Icon(
                  statusIcon,
                  size: 32,
                  color: isPending ? AppColors.textSubtle : statusColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        statusTitle,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isPending ? AppColors.textSubtle : statusColor,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            (status == 'sunday' || status == 'holiday') ? 'Day Off' : 'Marked Today',
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w400,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          if (!isPending && status != 'sunday' && status != 'holiday') ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                time,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w800,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Stats Grid
            Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Present',
                          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          presentCount,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.present,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Half Day',
                          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          halfDayCount,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.halfDay,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 20, color: const Color(0xFFE2E8F0)),
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Absent',
                          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          absentCount,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.absent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Bottom Score Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Score',
                      style: TextStyle(fontSize: 9, color: AppColors.textSubtle),
                    ),
                    Text(
                      scoreStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: 65,
                  height: 20,
                  child: CustomPaint(
                    painter: SparklinePainter(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class Widget4x2Preview extends StatelessWidget {
  final String status;
  final String time;
  final String monthYear;
  final String presentCount;
  final String halfDayCount;
  final String absentCount;
  final String earnedSalary;
  final String estimatedSalary;
  final int progress;

  const Widget4x2Preview({
    super.key,
    required this.status,
    required this.time,
    required this.monthYear,
    required this.presentCount,
    required this.halfDayCount,
    required this.absentCount,
    required this.earnedSalary,
    required this.estimatedSalary,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = status == 'pending';
    Color statusColor;
    IconData statusIcon;
    String statusTitle;

    switch (status) {
      case 'present':
        statusColor = AppColors.present;
        statusIcon = Icons.check_circle_rounded;
        statusTitle = 'Present';
        break;
      case 'halfDay':
        statusColor = AppColors.halfDay;
        statusIcon = Icons.timelapse_rounded;
        statusTitle = 'Half Day';
        break;
      case 'absent':
        statusColor = AppColors.absent;
        statusIcon = Icons.cancel_rounded;
        statusTitle = 'Absent';
        break;
      case 'holiday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusTitle = 'Holiday';
        break;
      case 'sunday':
        statusColor = AppColors.holiday;
        statusIcon = Icons.beach_access_rounded;
        statusTitle = 'Sunday';
        break;
      default:
        statusColor = AppColors.textSubtle;
        statusIcon = Icons.help_outline_rounded;
        statusTitle = 'Pending';
    }

    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          // LEFT PANEL (55% width)
          Expanded(
            flex: 55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthYear,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      statusIcon,
                      size: 32,
                      color: isPending ? AppColors.textSubtle : statusColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isPending ? AppColors.textSubtle : statusColor,
                            ),
                          ),
                          Text(
                            isPending ? 'Attendance Pending' : (status == 'sunday' || status == 'holiday') ? 'Day Off' : 'Marked Today · $time',
                            style: const TextStyle(
                              fontSize: 9.5,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  height: 1,
                  color: const Color(0xFFF1F5F9),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Present',
                            style: TextStyle(fontSize: 9, color: AppColors.present, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            presentCount,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: const Color(0xFFF1F5F9)),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Half Day',
                            style: TextStyle(fontSize: 9, color: AppColors.halfDay, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            halfDayCount,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 24, color: const Color(0xFFF1F5F9)),
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Absent',
                            style: TextStyle(fontSize: 9, color: AppColors.absent, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            absentCount,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Vertical Divider
          Container(width: 1, height: double.infinity, color: const Color(0xFFF1F5F9)),
          const SizedBox(width: 12),
          // RIGHT PANEL (45% width)
          Expanded(
            flex: 45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Salary Earned So Far',
                      style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                    ),
                    Icon(
                      Icons.more_horiz,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  earnedSalary,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.present,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress / 100.0,
                          backgroundColor: const Color(0xFFE2E8F0),
                          color: AppColors.present,
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'of estimated salary',
                  style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estimated Salary',
                      style: TextStyle(fontSize: 9, color: AppColors.textSubtle),
                    ),
                    Text(
                      estimatedSalary,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
