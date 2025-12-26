import 'package:flutter/material.dart';
import '../../db/achievementDb.dart';
import '../../Models/Acheivement.dart';

class AchievementScreen extends StatefulWidget {
  const AchievementScreen({Key? key}) : super(key: key);

  @override
  State<AchievementScreen> createState() => _AchievementScreenState();
}

class _AchievementScreenState extends State<AchievementScreen> {
  final AchievementDb _achievementDb = AchievementDb();
  late Future<List<Achievement>> _futureAchievements;

  @override
  void initState() {
    super.initState();
    // Lấy danh sách achievement của user hiện tại
    _futureAchievements = _achievementDb.getAchievements();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Achievements")),
      body: FutureBuilder<List<Achievement>>(
        future: _futureAchievements,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("No achievements found."));
          }

          final achievements = snapshot.data!;

          return ListView.builder(
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              Achievement achievement = achievements[index];

              // Kiểm tra xem achievement đã hoàn thành hay chưa
              bool isCompleted = achievement.progress >= achievement.goal;

              // Màu nền của Card
              Color cardColor = isCompleted ? Colors.amber.shade700 : Colors.white;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 5,
                color: cardColor, // Đổi màu khi hoàn thành
                shadowColor: isCompleted ? Colors.amber.shade300 : Colors.black54, // Hiệu ứng bóng
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.emoji_events,
                            size: 40,
                            color: isCompleted ? Colors.yellowAccent.shade700 : Colors.amber,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              achievement.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          color: isCompleted ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: (achievement.progress / achievement.goal).clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[300],
                        color: isCompleted ? Colors.greenAccent : Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Progress: ${achievement.progress}/${achievement.goal}",
                        style: TextStyle(
                          color: isCompleted ? Colors.white : Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isCompleted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 24),
                              const SizedBox(width: 8),
                              Text(
                                "Completed!",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
