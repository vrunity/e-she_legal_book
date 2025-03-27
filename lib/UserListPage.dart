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

  // Function to show user details and actions
  void showUserDetails(Map<String, dynamic> user, int index) {
    final int isApproved = int.parse(user['isApproved'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user['name']),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Contact: ${user['contact']}"),
            Text("Status: ${isApproved == 1 ? 'Approved' : 'Not Approved'}"),
          ],
        ),
        actions: [
          if (isApproved == 0)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                updateApprovalStatus(user['id'], 1, index);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Approve"),
            ),
          if (isApproved == 1)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                updateApprovalStatus(user['id'], 0, index);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: Text("Unapprove"),
            ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              removeUser(user['id'], index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text("Remove"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text("Close"),
          ),
        ],
      ),
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
      appBar: AppBar(
        title: Text("User List"),
        centerTitle: true,
        backgroundColor: Color(0xFF56ab2f),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
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
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          final int isApproved = int.parse(user['isApproved'].toString());
          return Card(
            color: isApproved == 1
                ? Colors.green.shade50
                : Colors.orange.shade50,
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isApproved == 1 ? Colors.green : Colors.orange,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                user['name'],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("Contact: ${user['contact']}"),
              trailing: Icon(Icons.arrow_forward_ios),
              onTap: () => showUserDetails(user, index),
            ),
          );
        },
      ),
    );
  }
}