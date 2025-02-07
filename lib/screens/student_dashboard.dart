import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/school_model.dart';
import '../widgets/attendance_chart.dart';
import 'login_screen.dart';
import '../services/user_session.dart';

class StudentDashboard extends StatefulWidget {
  final School school;
  final String rollNo;
  final String studentName;
  final String classId;

  StudentDashboard({
    required this.school,
    required this.rollNo,
    required this.studentName,
    required this.classId,
  });

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 0;
  double _attendancePercentage = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _calculateAttendance();
  }

  Future<void> _calculateAttendance() async {
    try {
      final QuerySnapshot attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance_records')
          .where('classId', isEqualTo: widget.classId)
          .where('rollNumber', isEqualTo: widget.rollNo)
          .orderBy('date')
          .get();

      int totalDays = attendanceSnapshot.docs.length;
      int presentDays = attendanceSnapshot.docs
          .where((doc) => doc['status'] == 'present')
          .length;

      if (!mounted) return;

      setState(() {
        _attendancePercentage = totalDays > 0 
            ? (presentDays / totalDays) * 100 
            : 0.0;
        _isLoading = false;
      });

      if (_attendancePercentage < 60) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Your attendance is below 60%'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      print('Error calculating attendance: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error calculating attendance. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final bool? confirmLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Confirm Logout'),
        content: Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout != true) return;

    try {
      await UserSession.clearSession();
      if (!mounted) return;
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      print('Error during logout: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildRecordsTab() {
    print('Building records tab with parameters:');
    print('Class ID: ${widget.classId}');
    print('Roll Number: ${widget.rollNo}');
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance_records')
          .where('classId', isEqualTo: widget.classId)
          .where('rollNumber', isEqualTo: widget.rollNo)
          .orderBy('date')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error in records query: ${snapshot.error}');
          return Center(
            child: Text(
              'Error loading records. Please try again later.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text('Loading records...'),
              ],
            ),
          );
        }

        final records = snapshot.data!.docs;
        
        if (records.isEmpty) {
          return Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'No Records Found',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Your attendance records will appear here',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            Card(
              margin: EdgeInsets.all(16),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Attendance Overview',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            Text(
                              '${_attendancePercentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _attendancePercentage < 60 
                                    ? Colors.red 
                                    : Colors.green,
                              ),
                            ),
                            Text('Total Attendance'),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '${records.length}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text('Total Days'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final date = DateFormat('dd MMM yyyy')
                      .format((record['date'] as Timestamp).toDate());
                  final status = record['status'];

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        status == 'present' 
                            ? Icons.check_circle 
                            : Icons.cancel,
                        color: status == 'present' 
                            ? Colors.green 
                            : Colors.red,
                      ),
                      title: Text(date),
                      subtitle: Text(
                        status.toString().toUpperCase(),
                        style: TextStyle(
                          color: status == 'present' 
                              ? Colors.green 
                              : Colors.red,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProfileTab() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        widget.studentName[0].toUpperCase(),
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    title: Text(
                      widget.studentName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    subtitle: Text('Roll No: ${widget.rollNo}'),
                  ),
                  Divider(),
                  ListTile(
                    leading: Icon(Icons.school),
                    title: Text(widget.school.name),
                  ),
                  ListTile(
                    leading: Icon(Icons.location_on),
                    title: Text(widget.school.address),
                    subtitle: Text('${widget.school.district}, ${widget.school.state}'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _handleLogout,
            icon: Icon(Icons.logout),
            label: Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              minimumSize: Size(double.infinity, 50),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Student Dashboard'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedIndex,
              children: [
                _buildRecordsTab(),
                _buildProfileTab(),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Records',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}