import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    'Báo cáo thống kê',
    'Lịch & Nhắc hẹn',
    'Ghi chú',
  ];

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // Xác nhận mật khẩu phụ huynh
  Future<bool> _reauthenticateParent(BuildContext context) async {
    final passwordController = TextEditingController();
    final currentUser = FirebaseAuth.instance.currentUser;

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
                  email: currentUser.email!,
                  password: passwordController.text,
                );
                await currentUser.reauthenticateWithCredential(credential);
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

  // GIAO VIỆC MỚI
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

    String? selectedChildUid;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final xpController = TextEditingController(text: "10");
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
                  onChanged: (value) {
                    setStateDialog(() => selectedChildUid = value);
                  },
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
                TextField(
                  controller: xpController,
                  decoration: const InputDecoration(labelText: "Thưởng XP"),
                  keyboardType: TextInputType.number,
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

                try {
                  await FirebaseFirestore.instance.collection('tasks').add({
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'assignedTo': selectedChildUid,
                    'assignedBy': parentUid,
                    'rewardXP': int.tryParse(xpController.text) ?? 10,
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

  // Tạo tài khoản con
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

  // Sửa thông tin con
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

  // Xóa tài khoản con
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

  // Đăng xuất
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

  // Ghi chú
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

  // Chi tiết task + duyệt minh chứng
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
                const Text("Minh chứng từ con:", style: TextStyle(fontWeight: FontWeight.bold)),
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

  // Duyệt task - cộng XP + lên level
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

  // Từ chối task
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
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text("Tổng quan"),
              selected: _selectedIndex == 0,
              selectedTileColor: Colors.orange[100],
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.child_care),
              title: const Text("Quản lý con cái"),
              selected: _selectedIndex == 1,
              selectedTileColor: Colors.orange[100],
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.assignment),
              title: const Text("Giao việc"),
              selected: _selectedIndex == 2,
              selectedTileColor: Colors.orange[100],
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.bar_chart),
              title: const Text("Báo cáo thống kê"),
              selected: _selectedIndex == 3,
              selectedTileColor: Colors.orange[100],
              onTap: () async {
                final ok = await _reauthenticateParent(context);
                if (ok) {
                  setState(() => _selectedIndex = 3);
                  Navigator.pop(context);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text("Lịch & Nhắc hẹn"),
              selected: _selectedIndex == 4,
              selectedTileColor: Colors.orange[100],
              onTap: () {
                setState(() => _selectedIndex = 4);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.note_alt),
              title: const Text("Ghi chú"),
              selected: _selectedIndex == 5,
              selectedTileColor: Colors.orange[100],
              onTap: () {
                setState(() => _selectedIndex = 5);
                Navigator.pop(context);
              },
            ),
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
        return const Center(child: Text("Báo cáo thống kê chi tiết\n(Đã xác thực mật khẩu)", style: TextStyle(fontSize: 18)));
      case 4:
        return const Center(child: Text("Quản lý lịch và nhắc hẹn\n(Sắp có)", style: TextStyle(fontSize: 18)));
      case 5:
        return _buildNotesScreen(parentUid);
      default:
        return const SizedBox();
    }
  }

  // Danh sách việc đã giao - SIÊU MƯỢT
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

  // Tổng quan
  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tổng quan tuần này", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.login, color: Colors.orange, size: 40),
              title: const Text("Lượt truy cập tuần này", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: const Text("7 lần", style: TextStyle(fontSize: 24, color: Colors.orange)),
              trailing: const Icon(Icons.trending_up, color: Colors.green),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.spaceEvenly,
            children: [
              _statCard("Số con", "3", Icons.child_care, Colors.blue),
              _statCard("Việc giao", "24", Icons.assignment, Colors.green),
              _statCard("Hoàn thành", "18", Icons.check_circle, Colors.orange),
              _statCard("Tỷ lệ", "75%", Icons.trending_up, Colors.purple),
            ],
          ),
          const SizedBox(height: 30),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hoạt động gần đây", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text("• Bé Na đã nộp minh chứng dọn phòng"),
                  Text("• Bé Kun hoàn thành học bài Toán"),
                  Text("• Bé Bi đang chờ duyệt bài tập Tiếng Anh"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 160,
      child: Card(
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 10),
              Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
              Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700]), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  // Ghi chú
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

  // Quản lý con cái
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
}