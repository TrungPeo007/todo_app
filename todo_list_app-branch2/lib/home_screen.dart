import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:table_calendar/table_calendar.dart';
import 'dart:io';

import 'screens/parent/parent_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String? role;
  String displayName = "Đang tải...";
  String email = "Đang tải...";
  int _selectedIndex = 0;
  bool _isVietnamese = true;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndName();
    _logLogin();
    _selectedDay = _focusedDay;
  }

  Future<void> _logLogin() async {
    if (currentUser == null) return;
    try {
      await FirebaseFirestore.instance.collection('logins').add({
        'userUid': currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Lỗi ghi log login: $e");
    }
  }

  Future<void> _loadUserRoleAndName() async {
    if (currentUser == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .get();

    if (doc.exists) {
      setState(() {
        role = doc['role'];
        displayName = doc['displayName'] ?? currentUser!.email ?? (_isVietnamese ? "Bé yêu" : "Little one");
        email = doc['email'] ?? currentUser!.email ?? "";
      });
    } else {
      setState(() {
        role = 'child';
        displayName = currentUser!.email ?? (_isVietnamese ? "Bé yêu" : "Little one");
        email = currentUser!.email ?? "";
      });
    }
  }

  Future<void> _confirmLogout() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(_isVietnamese ? "Đăng xuất" : "Logout", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Text(_isVietnamese ? "Bạn có muốn đăng xuất không bé yêu? 😢" : "Do you want to log out, sweetie? 😢"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_isVietnamese ? "Hủy" : "Cancel", style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_isVietnamese ? "Có, đăng xuất" : "Yes, log out", style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Chưa đăng nhập")));
    }

    if (role == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (role == 'parent') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentHomeScreen()),
        );
      });
      return const Scaffold(body: Center(child: Text("Đang chuyển đến trang phụ huynh...")));
    }

    return _buildChildHome();
  }

  Widget _buildChildHome() {
    final List<String> titlesVi = ['Tổng quan', 'Việc được giao', 'Phần thưởng', 'Lịch cá nhân', 'Điểm thưởng'];
    final List<String> titlesEn = ['Overview', 'Assigned Tasks', 'Rewards', 'Personal Calendar', 'Points'];
    final List<String> titles = _isVietnamese ? titlesVi : titlesEn;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(titles[_selectedIndex]),
        backgroundColor: Colors.orange[400],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
      ),
      drawer: _buildDrawer(titles),
      body: _buildChildBody(titles),
    );
  }

  Drawer _buildDrawer(List<String> titles) {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 240,
            decoration: const BoxDecoration(color: Colors.white),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.orange, width: 4),
                  ),
                  child: const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.transparent,
                    child: Icon(Icons.child_care_rounded, size: 70, color: Colors.orange),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  email,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(_isVietnamese ? "Ngôn ngữ: Tiếng Việt" : "Language: English"),
                  trailing: Switch(
                    value: !_isVietnamese,
                    onChanged: (value) {
                      setState(() {
                        _isVietnamese = !value;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                for (int i = 0; i < titles.length; i++)
                  ListTile(
                    leading: Icon(
                      i == 0 ? Icons.dashboard_rounded :
                      i == 1 ? Icons.task_alt_rounded :
                      i == 2 ? Icons.card_giftcard_rounded :
                      i == 3 ? Icons.calendar_month_rounded :
                      Icons.star_rounded,
                      color: i <= 2 ? Colors.orange : i == 3 ? Colors.green : Colors.amber,
                      size: 28,
                    ),
                    title: Text(titles[i], style: const TextStyle(fontSize: 18)),
                    selected: _selectedIndex == i,
                    selectedTileColor: i <= 2 ? Colors.orange[50] : i == 3 ? Colors.green[50] : Colors.amber[50],
                    onTap: () {
                      setState(() => _selectedIndex = i);
                      Navigator.pop(context);
                    },
                  ),
                const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
                  title: Text(_isVietnamese ? "Đăng xuất" : "Logout", style: const TextStyle(fontSize: 18, color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmLogout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildBody(List<String> titles) {
    switch (_selectedIndex) {
      case 0:
        return _buildChildOverview();
      case 1:
        return _buildTasksTab();
      case 2:
        return _buildChildRewardsTab();
      case 3:
        return _buildCalendarTab();
      case 4:
        return _buildPointsTab();
      default:
        return const SizedBox();
    }
  }

  Widget _buildCalendarTab() {
    final String uid = currentUser!.uid;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        Map<DateTime, List<Map<String, dynamic>>> events = {};

        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            Timestamp? dueTimestamp = data['dueDate'];
            if (dueTimestamp != null) {
              DateTime dueDate = dueTimestamp.toDate();
              DateTime normalizedDate = DateTime(dueDate.year, dueDate.month, dueDate.day);

              events.putIfAbsent(normalizedDate, () => []);
              events[normalizedDate]!.add({
                'id': doc.id,
                'title': data['title'] ?? (_isVietnamese ? 'Việc gì đó' : 'Some task'),
                'status': data['status'] ?? 'pending',
                'rewardXP': data['rewardXP'] ?? 0,
              });
            }
          }
        }

        return Column(
          children: [
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: TableCalendar(
                locale: _isVietnamese ? 'vi_VN' : 'en_US',
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onFormatChanged: (format) {
                  setState(() {
                    _calendarFormat = format;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  DateTime normalized = DateTime(day.year, day.month, day.day);
                  return events[normalized] ?? [];
                },
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
                  markerDecoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  markersMaxCount: 4,
                ),
                headerStyle: const HeaderStyle(
                  titleCentered: true,
                  formatButtonVisible: false,
                  titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange),
                  leftChevronIcon: Icon(Icons.chevron_left, color: Colors.orange),
                  rightChevronIcon: Icon(Icons.chevron_right, color: Colors.orange),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _isVietnamese ? "Việc cần làm hôm nay" : "Tasks for today",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _selectedDay == null
                  ? Center(child: Text(_isVietnamese ? "Chọn một ngày để xem việc nhé bé! 📅" : "Pick a day to see tasks, sweetie! 📅"))
                  : _buildTasksForSelectedDay(events, _selectedDay!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTasksForSelectedDay(Map<DateTime, List<Map<String, dynamic>>> events, DateTime selectedDay) {
    DateTime normalized = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    List<Map<String, dynamic>> dayTasks = events[normalized] ?? [];

    if (dayTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sentiment_satisfied_alt, size: 80, color: Colors.orange),
            SizedBox(height: 16),
            Text(
              _isVietnamese ? "Hôm nay bé được nghỉ ngơi rồi!\nKhông có việc nào hết á 🌈" : "No tasks today!\nYou can rest, sweetie! 🌈",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dayTasks.length,
      itemBuilder: (context, index) {
        var task = dayTasks[index];
        String status = task['status'];
        Color statusColor = status == 'approved'
            ? Colors.green
            : status == 'submitted'
                ? Colors.blue
                : status == 'rejected'
                    ? Colors.red
                    : Colors.orange;

        String statusText = status == 'approved'
            ? (_isVietnamese ? "Hoàn thành rồi! 🎉" : "Completed! 🎉")
            : status == 'submitted'
                ? (_isVietnamese ? "Đang chờ duyệt" : "Waiting for approval")
                : status == 'rejected'
                    ? (_isVietnamese ? "Làm lại nhé!" : "Please redo!")
                    : (_isVietnamese ? "Chưa làm xong" : "Not done yet");

        return Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: Icon(
              status == 'approved' ? Icons.celebration : Icons.task_alt,
              color: statusColor,
              size: 40,
            ),
            title: Text(
              task['title'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text("+${task['rewardXP']} XP • $statusText"),
            trailing: const Icon(Icons.arrow_forward_ios, color: Colors.orange),
            onTap: () {
              setState(() => _selectedIndex = 1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(_isVietnamese ? "Đang mở việc: ${task['title']}" : "Opening task: ${task['title']}")),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildChildOverview() {
    final String uid = currentUser!.uid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isVietnamese ? "Tổng quan tuần này bé ơi! 🌟" : "This week's overview, sweetie! 🌟", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 20),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('assignedTo', isEqualTo: uid)
                .snapshots(includeMetadataChanges: true),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              int totalTasks = taskSnapshot.data!.docs.length;
              int completedTasks = taskSnapshot.data!.docs.where((doc) => doc['status'] == 'approved').length;
              double completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

              return Column(
                children: [
                  _childStatCard(_isVietnamese ? "Việc được giao" : "Assigned tasks", totalTasks.toString(), Icons.task_alt_rounded, Colors.orange),
                  const SizedBox(height: 12),
                  _childStatCard(_isVietnamese ? "Đã hoàn thành" : "Completed", completedTasks.toString(), Icons.celebration, Colors.green),
                  const SizedBox(height: 12),
                  _childStatCard(_isVietnamese ? "Tỷ lệ hoàn thành" : "Completion rate", "${completionRate.toStringAsFixed(0)}%", Icons.trending_up_rounded, Colors.blue),
                ],
              );
            },
          ),

          const SizedBox(height: 30),

          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('experience')
                .doc(uid)
                .snapshots(),
            builder: (context, expSnapshot) {
              if (!expSnapshot.hasData || !expSnapshot.data!.exists) {
                return Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      _isVietnamese ? "Chưa có điểm thưởng nào! Làm việc tốt để nhận sao nhé bé 🌟" : "No points yet! Do good tasks to earn stars! 🌟",
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              var data = expSnapshot.data!.data() as Map<String, dynamic>;
              int xpCurrent = data['xpCurrent'] ?? 0;

              return Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _isVietnamese ? "Điểm thưởng hiện tại" : "Current points",
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 30),
                      Text(
                        "$xpCurrent XP",
                        style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isVietnamese ? "Cố lên bé yêu! Hoàn thành việc để nhận thêm sao nhé 🌟" : "Keep going, sweetie! Complete tasks to earn more stars! 🌟",
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _childStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, size: 50, color: color),
        title: Text(title, style: const TextStyle(fontSize: 16, color: Colors.black87)),
        trailing: Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildChildRewardsTab() {
    final String uid = currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('experience')
          .doc(uid)
          .snapshots(),
      builder: (context, expSnapshot) {
        int currentXP = 0;
        if (expSnapshot.hasData && expSnapshot.data!.exists) {
          currentXP = expSnapshot.data!['xpCurrent'] ?? 0;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('rewards')
              .orderBy('points', descending: true)
              .snapshots(includeMetadataChanges: true),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text(_isVietnamese ? "Ôi không! Có lỗi rồi 😢" : "Oh no! Something went wrong 😢"));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.card_giftcard_rounded, size: 120, color: Colors.orange),
                    const SizedBox(height: 24),
                    Text(
                      _isVietnamese ? "Chưa có phần thưởng nào hết!\nHỏi bố mẹ thêm quà đi bé yêu 🎁" : "No rewards yet!\nAsk mom/dad to add some gifts, sweetie! 🎁",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                var data = doc.data() as Map<String, dynamic>;
                String rewardId = doc.id;
                String name = data['name'] ?? (_isVietnamese ? 'Quà bí mật' : 'Mystery gift');
                String desc = data['description'] ?? (_isVietnamese ? 'Không có mô tả' : 'No description');
                int points = data['points'] ?? 10;

                bool canExchange = currentXP >= points;

                return Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(20),
                    leading: Icon(
                      Icons.card_giftcard_rounded,
                      size: 60,
                      color: canExchange ? Colors.orange : Colors.grey,
                    ),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: canExchange ? Colors.orange : Colors.grey[600],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(desc, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.star_rounded, color: canExchange ? Colors.amber : Colors.grey),
                            const SizedBox(width: 8),
                            Text(
                              _isVietnamese ? "Cần $points XP" : "Need $points XP",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: canExchange ? Colors.amber : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    onTap: () => _showRewardDetail(context, rewardId, name, desc, points, currentXP),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showRewardDetail(BuildContext context, String rewardId, String name, String desc, int points, int currentXP) {
    bool canExchange = currentXP >= points;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc, style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 30),
                  const SizedBox(width: 10),
                  Text(_isVietnamese ? "Cần: $points XP" : "Need: $points XP", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.green, size: 30),
                  const SizedBox(width: 10),
                  Text(_isVietnamese ? "Bạn có: $currentXP XP" : "You have: $currentXP XP", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                ],
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: Icon(canExchange ? Icons.card_giftcard : Icons.lock, size: 24),
                  label: Text(canExchange ? (_isVietnamese ? "Đổi phần thưởng" : "Exchange reward") : (_isVietnamese ? "Chưa đủ điểm" : "Not enough points"), style: const TextStyle(fontSize: 18)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canExchange ? Colors.orange : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: canExchange
                      ? () async {
                          await _exchangeReward(rewardId, points);
                          Navigator.pop(context);
                        }
                      : null,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_isVietnamese ? "Đóng" : "Close", style: const TextStyle(fontSize: 18, color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Future<void> _exchangeReward(String rewardId, int points) async {
    final String uid = currentUser!.uid;
    final expRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('experience')
        .doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(expRef);
        if (!snapshot.exists) return;

        int currentXP = snapshot['xpCurrent'] ?? 0;
        if (currentXP < points) return;

        transaction.update(expRef, {'xpCurrent': currentXP - points});
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isVietnamese ? "Đổi thưởng thành công! Bé giỏi quá! 🎉" : "Reward exchanged successfully! Great job! 🎉")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isVietnamese ? "Lỗi đổi thưởng: $e" : "Exchange error: $e")),
        );
      }
    }
  }

  Widget _buildTasksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: currentUser!.uid)
          .snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(_isVietnamese ? "Ôi không! Có lỗi rồi 😢" : "Oh no! Something went wrong 😢"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.sentiment_satisfied_alt, size: 100, color: Colors.orange),
                const SizedBox(height: 20),
                Text(
                  _isVietnamese ? "Chưa có việc nào hết!\nHỏi bố mẹ xem có việc gì làm không nhé! 😊" : "No tasks yet!\nAsk mom/dad if there's anything to do! 😊",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        var docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp? ?? Timestamp.now();
          final bTime = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp? ?? Timestamp.now();
          return bTime.compareTo(aTime);
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var doc = docs[index];
            var data = doc.data() as Map<String, dynamic>;
            String taskId = doc.id;
            String title = data['title'] ?? (_isVietnamese ? 'Việc vui' : 'Fun task');
            String desc = data['description'] ?? '';
            String status = data['status'] ?? 'pending';
            int reward = data['rewardXP'] ?? 0;
            Timestamp? dueTimestamp = data['dueDate'];
            String dueDate = dueTimestamp != null
                ? "${_isVietnamese ? "Hạn" : "Due"}: ${dueTimestamp.toDate().toLocal().day}/${dueTimestamp.toDate().toLocal().month}"
                : (_isVietnamese ? "Không gấp lắm đâu!" : "No rush!");

            Color statusColor = Colors.orange;
            String statusText = _isVietnamese ? "Chưa làm xong" : "Not done yet";
            IconData statusIcon = Icons.hourglass_bottom;

            switch (status) {
              case 'submitted':
                statusColor = Colors.blue;
                statusText = _isVietnamese ? "Đã báo xong!" : "Reported!";
                statusIcon = Icons.check_circle_outline;
                break;
              case 'approved':
                statusColor = Colors.green;
                statusText = _isVietnamese ? "Hoàn thành rồi! 🎉" : "Completed! 🎉";
                statusIcon = Icons.celebration;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusText = _isVietnamese ? "Làm lại nhé!" : "Please redo!";
                statusIcon = Icons.refresh;
                break;
            }

            return Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.all(20),
                title: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Text(desc, style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 12),
                    Text(dueDate, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.card_giftcard_rounded, color: Colors.orange, size: 28),
                        const SizedBox(width: 8),
                        Text("+$reward XP", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(statusIcon, color: statusColor),
                            const SizedBox(width: 8),
                            Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                    if (status == 'pending' || status == 'rejected')
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                label: Text(_isVietnamese ? "Làm xong rồi!" : "I'm done!", style: const TextStyle(fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  elevation: 4,
                                ),
                                onPressed: () => _markAsDone(taskId),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                                label: const Text("Bằng chứng", style: TextStyle(fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  elevation: 4,
                                ),
                                onPressed: () => _uploadEvidence(taskId),
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
    );
  }

  Future<void> _markAsDone(String taskId) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isVietnamese ? "Bé báo xong rồi! Chờ bố mẹ duyệt nhé 🌟" : "Reported! Waiting for parent's approval 🌟")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isVietnamese ? "Ôi không, lỗi rồi: $e" : "Oh no, error: $e")),
        );
      }
    }
  }

  Future<void> _uploadEvidence(String taskId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Bé chưa chọn ảnh nè 😅" : "No photo selected 😅")));
      return;
    }

    String path = pickedFile.path.toLowerCase();
    if (!path.endsWith('.jpg') && !path.endsWith('.jpeg') && !path.endsWith('.png')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isVietnamese ? "Chỉ được chọn ảnh .jpg hoặc .png thôi nha bé! 📸" : "Only .jpg or .png photos allowed! 📸")),
      );
      return;
    }

    File file = File(pickedFile.path);
    int fileSizeInBytes = await file.length();
    if (fileSizeInBytes > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isVietnamese ? "Ảnh to quá rồi! Chọn ảnh nhỏ hơn 5MB nhé bé ❤️" : "Photo too big! Choose under 5MB ❤️")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Đang gửi ảnh cho bố mẹ xem... 📤" : "Sending photo... 📤")));

    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child('evidences/$taskId/$fileName');

      UploadTask uploadTask = ref.putFile(file);
      TaskSnapshot taskSnapshot = await uploadTask;

      String url = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).collection('evidences').add({
        'url': url,
        'uploadedBy': currentUser!.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({'status': 'submitted'});

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Gửi ảnh thành công rồi! Bé giỏi quá! 🌟" : "Photo sent successfully! Great job! 🌟")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Ôi không, lỗi rồi: $e" : "Oh no, error: $e")));
      }
    }
  }

  Widget _buildPointsTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('experience')
          .doc(currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_border_rounded, size: 120, color: Colors.orange),
                const SizedBox(height: 24),
                Text(_isVietnamese ? "Chưa có điểm nào hết!\nLàm việc tốt để nhận sao nhé bé! 🌟" : "No points yet!\nDo good tasks to earn stars! 🌟",
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
          );
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        int xpCurrent = data['xpCurrent'] ?? 0;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.star_rounded, size: 140, color: Colors.amber),
              const SizedBox(height: 40),
              Text(
                _isVietnamese ? "Điểm thưởng hiện tại" : "Current points",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 40),
              Text(
                "$xpCurrent XP",
                style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 50),
              Text(
                _isVietnamese ? "Cố lên bé yêu! Hoàn thành việc để nhận thật nhiều sao nhé! 🌟✨" : "Keep going! Complete tasks to earn lots of stars! 🌟✨",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}