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
  List<String> folderNavigationStack = [];
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
  final Map<String, String> folderIcons = {
    'BOCWR': 'assets/bocwr.png',
    'DGFASLI': 'assets/dgfasli.png',
    'Electrical': 'assets/electrical.png',
    'Environment-TNPCB amendments': 'assets/environment.png',
    'ESI &PF': 'assets/esi_pf.png',
    'FIRE': 'assets/fire.png',
    'Food': 'assets/food.png',
    'Legal Amendements upto 2024': 'assets/legal2024.png',
    'Legal Amendements 2025': 'assets/2025.png',
    'LIFT': 'assets/lift.png',
    'Others': 'assets/others.png',
    'PESO': 'assets/peso.png',
    'The Factory act and rules': 'assets/factory_act.png',
  };

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
  Future<void> fetchFiles(String folderPath, {bool isNavigatingForward = true}) async {
    setState(() {
      isLoadingFiles = true;
      accessibleFile = null;
      currentFolderPath = folderPath;
      allFolderFiles.clear();
      allFolders.clear();

      if (isNavigatingForward) {
        folderNavigationStack.add(folderPath);
      }
    });

    try {
      final response = await http.post(Uri.parse(apiUrl), body: {
        'mode': 'files',
        'folderName': folderPath,
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'success') {
          if (data.containsKey('files') && data['files'] is List && data['files'].isNotEmpty) {
            setState(() {
              allFolderFiles = List<String>.from(data['files']);
              accessibleFile = data['accessibleFile'];
            });
          } else if (data.containsKey('subFolders') && data['subFolders'] is Map) {
            final subFoldersMap = data['subFolders'] as Map<String, dynamic>;
            setState(() {
              allFolders = subFoldersMap.entries.map((entry) => {
                'name': entry.value['name'],
                'path': "${folderPath}/${entry.value['path']}",
                'url': entry.value['url'],
              }).toList();
            });
          } else {
            throw Exception("No files or subfolders available.");
          }
        } else {
          throw Exception(data['error'] ?? "Error from server.");
        }
      } else {
        throw Exception("Server returned status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error in fetchFiles: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching files: $e")),
      );
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
        final folderName = folder['name'];
        final iconPath = folderIcons[folderName] ?? 'assets/2025.png';  // fallback icon

        return GestureDetector(
          onTap: () => fetchFiles(folder['path'], isNavigatingForward: true),
          child: SizedBox(
            width: 150,
            height: 100,
            child: Card(
              elevation: 6,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              shadowColor: Colors.black.withOpacity(0.2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F4), // Soft light background
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      iconPath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Text(
                    folderName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
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

      body: currentFolderPath == null
          ? buildFolderGrid()
          : (allFolderFiles.isNotEmpty ? buildFileGrid() : buildFolderGrid()),
      floatingActionButton: folderNavigationStack.isNotEmpty
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            folderNavigationStack.removeLast(); // Remove current folder

            if (folderNavigationStack.isNotEmpty) {
              final previousFolder = folderNavigationStack.last;
              fetchFiles(previousFolder, isNavigatingForward: false);
            } else {
              currentFolderPath = null;
              allFolderFiles.clear();
              fetchFolders(); // Go back to root folders
            }
          });
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: const CircleBorder(),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Color(0xFFFF0000), Color(0xFF710606)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(15),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
        ),
      )
          : null,
    );
  }
}