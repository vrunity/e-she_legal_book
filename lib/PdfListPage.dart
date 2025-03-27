import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'pdf_viewpage.dart';
import 'loginpage.dart';

class PdfListPage extends StatefulWidget {
  final bool isApproved;
  PdfListPage({required this.isApproved});

  @override
  _PdfListPageState createState() => _PdfListPageState();
}

class _PdfListPageState extends State<PdfListPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> allFolders = [];
  Map<String, String> unrestrictedFiles = {
  }; // One unrestricted file per folder
  List<String> allFolderFiles = [];
  String? accessibleFile; // Stores the first free file
  String? userName = " "; // Default name for unapproved users

  late TabController _tabController;
  final String apiUrl = "https://esheapp.in/pdf_userapp/get_files.php";
  final String baseFolderUrl = "https://esheapp.in/pdf_userapp/approved_books/";

  bool isLoadingFolders = false;
  bool isLoadingFiles = false;
  String? currentFolderPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    fetchUserName(); // Fetch user name from SharedPreferences
    fetchFolders();
  }

  Future<void> fetchUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? contact = prefs.getString('contact'); // Ensure user contact is stored locally

    if (contact == null) {
      setState(() {
        userName = "Guest"; // Default name
      });
      return;
    }

    String url = "https://esheapp.in/pdf_userapp/get_username.php?contact=$contact";
    print("Sending request to: $url");

    try {
      final response = await http.get(Uri.parse(url));

      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        var jsonData = jsonDecode(response.body);
        print("Decoded JSON: $jsonData");

        if (jsonData['status'] == 'success') {
          String fetchedName = jsonData['name'];
          await prefs.setString('username', fetchedName); // Save username locally

          setState(() {
            userName = fetchedName;
          });
        } else {
          setState(() {
            userName = "Guest";
          });
        }
      } else {
        setState(() {
          userName = "Guest";
        });
      }
    } catch (e) {
      print("Error fetching username: $e");
      setState(() {
        userName = "Error: $e";
      });
    }
  }


  /// Fetch list of folders
  Future<void> fetchFolders() async {
    setState(() {
      isLoadingFolders = true;
    });

    try {
      print("Fetching folders..."); // Debug print
      final response = await http.post(
        Uri.parse(apiUrl),
        body: {'mode': 'folders'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Folders Response: $data"); // Debug print

        if (data['status'] == 'success') {
          dynamic allFoldersResponse = data['allFolders'];

          // Ensure response is a list
          if (allFoldersResponse is Map) {
            allFoldersResponse = allFoldersResponse.values.toList();
          }

          if (allFoldersResponse is List) {
            setState(() {
              allFolders = List<Map<String, dynamic>>.from(allFoldersResponse);
            });
          } else {
            throw Exception(
                "Invalid data format: 'allFolders' should be a list.");
          }
        } else {
          throw Exception(data['error'] ?? "Failed to load folders.");
        }
      } else {
        throw Exception("Failed to connect to the server.");
      }
    } catch (e) {
      print("Exception in fetchFolders: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching folders: $e")),
      );
    } finally {
      setState(() {
        isLoadingFolders = false;
      });
    }
  }

  /// Fetch PDFs inside a selected folder
  Future<void> fetchFiles(String folderPath) async {
    setState(() {
      isLoadingFiles = true;
      accessibleFile = null; // Reset before fetching
      currentFolderPath = folderPath; // Update selected folder
    });

    try {
      print("Fetching files from folder: $folderPath"); // Debug print

      final response = await http.post(Uri.parse(apiUrl), body: {
        'mode': 'files',
        'folderName': folderPath,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Files Response: $data"); // Debug print

        if (data['status'] == 'success') {
          setState(() {
            allFolderFiles = List<String>.from(data['files']);
            accessibleFile = data['accessibleFile']; // Store first free file
          });
        } else {
          throw Exception("Failed to load files.");
        }
      } else {
        throw Exception("Failed to connect to the server.");
      }
    } catch (e) {
      print("Error in fetchFiles: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching files: $e")));
    } finally {
      setState(() {
        isLoadingFiles = false;
      });
    }
  }

  /// Open PDF file with restrictions
  void openPdf(String pdfUrl, bool isApproved, String freePdf) {
    print("Trying to open PDF: $pdfUrl"); // Debug print

    if (!isApproved && pdfUrl != freePdf) {
      print("Access Denied: Requires approval"); // Debug print
      showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text("Access Denied"),
              content: Text(
                  "You need approval to view this file. Contact Admin."),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context), child: Text("OK"))
              ],
            ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PdfViewerPage(pdfUrl: pdfUrl)),
      );
    }
  }


  Widget buildFolderGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3 / 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: allFolders.length,
      itemBuilder: (context, index) {
        final folder = allFolders[index];

        return GestureDetector(
          onTap: () => fetchFiles(folder['path']),
          child: SizedBox(
            width: 150,  // Set your desired width
            height: 100, // Set your desired height
            child: Card(
              elevation: 6, // Light drop shadow
              color: Colors.white, // Set box color to white
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: Colors.black.withOpacity(0.2), // Subtle shadow
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder, size: 50, color: Colors.amber), // Yellow folder icon
                  const SizedBox(height: 10.0),
                  Text(
                    folder['name'],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black, // Black text for better contrast
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Widget buildFileGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 3 / 3,
        crossAxisSpacing: 8.0,
        mainAxisSpacing: 8.0,
      ),
      itemCount: allFolderFiles.length,
      itemBuilder: (context, index) {
        String pdfUrl = allFolderFiles[index]; // Get PDF URL

        return GestureDetector(
          onTap: () {
            if (accessibleFile == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Error: accessible file not set!")),
              );
            } else {
              openPdf(pdfUrl, widget.isApproved, accessibleFile!);
            }
          },
          child: Card(
            elevation: 6, // Increased shadow effect
            color: Colors.white, // Folder background color changed to white
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            shadowColor: Colors.black.withOpacity(0.2), // Subtle shadow
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.picture_as_pdf, size: 50, color: Colors.redAccent), // Darker red PDF icon
                const SizedBox(height: 8.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    pdfUrl.split('/').last, // Show file name
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black, // Changed text color to black for better contrast
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE), // Very light gray for better distinction
      appBar:PreferredSize(
        preferredSize: const Size.fromHeight(70), // Set AppBar height
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFF0000), Color(0xFF710606)], // Gradient from Red to Brown
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent, // Make AppBar transparent to show gradient
            elevation: 0, // Remove shadow for a cleaner look
            centerTitle: true,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min, // Prevent excessive spacing
              children: [
                const Text(
                  "SEED FOR SAFETY",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 5), // Adjusted spacing
                Text(
                  userName ?? "Guest",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, size: 28, color: Colors.white), // White logout icon
                onPressed: () async {
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  await prefs.clear();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => LoginPage()),
                  );
                },
              ),
            ],
          ),
        ),
      ),

        body: currentFolderPath == null ? buildFolderGrid() : buildFileGrid(),
      floatingActionButton: currentFolderPath != null
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            currentFolderPath = null;
            allFolderFiles.clear(); // ✅ Ensures previous folder data is cleared
          });
        },
        backgroundColor: Colors.transparent, // Transparent to apply gradient
        elevation: 0, // No shadow
        shape: const CircleBorder(), // Ensures it's a perfect circle
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF0000), Color(0xFF710606)], // Smooth red to dark maroon
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center, // Center the icon
          padding: const EdgeInsets.all(15), // Proper spacing inside the button
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 28), // White arrow
        ),
      )


          : null,
    );
  }
}