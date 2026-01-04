import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _loadUserRoleAndName();
    _logLogin(); // Ghi lượt truy cập
  }

  Future<void> _logLogin() async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('logins').add({
      'userUid': currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
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
        displayName = doc['displayName'] ?? currentUser!.email ?? "Bé yêu";
        email = doc['email'] ?? currentUser!.email ?? "";
      });
    } else {
      setState(() {
        role = 'child';
        displayName = currentUser!.email ?? "Bé yêu";
        email = currentUser!.email ?? "";
      });
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
    final List<String> titles = ['Tổng quan', 'Việc được giao', 'Lịch cá nhân', 'Điểm thưởng'];

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
      body: _buildChildBody(),
    );
  }

  Drawer _buildDrawer(List<String> titles) {
    return Drawer(
      child: Column(
        children: [
          Container(
            height: 240,
            color: Colors.white,
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
                    backgroundColor: Colors.white,
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
                for (int i = 0; i < titles.length; i++)
                  ListTile(
                    leading: Icon(
                      i == 0
                          ? Icons.dashboard_rounded
                          : i == 1
                              ? Icons.task_alt_rounded
                              : i == 2
                                  ? Icons.calendar_month_rounded
                                  : Icons.star_rounded,
                      color: i == 0 || i == 1 ? Colors.orange : i == 2 ? Colors.green : Colors.amber,
                      size: 28,
                    ),
                    title: Text(titles[i], style: const TextStyle(fontSize: 18)),
                    selected: _selectedIndex == i,
                    selectedTileColor: i == 0 || i == 1 ? Colors.orange[50] : i == 2 ? Colors.green[50] : Colors.amber[50],
                    onTap: () {
                      setState(() => _selectedIndex = i);
                      Navigator.pop(context);
                    },
                  ),
                const Divider(height: 40, thickness: 1, indent: 20, endIndent: 20),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Colors.red, size: 28),
                  title: const Text("Đăng xuất", style: TextStyle(fontSize: 18, color: Colors.red)),
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushReplacementNamed(context, '/login');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildBody() {
    switch (_selectedIndex) {
      case 0:
        return _buildChildOverview();
      case 1:
        return _buildTasksTab();
      case 2:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event_note_rounded, size: 100, color: Colors.green),
              SizedBox(height: 20),
              Text("Lịch cá nhân\n(Sắp có nha bé yêu! 🗓️)", 
                   textAlign: TextAlign.center, 
                   style: TextStyle(fontSize: 20, color: Colors.grey)),
            ],
          ),
        );
      case 3:
        return _buildPointsTab();
      default:
        return const SizedBox();
    }
  }

  // DASHBOARD ĐỘNG CHO BÉ - ĐÃ FIX LỖI xpRequired
  Widget _buildChildOverview() {
    final String uid = currentUser!.uid;

    DateTime weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    Timestamp weekStartTimestamp = Timestamp.fromDate(weekStart);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tổng quan tuần này bé ơi! 🌟", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').where('assignedTo', isEqualTo: uid).snapshots(),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              int totalTasks = taskSnapshot.data!.docs.length;
              int completedTasks = taskSnapshot.data!.docs.where((doc) => doc['status'] == 'approved').length;
              double completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

              return Column(
                children: [
                  _childStatCard("Việc được giao", totalTasks.toString(), Icons.task_alt_rounded, Colors.orange),
                  const SizedBox(height: 12),
                  _childStatCard("Đã hoàn thành", completedTasks.toString(), Icons.celebration, Colors.green),
                  const SizedBox(height: 12),
                  _childStatCard("Tỷ lệ hoàn thành", "${completionRate.toStringAsFixed(0)}%", Icons.trending_up_rounded, Colors.blue),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('logins')
                .where('userUid', isEqualTo: uid)
                .where('timestamp', isGreaterThanOrEqualTo: weekStartTimestamp)
                .snapshots(),
            builder: (context, loginSnapshot) {
              int loginCount = loginSnapshot.hasData ? loginSnapshot.data!.docs.length : 0;
              return _childStatCard("Lượt truy cập tuần này", loginCount.toString(), Icons.login_rounded, Colors.purple);
            },
          ),
          const SizedBox(height: 30),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).collection('experience').doc(uid).snapshots(),
            builder: (context, expSnapshot) {
              if (!expSnapshot.hasData || !expSnapshot.data!.exists) {
                return Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Chưa có điểm thưởng nào! Làm việc tốt để nhận sao nhé bé 🌟", style: TextStyle(fontSize: 18)),
                  ),
                );
              }
              var data = expSnapshot.data!.data() as Map<String, dynamic>;
              int level = data['level'] ?? 1;
              int xpCurrent = data['xpCurrent'] ?? 0;
              int xpRequired = data['xpRequired'] ?? 100; // FIX: Đúng tên biến

              return Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Text("Điểm thưởng hiện tại", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 16),
                      Text("Cấp độ $level", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: xpCurrent / xpRequired,
                        minHeight: 20,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      const SizedBox(height: 12),
                      Text("$xpCurrent / $xpRequired XP", style: const TextStyle(fontSize: 24)),
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

  // Các phần còn lại giữ nguyên như file trước (TasksTab, PointsTab, button "Bằng chứng", upload, markAsDone...)
  // (đã đầy đủ trong file này)

  Widget _buildTasksTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedTo', isEqualTo: currentUser!.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Ôi không! Có lỗi rồi 😢"));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_satisfied_alt, size: 100, color: Colors.orange),
                SizedBox(height: 20),
                Text(
                  "Chưa có việc nào hết!\nHỏi bố mẹ xem có việc gì làm không nhé! 😊",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, color: Colors.grey),
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
            String title = data['title'] ?? 'Việc vui';
            String desc = data['description'] ?? '';
            String status = data['status'] ?? 'pending';
            int reward = data['rewardXP'] ?? 0;
            Timestamp? dueTimestamp = data['dueDate'];
            String dueDate = dueTimestamp != null
                ? "Hạn: ${dueTimestamp.toDate().toLocal().day}/${dueTimestamp.toDate().toLocal().month}"
                : "Không gấp lắm đâu!";

            Color statusColor = Colors.orange;
            String statusText = "Chưa làm xong";
            IconData statusIcon = Icons.hourglass_bottom;

            switch (status) {
              case 'submitted':
                statusColor = Colors.blue;
                statusText = "Đã báo xong!";
                statusIcon = Icons.check_circle_outline;
                break;
              case 'approved':
                statusColor = Colors.green;
                statusText = "Hoàn thành rồi! 🎉";
                statusIcon = Icons.celebration;
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusText = "Làm lại nhé!";
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
                        Icon(Icons.card_giftcard_rounded, color: Colors.orange, size: 28),
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
                                label: const Text("Làm xong rồi!", style: TextStyle(fontSize: 15)),
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
          const SnackBar(content: Text("Bé báo xong rồi! Chờ bố mẹ duyệt nhé 🌟")),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Ôi không, lỗi rồi: $e")),
        );
      }
    }
  }

  void _showTaskDetail(String taskId, String title, String desc, String status, int reward) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(desc, style: const TextStyle(fontSize: 17)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.card_giftcard_rounded, color: Colors.orange, size: 30),
                  const SizedBox(width: 10),
                  Text("Thưởng: +$reward XP", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
              const SizedBox(height: 20),
              _buildStatusText(status),
              const SizedBox(height: 24),
              if (status == 'pending' || status == 'rejected') ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                    label: const Text("Làm xong rồi!", style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _markAsDone(taskId);
                    },
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt_rounded, size: 22),
                    label: const Text("Nộp ảnh minh chứng", style: TextStyle(fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _uploadEvidence(taskId);
                    },
                  ),
                ),
              ],
              if (status == 'submitted')
                const Text("Đã báo xong rồi! Chờ bố mẹ duyệt nhé 🥰", style: TextStyle(fontSize: 17, color: Colors.blue)),
              if (status == 'approved')
                const Text("Tuyệt vời! Bé giỏi quá! 🌟🎉", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
              if (status == 'rejected')
                const Text("Ối, chưa đạt yêu cầu! Làm lại nhé bé yêu 💪", style: TextStyle(fontSize: 17, color: Colors.red)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Đóng", style: TextStyle(fontSize: 18, color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusText(String status) {
    String text;
    Color color = Colors.orange;
    IconData icon = Icons.hourglass_bottom;

    switch (status) {
      case 'pending':
        text = "Chưa làm xong";
        color = Colors.orange;
        icon = Icons.hourglass_bottom;
        break;
      case 'submitted':
        text = "Đã báo xong, chờ duyệt";
        color = Colors.blue;
        icon = Icons.schedule;
        break;
      case 'approved':
        text = "Hoàn thành rồi! 🎉";
        color = Colors.green;
        icon = Icons.celebration;
        break;
      case 'rejected':
        text = "Làm lại nhé!";
        color = Colors.red;
        icon = Icons.refresh;
        break;
      default:
        text = status;
        color = Colors.grey;
        icon = Icons.info;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Future<void> _uploadEvidence(String taskId) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bé chưa chọn ảnh nè 😅")));
      return;
    }

    String path = pickedFile.path.toLowerCase();
    if (!path.endsWith('.jpg') && !path.endsWith('.jpeg') && !path.endsWith('.png')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chỉ được chọn ảnh .jpg hoặc .png thôi nha bé! 📸")),
      );
      return;
    }

    File file = File(pickedFile.path);
    int fileSizeInBytes = await file.length();
    if (fileSizeInBytes > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ảnh to quá rồi! Chọn ảnh nhỏ hơn 5MB nhé bé ❤️")),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang gửi ảnh cho bố mẹ xem... 📤")));

    try {
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference ref = FirebaseStorage.instance.ref().child('evidences/$taskId/$fileName');
      await ref.putFile(file);
      String url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).collection('evidences').add({
        'url': url,
        'uploadedBy': currentUser!.uid,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({'status': 'submitted'});

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Gửi ảnh thành công rồi! Bé giỏi quá! 🌟")));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Ôi không, lỗi rồi: $e")));
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
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_border_rounded, size: 120, color: Colors.orange),
                SizedBox(height: 24),
                Text("Chưa có điểm nào hết!\nLàm việc tốt để nhận sao nhé bé! 🌟", 
                     textAlign: TextAlign.center, 
                     style: TextStyle(fontSize: 20, color: Colors.grey)),
              ],
            ),
          );
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        int level = data['level'] ?? 1;
        int xpCurrent = data['xpCurrent'] ?? 0;
        int xpRequired = data['xpRequired'] ?? 100;

        return Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.star_rounded, size: 140, color: Colors.amber[300]),
                  Icon(Icons.star_rounded, size: 100, color: Colors.amber),
                  Icon(Icons.star_rounded, size: 60, color: Colors.white),
                ],
              ),
              const SizedBox(height: 30),
              Text("Cấp độ $level", style: const TextStyle(fontSize: 44, fontWeight: FontWeight.bold, color: Colors.orange)),
              const SizedBox(height: 40),
              LinearProgressIndicator(
                value: xpCurrent / xpRequired,
                minHeight: 30,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(Colors.orange),
                borderRadius: BorderRadius.circular(15),
              ),
              const SizedBox(height: 24),
              Text(
                "$xpCurrent / $xpRequired XP",
                style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 50),
              const Text(
                "Cố lên bé yêu! Hoàn thành việc để nhận thật nhiều sao nhé! 🌟✨",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}