# 📅 3D TodoList App

A powerful and intuitive **Task Management App** with a unique **3D task viewer**, calendar-based task browsing, full task statistics and visual analytics. Built for productivity lovers and goal-driven users!

---

## 🚀 Features

### ✅ Task Management
- Create, edit, delete tasks easily
- Assign **priority levels**, **tags**, and **categories**
- Sort tasks:
  - Alphabetically (A-Z, Z-A)
  - By **Priority**
  - By **Experience System** (XP)
  - By **Achievements**

### 🔐 Authentication
- **Sign Up** with email and password
- **Secure Sign In** with Firebase Authentication
- Persistent login session
- Support for password reset and email verification *(optional)*

![SignIn Screens](images/491095798_697070649557840_8475609123261802112_n.jpg)
![SignUp Screens](images/488621385_1604969863509930_7948300953744262072_n.jpg)

### 🧭 3D Task Visualization
- Explore your task details in a **3D interactive interface**
- Zoom, rotate, and pan to view your task attributes in a fun and immersive way!

![3D Interaction Example](images/491004680_1352843066100956_8151260893042282377_n.jpg)

### 📆 Integrated Calendar View
- View all your tasks on a **monthly calendar**
- Click on any date to see tasks scheduled for that day
- Identify deadlines at a glance

![Calendar View](images/482847556_1333197881290587_8763466415220350125_n.jpg)

### 📊 Task Statistics and Insights
- Visual graphs showing:
  - Completed tasks per day/week/month
  - Task completion trends over time
  - Daily productivity summaries
- Track:
  - 📈 All completed tasks since beginning
  - 📅 Tasks completed today

![Statistics Dashboard](images/491011058_1376376423305652_4494223048211532498_n.jpg)

### 🏆 Achievements & Experience System
- Earn XP by completing tasks
- Unlock badges and achievements
- Level up as you progress!

![Achievements](images/488578564_1235150164837501_5593420835861056280_n.jpg)
![Experience](images/491016532_545035148646670_718867595093098129_n.jpg)

---

### Sound Announcement
- You can turn on or turn It off.
- Change the volume of the announce.
- It will only announce numbere of Task that has currentDate - EndDate <= 3

![SettingScreens](images/485492599_672714158472258_2157619058850298136_n.jpg)
![AnnounceScreens](images/491006102_973222678357085_930679029084654901_n.jpg)

## 📦 Installation

```bash
git clone https://github.com/yourusername/3d-todolist.git
cd 3d-todolist
flutter pub get
flutter run
