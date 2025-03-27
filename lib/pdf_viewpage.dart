import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'main.dart'; // Import the ThemeProvider
import 'package:shared_preferences/shared_preferences.dart';

class PdfViewerPage extends StatefulWidget {
  final String pdfUrl;

  PdfViewerPage({required this.pdfUrl});

  @override
  _PdfViewerPageState createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  String? localFilePath;
  bool isDownloading = true;
  String errorMessage = '';
  double downloadProgress = 0.0;
  int currentPage = 0;
  int totalPages = 0;
  bool isReady = false;
  late PDFViewController pdfController;
  String? userName = " "; // Default name for unapproved users

  @override
  void initState() {
    super.initState();
    downloadPdfWithProgress(widget.pdfUrl);
    getLocalUserName();
    fetchUserName();
  }

  Future<void> downloadPdfWithProgress(String url) async {
    try {
      final response =
      await http.Client().send(http.Request('GET', Uri.parse(url)));

      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/temp.pdf');

        final total = response.contentLength ?? 0;
        int downloaded = 0;

        final sink = file.openWrite();
        await response.stream.listen((chunk) {
          downloaded += chunk.length;
          sink.add(chunk);

          setState(() {
            downloadProgress = downloaded / total;
          });
        }).asFuture();

        await sink.close();

        setState(() {
          localFilePath = file.path;
          isDownloading = false;
        });
      } else {
        throw Exception("Failed to download PDF. Status Code: ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        errorMessage = "Failed to download PDF: $e";
        isDownloading = false;
      });
    }
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

// Function to retrieve locally stored username
  Future<void> getLocalUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? storedName = prefs.getString('username');

    setState(() {
      userName = storedName ?? "Guest"; // Use stored name if available
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      extendBodyBehindAppBar: true, // Allows content behind AppBar
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100.0), // Increased AppBar height
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0, // Remove shadow for clean UI
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF4500), Color(0xFF5B0000)], // Red to Dark Maroon
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28), // Back Arrow
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "SEED FOR SAFETY",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                userName ?? "Guest",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF005F9E), // Deep Blue
                  Color(0xFF0073CC), // Lighter Blue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // Show Download Progress
          if (isDownloading)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(value: downloadProgress, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    "${(downloadProgress * 100).toStringAsFixed(0)}% Downloaded",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            )
          // Show Error Message
          else if (errorMessage.isNotEmpty)
            Center(
              child: Text(
                errorMessage,
                style: const TextStyle(color: Colors.red, fontSize: 16),
              ),
            )
          // PDF Viewer
          else
            Padding(
              padding: const EdgeInsets.only(top: 100), // Ensures UI starts below AppBar
              child: Stack(
                children: [
                  PDFView(
                    filePath: localFilePath,
                    enableSwipe: true,
                    swipeHorizontal: true, // ✅ Enable horizontal swiping for better page-by-page navigation
                    pageSnap: true, // ✅ Ensures pages snap to center one-by-one
                    pageFling: true, // ✅ Smooth transition between pages
                    autoSpacing: false, // ✅ Removes auto spacing to keep pages centered
                    nightMode: themeProvider.isDarkMode,
                    fitPolicy: FitPolicy.WIDTH, // ✅ Keeps the pages centered within the screen
                    onRender: (pages) {
                      setState(() {
                        totalPages = pages!;
                        isReady = true;
                      });
                    },
                    onViewCreated: (PDFViewController controller) {
                      pdfController = controller;
                    },
                    onPageChanged: (current, total) {
                      setState(() {
                        currentPage = current!;
                      });
                    },
                    onError: (error) {
                      setState(() {
                        errorMessage = error.toString();
                      });
                    },
                    onPageError: (page, error) {
                      setState(() {
                        errorMessage = "Error on page $page: $error";
                      });
                    },
                  ),



                  // Loading Indicator
                  if (!isReady && errorMessage.isEmpty)
                    const Center(child: CircularProgressIndicator(color: Colors.white)),

                  // PDF Controls
                  if (totalPages > 0 && errorMessage.isEmpty)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Column(
                        children: [
                          // Page Slider
                          Slider(
                            activeColor: Colors.red,
                            inactiveColor: Colors.red,
                            value: currentPage.toDouble(),
                            min: 0,
                            max: (totalPages - 1).toDouble(),
                            onChanged: (value) async {
                              int page = value.toInt();
                              await pdfController.setPage(page);
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Page ${currentPage + 1} of $totalPages",
                                style: const TextStyle(color: Colors.black),
                              ),
                              Row(
                                children: [
                                  FloatingActionButton.small(
                                    heroTag: "prevPage",
                                    onPressed: () async {
                                      if (currentPage > 0) {
                                        await pdfController.setPage(currentPage - 1);
                                      }
                                    },
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    shape: const CircleBorder(),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFF4500), Color(0xFF5B0000)], // Red to Dark Maroon
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FloatingActionButton.small(
                                    heroTag: "nextPage",
                                    onPressed: () async {
                                      if (currentPage < totalPages - 1) {
                                        await pdfController.setPage(currentPage + 1);
                                      }
                                    },
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    shape: const CircleBorder(),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [Color(0xFFFF4500), Color(0xFF5B0000)], // Red to Dark Maroon
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(12),
                                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
