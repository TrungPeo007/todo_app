import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:async';

class ParentHomeScreen extends StatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  State<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends State<ParentHomeScreen> {
  int _selectedIndex = 0;
  final List<String> _titlesVi = [
    'Tổng quan',
    'Quản lý con cái',
    'Giao việc',
    'Quản lý phần thưởng',
    'Báo cáo thống kê',
    'Lịch & Nhắc hẹn',
    'Ghi chú',
  ];
  final List<String> _titlesEn = [
    'Overview',
    'Manage Children',
    'Assign Tasks',
    'Manage Rewards',
    'Statistics Report',
    'Calendar & Reminders',
    'Notes',
  ];
  List<String> get _titles => _isVietnamese ? _titlesVi : _titlesEn;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isVietnamese = true;
  late StreamSubscription<QuerySnapshot> _taskSubscription;

  @override
  void initState() {
    super.initState();
    _logLogin();
    _selectedDay = _focusedDay;
    _listenForSubmittedTasks();
  }

  @override
  void dispose() {
    _taskSubscription.cancel();
    super.dispose();
  }

  Future<void> _logLogin() async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance.collection('logins').add({
      'userUid': currentUser!.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _listenForSubmittedTasks() {
    _taskSubscription = FirebaseFirestore.instance
        .collection('tasks')
        .where('assignedBy', isEqualTo: currentUser!.uid)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          var data = change.doc.data() as Map<String, dynamic>?;
          if (data != null && data['status'] == 'submitted') {
            var oldData = change.oldIndex != -1
                ? snapshot.docs[change.oldIndex].data()
                : null;
            if (oldData is Map<String, dynamic> && oldData['status'] != 'submitted') {
              String title = data['title'] ?? 'việc';
              bool isAll = data['isAll'] == true;
              String assignedTo = data['assignedTo'];
              if (isAll) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Tất cả các bé đã nộp việc '$title', mời bố mẹ kiểm tra!"),
                    backgroundColor: Colors.blue,
                  ),
                );
              } else {
                FirebaseFirestore.instance.collection('users').doc(assignedTo).get().then((doc) {
                  if (doc.exists) {
                    String childName = doc['displayName'] ?? 'Bé';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$childName đã nộp việc '$title', mời bố mẹ kiểm tra!"),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                });
              }
            }
          }
        }
      }
    });
  }

  Future<bool> _reauthenticateParent(BuildContext context) async {
    final passwordController = TextEditingController();
    if (currentUser == null) return false;
    bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(_isVietnamese ? "Xác nhận danh tính phụ huynh" : "Parent Authentication"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isVietnamese ? "Nhập mật khẩu của bạn để tiếp tục:" : "Enter your password to continue:"),
            const SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: _isVietnamese ? "Mật khẩu" : "Password"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
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
                  SnackBar(content: Text(_isVietnamese ? "Mật khẩu sai!" : "Wrong password!")),
                );
              }
            },
            child: Text(_isVietnamese ? "Xác nhận" : "Confirm"),
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
        SnackBar(content: Text(_isVietnamese ? "Chưa có con nào để giao việc" : "No children to assign tasks")),
      );
      return;
    }
    final rewardsSnapshot = await FirebaseFirestore.instance.collection('rewards').get();
    List<String> selectedChildUids = [];
    bool assignToAll = false;
    String? selectedRewardId;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? dueDate;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text(_isVietnamese ? "Giao việc mới" : "New Task Assignment"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(_isVietnamese ? "Giao cho tất cả các bé" : "Assign to all children"),
                  value: assignToAll,
                  onChanged: (value) {
                    setStateDialog(() {
                      assignToAll = value;
                      if (value) selectedChildUids.clear();
                    });
                  },
                ),
                if (!assignToAll) ...[
                  const SizedBox(height: 10),
                  Text(_isVietnamese ? "Chọn bé cụ thể:" : "Select specific child:"),
                  ...childrenSnapshot.docs.map((doc) {
                    return CheckboxListTile(
                      title: Text(doc['displayName'] ?? 'Không tên'),
                      value: selectedChildUids.contains(doc.id),
                      onChanged: (bool? value) {
                        setStateDialog(() {
                          if (value == true) {
                            selectedChildUids.add(doc.id);
                          } else {
                            selectedChildUids.remove(doc.id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ],
                const SizedBox(height: 15),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(labelText: _isVietnamese ? "Tiêu đề việc (bắt buộc)" : "Task title (required)"),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  decoration: InputDecoration(labelText: _isVietnamese ? "Mô tả chi tiết" : "Detailed description"),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: _isVietnamese ? "Chọn phần thưởng" : "Select reward"),
                  hint: Text(_isVietnamese ? "Không chọn (mặc định 10 XP)" : "No selection (default 10 XP)"),
                  items: rewardsSnapshot.docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
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
                    Text(_isVietnamese ? "Hạn chót:" : "Due date:"),
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
                        dueDate == null ? (_isVietnamese ? "Chưa chọn" : "Not selected") : dueDate!.toLocal().toString().split(' ')[0],
                        style: TextStyle(color: dueDate == null ? Colors.grey : Colors.blue),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () async {
                bool isAll = assignToAll || selectedChildUids.length == childrenSnapshot.docs.length;
                List<String> targets = isAll ? childrenSnapshot.docs.map((e) => e.id).toList() : selectedChildUids;
                if (targets.isEmpty || titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isVietnamese ? "Vui lòng chọn ít nhất 1 bé và nhập tiêu đề" : "Please select at least one child and enter title")),
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
                WriteBatch batch = FirebaseFirestore.instance.batch();
                for (String childUid in targets) {
                  DocumentReference taskRef = FirebaseFirestore.instance.collection('tasks').doc();
                  batch.set(taskRef, {
                    'title': titleController.text.trim(),
                    'description': descController.text.trim(),
                    'assignedTo': childUid,
                    'assignedBy': parentUid,
                    'rewardXP': rewardXP,
                    'rewardId': rewardId,
                    'status': 'pending',
                    'isAll': isAll,
                    'createdAt': FieldValue.serverTimestamp(),
                    'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
                  });
                }
                try {
                  await batch.commit();
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_isVietnamese ? "Giao việc thành công!" : "Task assigned successfully!")),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
                }
              },
              child: Text(_isVietnamese ? "Giao việc" : "Assign Task"),
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
        title: Text(_isVietnamese ? "Tạo tài khoản cho con" : "Create child account"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Tên con (ví dụ: Bé Na)" : "Child name (e.g: Baby Na)"),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Email cho con" : "Child email"),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Mật khẩu" : "Password"),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String name = nameController.text.trim();
              String email = emailController.text.trim();
              String password = passwordController.text.trim();
              if (name.isEmpty || email.isEmpty || password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Vui lòng nhập đầy đủ" : "Please fill all fields")));
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
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Tạo thành công tài khoản cho $name" : "Successfully created account for $name")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
              }
            },
            child: Text(_isVietnamese ? "Tạo" : "Create"),
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
        title: Text(_isVietnamese ? "Sửa thông tin con" : "Edit child info"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Tên con" : "Child name"),
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                decoration: InputDecoration(labelText: "Email"),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String newName = nameController.text.trim();
              String newEmail = emailController.text.trim();
              if (newName.isEmpty || newEmail.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Không được để trống" : "Cannot be empty")));
                return;
              }
              try {
                await FirebaseFirestore.instance.collection('users').doc(childUid).update({
                  'displayName': newName,
                  'email': newEmail,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Cập nhật thành công cho $newName" : "Updated successfully for $newName")));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi: $e")));
              }
            },
            child: Text(_isVietnamese ? "Lưu" : "Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChild(BuildContext context, String childUid, String childName) async {
    bool confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(_isVietnamese ? "Xóa tài khoản" : "Delete account"),
            content: Text(_isVietnamese ? "Xóa vĩnh viễn tài khoản của $childName?\nKhông thể hoàn tác!" : "Permanently delete $childName's account?\nCannot be undone!"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
              TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_isVietnamese ? "Xóa" : "Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ?? false;
    if (!confirmed) return;
    bool reauth = await _reauthenticateParent(context);
    if (!reauth) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(childUid).delete();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Đã xóa $childName thành công" : "Successfully deleted $childName")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi xóa: $e")));
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isVietnamese ? "Đăng xuất" : "Logout"),
        content: Text(_isVietnamese ? "Bạn có chắc muốn đăng xuất không?" : "Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(_isVietnamese ? "Đăng xuất" : "Logout", style: TextStyle(color: Colors.red))),
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
        title: Text(_isVietnamese ? "Thêm ghi chú mới" : "Add new note"),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: _isVietnamese ? "Ví dụ: Mua sữa, cá, rau cải..." : "E.g: Buy milk, fish, vegetables...",
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
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
            child: Text(_isVietnamese ? "Lưu" : "Save"),
          ),
        ],
      ),
    );
  }

  void _deleteNote(String noteId) async {
    await FirebaseFirestore.instance.collection('notes').doc(noteId).delete();
  }

  String _formatTimestamp(Timestamp timestamp) {
    DateTime date = timestamp.toDate();
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime yesterday = today.subtract(const Duration(days: 1));
    DateTime dateDay = DateTime(date.year, date.month, date.day);

    String time = "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";

    if (dateDay == today) {
      return _isVietnamese ? "Hôm nay, $time" : "Today, $time";
    } else if (dateDay == yesterday) {
      return _isVietnamese ? "Hôm qua, $time" : "Yesterday, $time";
    } else {
      String day = date.day.toString().padLeft(2, '0');
      String month = date.month.toString().padLeft(2, '0');
      return _isVietnamese
          ? "$day/$month/${date.year}, $time"
          : "$month/$day/${date.year}, $time";
    }
  }

  void _showTaskDetailForParent(BuildContext context, String taskId, Map<String, dynamic> taskData, String childName) {
    String title = taskData['title'] ?? '';
    String desc = taskData['description'] ?? '';
    String status = taskData['status'] ?? 'pending';
    int reward = taskData['rewardXP'] ?? 0;
    Timestamp? dueTimestamp = taskData['dueDate'];
    String dueDate = dueTimestamp != null
        ? dueTimestamp.toDate().toLocal().toString().split(' ')[0]
        : (_isVietnamese ? "Không có hạn" : "No deadline");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(taskData['isAll'] == true ? (_isVietnamese ? "Việc chung cho tất cả bé" : "Common task for all children") : "Giao cho: $childName", style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(desc),
              const SizedBox(height: 12),
              Text(_isVietnamese ? "Hạn chót: $dueDate" : "Deadline: $dueDate"),
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
                Text(_isVietnamese ? "Minh chứng từ con:" : "Evidence from child:", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      return Text(_isVietnamese ? "Lỗi tải ảnh" : "Error loading images");
                    }
                    if (!evidenceSnapshot.hasData || evidenceSnapshot.data!.docs.isEmpty) {
                      return Text(_isVietnamese ? "Không có ảnh minh chứng" : "No evidence photos");
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
                      label: Text(_isVietnamese ? "Duyệt" : "Approve"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      onPressed: () => _approveTask(context, taskId, taskData['assignedTo'], reward),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.close),
                      label: Text(_isVietnamese ? "Từ chối" : "Reject"),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Đóng" : "Close")),
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
          SnackBar(content: Text(_isVietnamese ? "Đã duyệt! Bé được cộng XP" : "Approved! Child received XP")),
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
          SnackBar(content: Text(_isVietnamese ? "Đã từ chối. Bé cần làm lại" : "Rejected. Child needs to redo")),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text(_isVietnamese ? "Lỗi tải phần thưởng" : "Error loading rewards"));
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Text(_isVietnamese ? "Chưa có phần thưởng nào\nNhấn nút + để thêm" : "No rewards yet\nTap + to add", style: TextStyle(fontSize: 18, color: Colors.grey)),
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
        title: Text(rewardId == null ? (_isVietnamese ? "Thêm phần thưởng mới" : "Add new reward") : (_isVietnamese ? "Chỉnh sửa phần thưởng" : "Edit reward")),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Tên phần thưởng (bắt buộc)" : "Reward name (required)"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Mô tả chi tiết" : "Detailed description"),
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(labelText: _isVietnamese ? "Điểm cần đổi (10-100)" : "Points required (10-100)"),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Hủy" : "Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              String name = nameController.text.trim();
              String desc = descController.text.trim();
              int? points = int.tryParse(pointsController.text);
              if (name.isEmpty || points == null || points < 10 || points > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_isVietnamese ? "Kiểm tra lại tên và điểm (10-100)" : "Check name and points (10-100)")),
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
              String message = rewardId == null ? (_isVietnamese ? "Thêm thành công!" : "Added successfully!") : (_isVietnamese ? "Cập nhật thành công!" : "Updated successfully!");
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
            },
            child: Text(rewardId == null ? (_isVietnamese ? "Thêm" : "Add") : (_isVietnamese ? "Lưu" : "Save")),
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
          TextButton(onPressed: () => Navigator.pop(context), child: Text(_isVietnamese ? "Đóng" : "Close")),
        ],
      ),
    );
  }

  Future<void> _deleteReward(String rewardId) async {
    await FirebaseFirestore.instance.collection('rewards').doc(rewardId).delete();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isVietnamese ? "Đã xóa phần thưởng" : "Reward deleted")));
  }

  Widget _buildOverview() {
    final String parentUid = currentUser!.uid;
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    weekStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_isVietnamese ? "Tổng quan tuần này" : "This week's overview", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange)),
          const SizedBox(height: 20),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .where('parentUid', isEqualTo: parentUid)
                .where('role', isEqualTo: 'child')
                .get(),
            builder: (context, childrenSnapshot) {
              int childCount = childrenSnapshot.hasData ? childrenSnapshot.data!.docs.length : 0;
              return _statCard(_isVietnamese ? "Số con" : "Number of children", childCount.toString(), Icons.child_care, Colors.blue);
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
                  _statCard(_isVietnamese ? "Việc đã giao" : "Tasks assigned", totalTasks.toString(), Icons.assignment, Colors.green),
                  const SizedBox(height: 12),
                  _statCard(_isVietnamese ? "Hoàn thành" : "Completed", completedTasks.toString(), Icons.check_circle, Colors.orange),
                  const SizedBox(height: 12),
                  _statCard(_isVietnamese ? "Tỷ lệ hoàn thành" : "Completion rate", "${completionRate.toStringAsFixed(0)}%", Icons.trending_up, Colors.purple),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('logins')
                .where('userUid', isEqualTo: parentUid)
                .snapshots(),
            builder: (context, loginSnapshot) {
              if (!loginSnapshot.hasData) {
                return _statCard(_isVietnamese ? "Lượt truy cập tuần này" : "Logins this week", "0", Icons.login, Colors.purple);
              }
              int loginCount = 0;
              for (var doc in loginSnapshot.data!.docs) {
                Timestamp? ts = doc['timestamp'] as Timestamp?;
                if (ts != null) {
                  DateTime loginDate = ts.toDate();
                  if (loginDate.isAfter(weekStart.subtract(const Duration(days: 1)))) {
                    loginCount++;
                  }
                }
              }
              return _statCard(_isVietnamese ? "Lượt truy cập tuần này" : "Logins this week", loginCount.toString(), Icons.login, Colors.purple);
            },
          ),
          const SizedBox(height: 30),
          Text(_isVietnamese ? "Hoạt động gần đây" : "Recent activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.orange)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tasks')
                .where('assignedBy', isEqualTo: parentUid)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, recentSnapshot) {
              if (!recentSnapshot.hasData || recentSnapshot.data!.docs.isEmpty) {
                return Text(_isVietnamese ? "Chưa có hoạt động nào" : "No recent activity", style: TextStyle(fontSize: 16));
              }
              return Column(
                children: recentSnapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String title = data['title'] ?? 'Việc không tên';
                  String status = data['status'] ?? 'pending';
                  String statusText = status == 'approved' ? (_isVietnamese ? 'Hoàn thành' : 'Completed') : status == 'submitted' ? (_isVietnamese ? 'Đã nộp' : 'Submitted') : (_isVietnamese ? 'Chưa làm' : 'Pending');
                  return ListTile(
                    leading: const Icon(Icons.circle, size: 10, color: Colors.orange),
                    title: Text(title),
                    subtitle: Text(_isVietnamese ? "Trạng thái: $statusText" : "Status: $statusText"),
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
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _isVietnamese ? "Danh sách việc đã giao" : "Assigned tasks list",
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
                return Center(child: Text(_isVietnamese ? "Lỗi tải danh sách việc" : "Error loading task list", style: TextStyle(color: Colors.red)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_add, size: 80, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        _isVietnamese ? "Chưa giao việc nào\nNhấn nút + để bắt đầu" : "No tasks assigned yet\nTap + to start",
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
                      ? dueTimestamp.toDate().toLocal().toString().split(' ')[0]
                      : (_isVietnamese ? "Không có hạn" : "No deadline");
                  bool isAll = data['isAll'] == true;
                  String assignedTo = data['assignedTo'];
                  return FutureBuilder<DocumentSnapshot>(
                    future: isAll ? null : FirebaseFirestore.instance.collection('users').doc(assignedTo).get(),
                    builder: (context, childSnapshot) {
                      String childName = isAll ? (_isVietnamese ? "Tất cả bé" : "All children") : (childSnapshot.hasData && childSnapshot.data!.exists ? childSnapshot.data!['displayName'] ?? 'Không tên' : "Không rõ");
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
                              Text(_isVietnamese ? "Giao cho: $childName" : "Assigned to: $childName", style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(_isVietnamese ? "Hạn: $dueDate" : "Due: $dueDate"),
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
        text = _isVietnamese ? "Chưa làm" : "Pending";
        break;
      case 'submitted':
        color = Colors.blue;
        text = _isVietnamese ? "Đã nộp" : "Submitted";
        break;
      case 'approved':
        color = Colors.green;
        text = _isVietnamese ? "Hoàn thành" : "Completed";
        break;
      case 'rejected':
        color = Colors.red;
        text = _isVietnamese ? "Từ chối" : "Rejected";
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

  Widget _buildChildrenManagement(String parentUid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_isVietnamese ? "Tạo tài khoản mới cho con" : "Create new child account"),
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
              if (snapshot.hasError) return Center(child: Text(_isVietnamese ? "Lỗi kết nối" : "Connection error"));
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(child: Text(_isVietnamese ? "Chưa có con nào\nTạo bé đầu tiên đi anh!" : "No children yet\nCreate the first one!", style: TextStyle(fontSize: 16, color: Colors.grey)));
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

  Widget _buildStatisticsReport(String parentUid) {
    DateTime now = DateTime.now();
    DateTime weekStart = now.subtract(Duration(days: now.weekday - 1));
    Timestamp weekStartTimestamp = Timestamp.fromDate(weekStart);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isVietnamese ? "Báo cáo thống kê tuần này" : "This week's statistics report",
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
                return Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        _isVietnamese ? "Chưa có bé nào để thống kê\nTạo tài khoản con trước nhé!" : "No children to show stats\nCreate child account first!",
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
                    bool isAll = data['isAll'] == true;
                    String? assignedTo = data['assignedTo'] as String?;
                    String status = data['status'] as String? ?? 'pending';
                    if (isAll) {
                      for (int i = 0; i < childUids.length; i++) {
                        assignedSpots[i]++;
                        if (status == 'approved') completedSpots[i]++;
                      }
                    } else if (assignedTo != null) {
                      int index = childUids.indexOf(assignedTo);
                      if (index != -1) {
                        assignedSpots[index]++;
                        if (status == 'approved') completedSpots[index]++;
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
                          Text(
                            _isVietnamese ? "Việc được giao & hoàn thành theo bé" : "Tasks assigned & completed per child",
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
                                      reservedSize: 70,
                                      getTitlesWidget: (value, meta) {
                                        int index = value.toInt();
                                        if (index < 0 || index >= childNames.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 8),
                                          child: Text(
                                            childNames[index],
                                            style: const TextStyle(fontSize: 11),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 2,
                                            textAlign: TextAlign.center,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                ),
                                gridData: const FlGridData(show: true),
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
                              Row(children: [
                                Container(width: 20, height: 20, color: Colors.orange[400]),
                                const SizedBox(width: 10),
                                Text(_isVietnamese ? "Đã giao" : "Assigned", style: TextStyle(fontSize: 16)),
                              ]),
                              const SizedBox(width: 30),
                              Row(children: [
                                Container(width: 20, height: 20, color: Colors.green[600]),
                                const SizedBox(width: 10),
                                Text(_isVietnamese ? "Hoàn thành" : "Completed", style: TextStyle(fontSize: 16)),
                              ]),
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
                      Text(_isVietnamese ? "Tổng lượt truy cập tuần này" : "Total logins this week", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      Text(
                        totalLogins.toString(),
                        style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold, color: Colors.purple),
                      ),
                      Text(_isVietnamese ? "Cả bố mẹ và các bé" : "Parents and children", style: TextStyle(color: Colors.grey, fontSize: 16)),
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

  Widget _buildNotesScreen(String parentUid) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: Text(_isVietnamese ? "Thêm ghi chú mới" : "Add new note"),
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
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(_isVietnamese ? "Lỗi tải ghi chú" : "Error loading notes"));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(
                    _isVietnamese
                        ? "Chưa có ghi chú nào\nNhấn nút + để thêm nhé!"
                        : "No notes yet\nTap + to add!",
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 18),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  String noteId = doc.id;
                  String content = (doc['content'] as String?) ?? '(Không có nội dung)';

                  Timestamp? timestamp = doc['createdAt'] as Timestamp?;
                  String timeString = timestamp != null
                      ? _formatTimestamp(timestamp)
                      : (_isVietnamese ? "Không rõ thời gian" : "Unknown time");

                  return Dismissible(
                    key: Key(noteId),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => _deleteNote(noteId),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: const Icon(Icons.note, color: Colors.orange, size: 40),
                        title: Text(
                          content,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            timeString,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteNote(noteId),
                        ),
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

  Widget _buildCalendarForParent(String parentUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tasks')
          .where('assignedBy', isEqualTo: parentUid)
          .snapshots(),
      builder: (context, snapshot) {
        Map<DateTime, List<Map<String, dynamic>>> events = {};
        Set<DateTime> overdueDates = {};
        if (snapshot.hasData) {
          DateTime now = DateTime.now();
          for (var doc in snapshot.data!.docs) {
            var data = doc.data() as Map<String, dynamic>;
            Timestamp? dueTimestamp = data['dueDate'];
            if (dueTimestamp != null) {
              DateTime dueDate = dueTimestamp.toDate();
              DateTime normalized = DateTime(dueDate.year, dueDate.month, dueDate.day);
              events.putIfAbsent(normalized, () => []);
              events[normalized]!.add(data..['id'] = doc.id);
              if (data['status'] != 'approved' && dueDate.isBefore(now)) {
                overdueDates.add(normalized);
              }
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
                  setState(() => _calendarFormat = format);
                },
                onPageChanged: (focusedDay) => _focusedDay = focusedDay,
                eventLoader: (day) {
                  DateTime normalized = DateTime(day.year, day.month, day.day);
                  return events[normalized] ?? [];
                },
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    DateTime normalized = DateTime(day.year, day.month, day.day);
                    if (events.isNotEmpty) {
                      bool isOverdue = overdueDates.contains(normalized);
                      return Positioned(
                        bottom: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOverdue ? Colors.red : Colors.green,
                          ),
                          width: 16,
                          height: 16,
                        ),
                      );
                    }
                    return null;
                  },
                ),
                calendarStyle: const CalendarStyle(
                  todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: Colors.deepOrange, shape: BoxShape.circle),
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
                _isVietnamese ? "Việc của các bé hôm nay" : "Children's tasks today",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _selectedDay == null
                  ? Center(child: Text(_isVietnamese ? "Chọn ngày để xem lịch bé nhé bố mẹ! 📅" : "Select a date to view children's schedule! 📅"))
                  : _buildParentTasksForDay(events, _selectedDay!),
            ),
          ],
        );
      },
    );
  }

  Widget _buildParentTasksForDay(Map<DateTime, List<Map<String, dynamic>>> events, DateTime day) {
    DateTime normalized = DateTime(day.year, day.month, day.day);
    List<Map<String, dynamic>> dayTasks = events[normalized] ?? [];
    if (dayTasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_available, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              _isVietnamese ? "Hôm nay các bé không có việc nào!\nTốt lắm các con! 🌟" : "No tasks for children today!\nWell done kids! 🌟",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey),
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
        Timestamp? dueTimestamp = task['dueDate'];
        DateTime? dueDate = dueTimestamp?.toDate();
        bool isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && status != 'approved';
        bool isAll = task['isAll'] == true;
        return FutureBuilder<List<String>>(
          future: isAll
              ? FirebaseFirestore.instance
                  .collection('users')
                  .where('parentUid', isEqualTo: currentUser!.uid)
                  .where('role', isEqualTo: 'child')
                  .get()
                  .then((snapshot) => snapshot.docs.map((d) => d['displayName'] as String? ?? 'Không tên').toList())
              : FirebaseFirestore.instance.collection('users').doc(task['assignedTo']).get().then((doc) => [doc['displayName'] ?? 'Không tên']),
          builder: (context, nameSnapshot) {
            String displayName = isAll
                ? (_isVietnamese ? "Tất cả bé" : "All children")
                : (nameSnapshot.hasData ? nameSnapshot.data![0] : 'Đang tải...');
            Color cardColor = isOverdue ? Colors.red[50]! : Colors.white;
            return Card(
              color: cardColor,
              elevation: isOverdue ? 10 : 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: Icon(
                  isOverdue ? Icons.warning_amber_rounded : Icons.task_alt,
                  color: isOverdue ? Colors.red : Colors.orange,
                  size: 40,
                ),
                title: Text(
                  task['title'],
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_isVietnamese ? "Giao cho: $displayName" : "Assigned to: $displayName"),
                    Text("+${task['rewardXP']} XP"),
                    if (isOverdue) Text("⚠️ ĐÃ QUÁ HẠN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: _buildStatusChip(status),
                onTap: () {
                  _showTaskDetailForParent(context, task['id'], task, displayName);
                },
              ),
            );
          },
        );
      },
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
                      Text(_isVietnamese ? "Xin chào," : "Hello,", style: TextStyle(color: Colors.white70, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  );
                },
              ),
            ),
            ListTile(
              leading: Icon(_isVietnamese ? Icons.language : Icons.translate),
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
            ..._titles.asMap().entries.map((entry) {
              int idx = entry.key;
              String title = entry.value;
              List<IconData> icons = [
                Icons.dashboard,
                Icons.child_care,
                Icons.assignment,
                Icons.card_giftcard_rounded,
                Icons.bar_chart,
                Icons.calendar_month,
                Icons.note_alt,
              ];
              return ListTile(
                leading: Icon(icons[idx]),
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
        return _buildCalendarForParent(parentUid);
      case 6:
        return _buildNotesScreen(parentUid);
      default:
        return const SizedBox();
    }
  }
}