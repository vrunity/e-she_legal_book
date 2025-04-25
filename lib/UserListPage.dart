import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'loginpage.dart';

class UserListPage extends StatefulWidget {
  @override
  _UserListPageState createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  bool isLoading = true; // Loading state
  List<dynamic> users = []; // List of users

  @override
  void initState() {
    super.initState();
    fetchUserList();
  }

  // Function to fetch the user list from the server
  Future<void> fetchUserList() async {
    try {
      final String apiUrl = "https://esheapp.in/pdf_userapp/get_users.php";
      final response = await http.get(Uri.parse(apiUrl));

      if (response.statusCode == 200) {
        final cleanedResponse = response.body.substring(response.body.indexOf('{'));
        setState(() {
          users = json.decode(cleanedResponse)['data'];
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to load user list. Please try again.")),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred. Please try again.")),
      );
    }
  }

  // Function to update user approval status
  Future<void> updateApprovalStatus(String userId, int approvalStatus, int index) async {
    try {
      final String apiUrl = "https://esheapp.in/pdf_userapp/update_approval.php";
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {
          'user_id': userId,
          'isApproved': approvalStatus.toString(),
        },
      );

      if (response.statusCode == 200) {
        final cleanedResponse = response.body.substring(response.body.indexOf('{'));
        var data = json.decode(cleanedResponse);

        if (data['status'] == 'success') {
          setState(() {
            users[index]['isApproved'] = approvalStatus;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update approval status.")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred. Please try again.")),
      );
    }
  }

  // Function to remove a user
  Future<void> removeUser(String userId, int index) async {
    try {
      final String apiUrl = "https://esheapp.in/pdf_userapp/remove_user.php";
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'user_id': userId},
      );

      final responseBody = response.body.trim();

      // Extract the first JSON object
      final jsonStartIndex = responseBody.indexOf('{');
      final jsonEndIndex = responseBody.indexOf('}', jsonStartIndex);
      if (jsonStartIndex != -1 && jsonEndIndex != -1) {
        final cleanedResponse = responseBody.substring(jsonStartIndex, jsonEndIndex + 1);
        var data = json.decode(cleanedResponse);

        if (data['status'] == 'success') {
          setState(() {
            users.removeAt(index); // Remove the user from the list
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "User removed successfully.")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? "Failed to remove user.")),
          );
        }
      } else {
        throw FormatException("Invalid JSON format");
      }
    } catch (e) {
      debugPrint("Error in removeUser: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred. Please try again.")),
      );
    }
  }

  // Function to get user initials from their name for a modern avatar
  String getUserInitials(String name) {
    List<String> names = name.split(" ");
    String initials = "";
    for (var part in names) {
      if (part.isNotEmpty) {
        initials += part[0].toUpperCase();
      }
    }
    return initials;
  }

  // Function to show user details and actions in a modern-styled dialog
  void showUserDetails(Map<String, dynamic> user, int index) {
    final int isApproved = int.parse(user['isApproved'].toString());
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 10),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background, icon, and close icon at the right corner
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF4500), Color(0xFF5B0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Left side: Icon + Name
                      Row(
                        children: [
                          Icon(Icons.person, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            user['name'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      // Right side: Close icon
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content displaying contact and approval status (left-aligned)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Contact: ${user['contact']}",
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "Status: ${isApproved == 1 ? 'Approved' : 'Not Approved'}",
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),

                // Action buttons row with white theme and differentiated border colors
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (isApproved == 0)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            updateApprovalStatus(user['id'], 1, index);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.green.shade400, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text("Approve"),
                        ),
                      if (isApproved == 1)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            updateApprovalStatus(user['id'], 0, index);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.amber.shade400, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text("Unapprove"),
                        ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          removeUser(user['id'], index);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.red.shade400, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text("Remove"),
                      ),
                    ],
                  ),
                ),

                // Extra bottom spacing
                SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }


  // Function to logout the user
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  // Function to show logout confirmation dialog
  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Confirm Logout"),
          content: Text("Are you sure you want to log out?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                logout();
              },
              child: Text("Logout"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text(
            "User List",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          elevation: 4,
          // Using a gradient background for a modern look
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF4500), Color(0xFF5B0000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() {
                  isLoading = true;
                });
                fetchUserList();
              },
            ),
            IconButton(
              icon: Icon(Icons.logout, color: Colors.white),
              onPressed: showLogoutDialog,
            ),
          ],
        ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : users.isEmpty
          ? Center(
        child: Text(
          "No users found",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final int isApproved = int.parse(user['isApproved'].toString());
          return GestureDetector(
            onTap: () => showUserDetails(user, index),
            child: Container(
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: isApproved == 1 ? Colors.greenAccent : Colors.orangeAccent,
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                leading: CircleAvatar(
                  backgroundColor: isApproved == 1 ? Colors.green : Colors.orange,
                  child: Text(
                    getUserInitials(user['name']),
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  user['name'],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    "Contact: ${user['contact']}",
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ),
          );
        },
      ),
    );
  }
}
