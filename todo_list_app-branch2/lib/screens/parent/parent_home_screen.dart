import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _selectedIndex = 0;

  final List<String> _titles = [
    'Tổng quan',
    'Quản lý con cái',
    'Giao việc',
    'Quản lý phần thưởng',
    'Báo cáo thống kê',
    'Lịch & Nhắc hẹn',
    'Ghi chú',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _logLogin();
  }

  Future<void> _logLogin() async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('logins').add({
      'userUid': currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> _reauthenticateParent(BuildContext context) async {
    final passwordController = TextEditingController();

    if (currentUser == null) return false;

    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Xác nhận danh tính phụ huynh"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Nhập mật khẩu của bạn để tiếp tục:"),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Mật khẩu"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              try {
                final credential = EmailAuthProvider.credential(
                  email: currentUser!.email!,
                  password: passwordController.text,
                );
                await currentUser!.reauthenticateWithCredential(credential);
                Navigator.pop(context, true);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Mật khẩu sai!")),
                );
              }
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _assignTask(BuildContext context, String parentUid) async {
    final childrenSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('parentUid', isEqualTo: parentUid)
        .where('role', isEqualTo: 'child')
        .get();

    if (childrenSnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Chưa có con nào để giao việc. Hãy tạo tài khoản con trước!")),
      );
      return;
    }

    final rewardsSnapshot = await FirebaseFirestore.instance.collection('rewards').get();

    String? selectedChildUid;
    String? selectedRewardId;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? dueDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Giao việc mới"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Giao cho con"),
                  hint: const Text("Chọn con"),
                  items: childrenSnapshot.docs.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['displayName'] ?? 'Không tên'),
                    );
                  }).toList(),
                  onChanged: (value) => setStateDialog(() => selectedChildUid = value),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Tiêu đề việc (bắt buộc)"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Mô tả chi tiết"),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: "Chọn phần thưởng"),
                  hint: const Text("Không chọn (mặc định 10 XP)"),
                  items: rewardsSnapshot.docs.map((doc) {
                    var data = doc.data();
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text("${data['name']} (${data['points']} XP)"),
                    );
                  }).toList(),
                  onChanged: (value) => setStateDialog(() => selectedRewardId = value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text("Hạn chót: "),
                    TextButton(
                      onPressed: () async {
                        dueDate = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        setStateDialog(() {});
                      },
                      child: Text(
                        dueDate == null ? "Chưa chọn" : dueDate!.toLocal().toString().split(' ')[0],
                        style: TextStyle(color: dueDate == null ? Colors.grey : Colors.blue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                if (selectedChildUid == null || titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Vui lòng chọn con và nhập tiêu đề việc")),
                  );
                  return;
                }

                int rewardXP = 10;
                String? rewardId;
                if (selectedRewardId != null) {
                  final rewardDoc = await FirebaseFirestore.instance.collection('rewards').doc(selectedRewardId).get();
                  rewardXP = rewardDoc['points'] ?? 10;
                  rewardId = selectedRewardId;
                }

                try {
                  await FirebaseFirestore.instance.collection('tasks').add({
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'assignedTo': selectedChildUid,
                    'assignedBy': parentUid,
                    'rewardXP': rewardXP,
                    'rewardId': rewardId,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                    'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Giao việc thành công!")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                }
              },
              child: const Text("Giao việc"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createChildAccount(BuildContext context) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tạo tài khoản cho con"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên con (ví dụ: Bé Na)"),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email cho con"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Mật khẩu"),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String name = nameController.text.trim();
              String email = emailController.text.trim();
              String password = passwordController.text.trim();

              if (name.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Vui lòng nhập đầy đủ")));
                return;
              }

              try {
                final currentParent = FirebaseAuth.instance.currentUser;
                if (currentParent == null) return;

                UserCredential userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);

                await FirebaseFirestore.instance.collection('users').doc(userCred.user!.uid).set({
                  'displayName': name,
                  'email': email,
                  'role': 'child',
                  'parentUid': currentParent.uid,
                  'isLocked': false,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tạo thành công tài khoản cho $name")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
              }
            },
            child: const Text("Tạo"),
          ),
        ],
      ),
    );
  }

  Future<void> _editChild(BuildContext context, String childUid, String currentName, String currentEmail) async {
    final nameController = TextEditingController(text: currentName);
    final emailController = TextEditingController(text: currentEmail);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Sửa thông tin con"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên con"),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String newName = nameController.text.trim();
              String newEmail = emailController.text.trim();

              if (newName.isEmpty || newEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không được để trống")));
                return;
              }

              try {
                await FirebaseFirestore.instance.collection('users').doc(childUid).update({
                  'displayName': newName,
                  'email': newEmail,
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Cập nhật thành công cho $newName")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
              }
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChild(BuildContext context, String childUid, String childName) async {
    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Xóa tài khoản"),
            content: Text("Xóa vĩnh viễn tài khoản của $childName?\nKhông thể hoàn tác!"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Xóa", style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    bool reauth = await _reauthenticateParent(context);
    if (!reauth) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(childUid).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã xóa $childName thành công")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi xóa: $e")));
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Đăng xuất"),
        content: const Text("Bạn có chắc muốn đăng xuất không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Hủy")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Đăng xuất", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  Future<void> _addNote(String parentUid) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Thêm ghi chú mới"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: "Ví dụ: Mua sữa, cá, rau cải...",
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                FirebaseFirestore.instance.collection('notes').add({
                  'parentUid': parentUid,
                  'content': controller.text.trim(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
              }
              Navigator.pop(context);
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  void _deleteNote(String noteId) async {
    await FirebaseFirestore.instance.collection('notes').doc(noteId).delete();
  }

  void _showTaskDetailForParent(BuildContext context, String taskId, Map<String, dynamic> taskData, String childName) {
    String title = taskData['title'] ?? '';
    String desc = taskData['description'] ?? '';
    String status = taskData['status'] ?? 'pending';
    int reward = taskData['rewardXP'] ?? 0;
    Timestamp? dueTimestamp = taskData['dueDate'];
    String dueDate = dueTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(dueTimestamp.millisecondsSinceEpoch).toLocal().toString().split(' ')[0]
        : "Không có hạn";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Giao cho: $childName", style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(desc),
              const SizedBox(height: 12),
              Text("Hạn chót: $dueDate"),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.card_giftcard, color: Colors.green),
                  const SizedBox(width: 8),
                  Text("Thưởng: +$reward XP", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatusChip(status),

              if (status == 'submitted') ...[
                const SizedBox(height: 16),
                const Text("Minh chứng từ con:", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tasks')
                      .doc(taskId)
                      .collection('evidences')
                      .orderBy('uploadedAt', descending: true)
                      .snapshots(),
                  builder: (context, evidenceSnapshot) {
                    if (evidenceSnapshot.hasError) {
                      return const Text("Lỗi tải ảnh");
                    }
                    if (!evidenceSnapshot.hasData || evidenceSnapshot.data!.docs.isEmpty) {
                      return const Text("Không có ảnh minh chứng");
                    }

                    return SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: evidenceSnapshot.data!.docs.length,
                        itemBuilder: (context, idx) {
                          var evidenceDoc = evidenceSnapshot.data!.docs[idx];
                          String url = evidenceDoc['url'] ?? '';

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.error, color: Colors.red),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text("Duyệt"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _approveTask(context, taskId, taskData['assignedTo'], reward),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: const Text("Từ chối"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _rejectTask(context, taskId),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng")),
        ],
      ),
    );
  }

  Future<void> _approveTask(BuildContext context, String taskId, String childUid, int rewardXP) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({'status': 'approved'});

      final experienceRef = FirebaseFirestore.instance
          .collection('users')
          .doc(childUid)
          .collection('experience')
          .doc(childUid);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(experienceRef);

        if (!snapshot.exists) {
          transaction.set(experienceRef, {
            'level': 1,
            'xpCurrent': rewardXP,
            'xpRequired': 100,
          });
        } else {
          int currentXP = snapshot['xpCurrent'] ?? 0;
          int level = snapshot['level'] ?? 1;
          int xpRequired = snapshot['xpRequired'] ?? 100;

          int newXP = currentXP + rewardXP;
          while (newXP >= xpRequired) {
            newXP -= xpRequired;
            level++;
            xpRequired = level * 100;
          }

          transaction.update(experienceRef, {
            'xpCurrent': newXP,
            'level': level,
            'xpRequired': xpRequired,
          });
        }
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã duyệt! Con được cộng XP và có thể lên cấp!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi duyệt: $e")));
      }
    }
  }

  Future<void> _rejectTask(BuildContext context, String taskId) async {
    try {
      await FirebaseFirestore.instance.collection('tasks').doc(taskId).update({'status': 'pending'});
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã từ chối. Con cần làm lại minh chứng!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
      }
    }
  }

  Widget _buildRewardsManagement() {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _addOrEditReward(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('rewards').orderBy('points', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Lỗi tải phần thưởng"));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("Chưa có phần thưởng nào\nNhấn nút + để thêm", style: TextStyle(fontSize: 18, color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              var data = doc.data() as Map<String, dynamic>;
              String rewardId = doc.id;
              String name = data['name'] ?? 'Quà';
              String desc = data['description'] ?? '';
              int points = data['points'] ?? 10;

              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: const Icon(Icons.card_giftcard_rounded, size: 50, color: Colors.orange),
                  title: Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  subtitle: Text("$points XP\n$desc"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _addOrEditReward(rewardId: rewardId, initialData: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteReward(rewardId),
                      ),
                    ],
                  ),
                  onTap: () => _showRewardDetailForParent(name, desc, points),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _addOrEditReward({String? rewardId, Map<String, dynamic>? initialData}) async {
    final nameController = TextEditingController(text: initialData?['name'] ?? '');
    final descController = TextEditingController(text: initialData?['description'] ?? '');
    final pointsController = TextEditingController(text: initialData?['points']?.toString() ?? '10');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rewardId == null ? "Thêm phần thưởng mới" : "Chỉnh sửa phần thưởng"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Tên phần thưởng (bắt buộc)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Mô tả chi tiết"),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pointsController,
                decoration: const InputDecoration(labelText: "Điểm cần đổi (10-100)"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Hủy")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String name = nameController.text.trim();
              String desc = descController.text.trim();
              int? points = int.tryParse(pointsController.text);

              if (name.isEmpty || points == null || points < 10 || points > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Kiểm tra lại tên và điểm (10-100)")),
                );
                return;
              }

              if (rewardId == null) {
                await FirebaseFirestore.instance.collection('rewards').add({
                  'name': name,
                  'description': desc,
                  'points': points,
                });
              } else {
                await FirebaseFirestore.instance.collection('rewards').doc(rewardId).update({
                  'name': name,
                  'description': desc,
                  'points': points,
                });
              }

              Navigator.pop(context);
              String message = rewardId == null ? "Thêm thành công!" : "Cập nhật thành công!";
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(message)),
              );
            },
            child: Text(rewardId == null ? "Thêm" : "Lưu"),
          ),
        ],
      ),
    );
  }

  void _showRewardDetailForParent(String name, String desc, int points) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
        content: Text(desc, style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Đóng")),
        ],
      ),
    );
  }

  Future<void> _deleteReward(String rewardId) async {
    await FirebaseFirestore.instance.collection('rewards').doc(rewardId).delete();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa phần thưởng")));
  }

  Widget _buildOverview() {
    final String parentUid = currentUser!.uid;

    DateTime weekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
    Timestamp weekStartTimestamp = Timestamp.fromDate(weekStart);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tổng quan tuần này", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 20),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('parentUid', isEqualTo: parentUid)
                .where('role', isEqualTo: 'child')
                .get(),
            builder: (context, childrenSnapshot) {
              int childCount = childrenSnapshot.hasData ? childrenSnapshot.data!.docs.length : 0;
              return _statCard("Số con", childCount.toString(), Icons.child_care, Colors.blue);
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('tasks').where('assignedBy', isEqualTo: parentUid).snapshots(),
            builder: (context, taskSnapshot) {
              if (!taskSnapshot.hasData) return const Center(child: CircularProgressIndicator());

              int totalTasks = taskSnapshot.data!.docs.length;
              int completedTasks = taskSnapshot.data!.docs.where((doc) => doc['status'] == 'approved').length;
              double completionRate = totalTasks > 0 ? (completedTasks / totalTasks * 100) : 0;

              return Column(
                children: [
                  const SizedBox(height: 12),
                  _statCard("Việc đã giao", totalTasks.toString(), Icons.assignment, Colors.green),
                  const SizedBox(height: 12),
                  _statCard("Hoàn thành", completedTasks.toString(), Icons.check_circle, Colors.orange),
                  const SizedBox(height: 12),
                  _statCard("Tỷ lệ hoàn thành", "${completionRate.toStringAsFixed(0)}%", Icons.trending_up, Colors.purple),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('logins')
                .where('timestamp', isGreaterThanOrEqualTo: weekStartTimestamp)
                .snapshots(),
            builder: (context, loginSnapshot) {
              return FutureBuilder<List<String>>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .where('parentUid', isEqualTo: parentUid)
                    .where('role', isEqualTo: 'child')
                    .get()
                    .then((snap) => snap.docs.map((doc) => doc.id).toList()),
                builder: (context, childUidsSnapshot) {
                  List<String> childUids = childUidsSnapshot.data ?? [];

                  int loginCount = 0;
                  if (loginSnapshot.hasData) {
                    for (var doc in loginSnapshot.data!.docs) {
                      String uid = doc['userUid'];
                      if (uid == parentUid || childUids.contains(uid)) {
                        loginCount++;
                      }
                    }
                  }

                  return _statCard("Lượt truy cập tuần này", loginCount.toString(), Icons.login, Colors.purple);
                },
              );
            },
          ),
          const SizedBox(height: 30),
          const Text("Hoạt động gần đây", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('assignedBy', isEqualTo: parentUid)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, recentSnapshot) {
              if (!recentSnapshot.hasData || recentSnapshot.data!.docs.isEmpty) {
                return const Text("Chưa có hoạt động nào", style: TextStyle(fontSize: 16));
              }

              return Column(
                children: recentSnapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String title = data['title'] ?? 'Việc không tên';
                  String status = data['status'] ?? 'pending';
                  String statusText = status == 'approved' ? 'Hoàn thành' : status == 'submitted' ? 'Đã nộp' : 'Chưa làm';
                  return ListTile(
                    leading: const Icon(Icons.circle, size: 10, color: Colors.orange),
                    title: Text(title),
                    subtitle: Text("Trạng thái: $statusText"),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(icon, size: 50, color: color),
        title: Text(title, style: const TextStyle(fontSize: 18)),
        trailing: Text(value, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }

  Widget _buildAssignTaskScreen(String parentUid) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            "Danh sách việc đã giao",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('assignedBy', isEqualTo: parentUid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Lỗi tải danh sách việc", style: TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_add, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "Chưa giao việc nào\nNhấn nút + để bắt đầu",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  String taskId = doc.id;
                  String title = data['title'] ?? 'Không tiêu đề';
                  String status = data['status'] ?? 'pending';
                  int reward = data['rewardXP'] ?? 0;
                  Timestamp? dueTimestamp = data['dueDate'];
                  String dueDate = dueTimestamp != null
                      ? DateTime.fromMillisecondsSinceEpoch(dueTimestamp.millisecondsSinceEpoch)
                          .toLocal()
                          .toString()
                          .split(' ')[0]
                      : "Không có hạn";

                  return FutureBuilder<DocumentSnapshot>(
                    future: data['assignedTo'] != null
                        ? FirebaseFirestore.instance.collection('users').doc(data['assignedTo']).get()
                        : null,
                    builder: (context, childSnapshot) {
                      String childName = "Không rõ";
                      if (childSnapshot.hasData && childSnapshot.data!.exists) {
                        childName = childSnapshot.data!['displayName'] ?? 'Không tên';
                      }

                      return Card(
                        elevation: 6,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text("Giao cho: $childName", style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text("Hạn: $dueDate"),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.card_giftcard, color: Colors.green, size: 20),
                                  const SizedBox(width: 4),
                                  Text("+ $reward XP", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 16),
                                  _buildStatusChip(status),
                                ],
                              ),
                            ],
                          ),
                          onTap: () => _showTaskDetailForParent(context, taskId, data, childName),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String text;
    switch (status) {
      case 'pending':
        color = Colors.orange;
        text = "Chưa làm";
        break;
      case 'submitted':
        color = Colors.blue;
        text = "Đã nộp";
        break;
      case 'approved':
        color = Colors.green;
        text = "Hoàn thành";
        break;
      case 'rejected':
        color = Colors.red;
        text = "Từ chối";
        break;
      default:
        color = Colors.grey;
        text = status;
    }
    return Chip(
      label: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
    );
  }

  Widget _buildNotesScreen(String parentUid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Thêm ghi chú mới"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(50)),
            onPressed: () => _addNote(parentUid),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notes')
                .where('parentUid', isEqualTo: parentUid)
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Lỗi tải ghi chú"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("Chưa có ghi chú nào\nNhấn nút + để thêm nhé!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  String noteId = doc.id;
                  String content = doc['content'] ?? '';

                  return Dismissible(
                    key: Key(noteId),
                    direction: DismissDirection.endToStart,
                    background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
                    onDismissed: (_) => _deleteNote(noteId),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.note, color: Colors.orange),
                        title: Text(content, style: const TextStyle(fontSize: 16)),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteNote(noteId)),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildChildrenManagement(String parentUid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text("Tạo tài khoản mới cho con"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size.fromHeight(50)),
            onPressed: () => _createChildAccount(context),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .where('parentUid', isEqualTo: parentUid)
                .where('role', isEqualTo: 'child')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Lỗi kết nối"));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("Chưa có con nào\nTạo bé đầu tiên đi anh!", style: TextStyle(fontSize: 16, color: Colors.grey)));
              }

              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  String childUid = doc.id;
                  String name = doc['displayName'] ?? 'Không tên';
                  String email = doc['email'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: ListTile(
                      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.child_care, color: Colors.white)),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(email),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editChild(context, childUid, name, email)),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteChild(context, childUid, name)),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // ================== BÁO CÁO THỐNG KÊ ĐÃ SỬA HOÀN CHỈNH ==================
  Widget _buildStatisticsReport(String parentUid) {
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    Timestamp weekStartTimestamp = Timestamp.fromDate(weekStart);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Báo cáo thống kê tuần này",
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 24),

          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('parentUid', isEqualTo: parentUid)
                .where('role', isEqualTo: 'child')
                .get(),
            builder: (context, childrenSnapshot) {
              if (!childrenSnapshot.hasData || childrenSnapshot.data!.docs.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        "Chưa có bé nào để thống kê\nTạo tài khoản con trước nhé! 👶",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              }

              final List<String> childUids = childrenSnapshot.data!.docs.map((doc) => doc.id).toList();
              final List<String> childNames = childrenSnapshot.data!.docs
                  .map((doc) => (doc.data() as Map<String, dynamic>)['displayName'] as String? ?? 'Không tên')
                  .toList();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tasks')
                    .where('assignedBy', isEqualTo: parentUid)
                    .snapshots(),
                builder: (context, tasksSnapshot) {
                  if (!tasksSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  List<double> assignedSpots = List.filled(childUids.length, 0.0);
                  List<double> completedSpots = List.filled(childUids.length, 0.0);

                  for (var doc in tasksSnapshot.data!.docs) {
                    var data = doc.data() as Map<String, dynamic>;
                    String? assignedTo = data['assignedTo'] as String?;
                    String status = data['status'] as String? ?? 'pending';

                    int index = childUids.indexOf(assignedTo ?? '');
                    if (index != -1) {
                      assignedSpots[index]++;
                      if (status == 'approved') {
                        completedSpots[index]++;
                      }
                    }
                  }

                  double maxAssigned = assignedSpots.isEmpty ? 1 : assignedSpots.reduce((a, b) => a > b ? a : b);
                  double maxY = (maxAssigned + 2).ceilToDouble();

                  return Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Việc được giao & hoàn thành theo bé",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 340,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: maxY,
                                barTouchData: BarTouchData(enabled: true),
                                titlesData: FlTitlesData(
                                  show: true,
                                  leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 40,
                                      getTitlesWidget: (value, meta) {
                                        return Text(
                                          value.toInt().toString(),
                                          style: const TextStyle(fontSize: 12),
                                        );
                                      },
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 70, // Tăng để tên dài không bị cắt
                                      getTitlesWidget: (value, meta) {
                                        int index = value.toInt();
                                        if (index < 0 || index >= childNames.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return SideTitleWidget(
                                          meta: meta, // Đây là tham số đúng ở phiên bản 0.70+
                                          child: Padding(
                                            padding: const EdgeInsets.only(top: 8),
                                            child: Text(
                                              childNames[index],
                                              style: const TextStyle(fontSize: 11),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: FlGridData(show: true),
                                borderData: FlBorderData(show: false),
                                barGroups: List.generate(childUids.length, (i) {
                                  return BarChartGroupData(
                                    x: i,
                                    barRods: [
                                      BarChartRodData(
                                        toY: assignedSpots[i],
                                        color: Colors.orange[400],
                                        width: 18,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                      BarChartRodData(
                                        toY: completedSpots[i],
                                        color: Colors.green[600],
                                        width: 18,
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                      ),
                                    ],
                                    barsSpace: 10,
                                  );
                                }),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legendItem(Colors.orange[400]!, "Đã giao"),
                              const SizedBox(width: 30),
                              _legendItem(Colors.green[600]!, "Hoàn thành"),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 30),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('logins')
                .where('timestamp', isGreaterThanOrEqualTo: weekStartTimestamp)
                .snapshots(),
            builder: (context, loginSnapshot) {
              int totalLogins = loginSnapshot.hasData ? loginSnapshot.data!.docs.length : 0;

              return Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Text("Tổng lượt truy cập tuần này", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text(
                        totalLogins.toString(),
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                      const Text("Cả bố mẹ và các bé", style: TextStyle(color: Colors.grey, fontSize: 16)),
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

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text("Lỗi đăng nhập")));

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.orange),
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
                builder: (context, snapshot) {
                  final name = snapshot.data?['displayName'] ?? "Phụ huynh";
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 40, color: Colors.orange),
                      ),
                      const SizedBox(height: 12),
                      const Text("Xin chào,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Flexible(
                        child: Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ..._titles.asMap().entries.map((entry) {
              int idx = entry.key;
              String title = entry.value;
              IconData icon = [
                Icons.dashboard,
                Icons.child_care,
                Icons.assignment,
                Icons.card_giftcard_rounded,
                Icons.bar_chart,
                Icons.calendar_month,
                Icons.note_alt,
              ][idx];
              return ListTile(
                leading: Icon(icon),
                title: Text(title),
                selected: _selectedIndex == idx,
                selectedTileColor: Colors.orange[100],
                onTap: () {
                  if (idx == 4) {
                    _reauthenticateParent(context).then((ok) {
                      if (ok) {
                        setState(() => _selectedIndex = idx);
                        Navigator.pop(context);
                      }
                    });
                  } else {
                    setState(() => _selectedIndex = idx);
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ],
        ),
      ),
      body: _buildBody(currentUser!.uid),
      floatingActionButton: _selectedIndex == 2
          ? FloatingActionButton(
              backgroundColor: Colors.orange,
              child: const Icon(Icons.add_task, color: Colors.white),
              onPressed: () => _assignTask(context, currentUser!.uid),
            )
          : _selectedIndex == 3
              ? FloatingActionButton(
                  backgroundColor: Colors.orange,
                  child: const Icon(Icons.add, color: Colors.white),
                  onPressed: () => _addOrEditReward(),
                )
              : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildBody(String parentUid) {
    switch (_selectedIndex) {
      case 0:
        return _buildOverview();
      case 1:
        return _buildChildrenManagement(parentUid);
      case 2:
        return _buildAssignTaskScreen(parentUid);
      case 3:
        return _buildRewardsManagement();
      case 4:
        return _buildStatisticsReport(parentUid);
      case 5:
        return const Center(child: Text("Quản lý lịch và nhắc hẹn\n(Sắp có)", style: TextStyle(fontSize: 18)));
      case 6:
        return _buildNotesScreen(parentUid);
      default:
        return const SizedBox();
    }
  }
}