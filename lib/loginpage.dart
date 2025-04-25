import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';
import 'PdfListPage.dart';
import 'UserListPage.dart'; // Import UserListPage
import 'package:flutter/services.dart'; // Import for input formatters
class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  TextEditingController contactController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordVisible = false;
  @override
  void initState() {
    super.initState();

    // Initialize the animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // Start the fade animation
    _animationController.forward();

    // Call auto-login
    autoLogin();
  }


  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<bool> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> autoLogin() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? contact = prefs.getString('contact');
      String? password = prefs.getString('password');

      if (contact != null && password != null) {
        // Set the saved credentials to the text controllers
        contactController.text = contact;
        passwordController.text = password;

        // Attempt auto-login
        setState(() {
          isLoading = true;
        });

        bool isConnected = await checkConnectivity();
        if (!isConnected) {
          setState(() {
            isLoading = false;
          });
          // Notify the user of offline mode or handle accordingly
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text("No internet connection. Auto-login failed.")),
          );
          return;
        }

        // Perform the login request
        var response = await http.post(
          Uri.parse('https://esheapp.in/pdf_userapp/login.php'),
          body: {
            'contact': contact.trim(),
            'password': password.trim(),
          },
        );

        setState(() {
          isLoading = false;
        });

        final cleanedResponse = response.body.substring(
            response.body.indexOf('{'));
        var data = json.decode(cleanedResponse);

        if (data['status'] == 'success') {
          // Navigate based on user type
          bool isApproved = data['isApproved'] == 1;
          bool isAdmin = data['isAdmin'] == 1;

          if (isAdmin) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => UserListPage()),
            );
          } else if (isApproved) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => PdfListPage(isApproved: true)),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => PdfListPage(isApproved: false)),
            );
          }
        } else {
          // If auto-login fails, show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Handle unexpected errors during auto-login
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auto-login failed: $e")),
      );
    }
  }


  void login({bool autoLogin = false}) async {
    bool isConnected = await checkConnectivity();
    if (!isConnected) {
      if (!autoLogin) {
        showRetryDialog();
      }
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      var response = await http.post(
        Uri.parse('https://esheapp.in/pdf_userapp/login.php'),
        body: {
          'contact': contactController.text.trim(),
          'password': passwordController.text.trim(),
        },
      );

      setState(() {
        isLoading = false;
      });

      final cleanedResponse = response.body.substring(
          response.body.indexOf('{'));
      var data = json.decode(cleanedResponse);

      if (data['status'] == 'success') {
        bool isApproved = data['isApproved'] == 1;
        bool isAdmin = data['isAdmin'] == 1;

        if (!autoLogin) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('contact', contactController.text.trim());
          await prefs.setString('password', passwordController.text.trim());
        }

        if (isAdmin) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => UserListPage()),
          );
        } else if (isApproved) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => PdfListPage(isApproved: true)),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
                builder: (context) => PdfListPage(isApproved: false)),
          );
        }
      } else {
        if (!autoLogin) {
          showDialog(
            context: context,
            builder: (context) =>
                AlertDialog(
                  content: Text(data['message']),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('OK'),
                    ),
                  ],
                ),
          );
        }
      }
    } on SocketException {
      setState(() {
        isLoading = false;
      });

      if (!autoLogin) {
        showRetryDialog();
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      print("Exception: $e");
      if (!autoLogin) {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                content: Text(
                    'An unexpected error occurred. Please try again later.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  void showRetryDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text('Network Error'),
          content: Text(
              'Failed to connect to the server. Please check your internet connection.'),
          actions: [
            ElevatedButton(
              onPressed: () async {
                bool isConnected = await checkConnectivity();
                if (isConnected) {
                  Navigator.of(context).pop();
                  login();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text("Still no network. Please try again.")),
                  );
                }
              },
              child: Text('Retry'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
  void showForgotPasswordDialog() {
    TextEditingController forgotContactController = TextEditingController();
    TextEditingController newPasswordController = TextEditingController();
    TextEditingController confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient background, title, and close icon
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
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
                      Text(
                        "Forgot Password",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Icon(Icons.close, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                // Dialog body
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Mobile Number Field
                        TextField(
                          controller: forgotContactController,
                          decoration: InputDecoration(
                            labelText: "Mobile Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        SizedBox(height: 12),
                        // New Password Field
                        TextField(
                          controller: newPasswordController,
                          decoration: InputDecoration(
                            labelText: "New Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: true,
                        ),
                        SizedBox(height: 12),
                        // Confirm Password Field
                        TextField(
                          controller: confirmPasswordController,
                          decoration: InputDecoration(
                            labelText: "Confirm Password",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          obscureText: true,
                        ),
                      ],
                    ),
                  ),
                ),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel button
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          "Cancel",
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                        ),
                      ),
                      // Submit button
                      ElevatedButton(
                        onPressed: () async {
                          // Validate input fields
                          if (forgotContactController.text.trim().isEmpty ||
                              newPasswordController.text.trim().isEmpty ||
                              confirmPasswordController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Please fill in all fields")),
                            );
                            return;
                          }
                          if (newPasswordController.text.trim() !=
                              confirmPasswordController.text.trim()) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("Passwords do not match")),
                            );
                            return;
                          }
                          // Call the forgot password API
                          try {
                            var response = await http.post(
                              Uri.parse('https://esheapp.in/pdf_userapp/forgot_password.php'),
                              body: {
                                'contact': forgotContactController.text.trim(),
                                'newPassword': newPasswordController.text.trim(),
                                'confirmPassword': confirmPasswordController.text.trim(),
                              },
                            );
                            // Print the server response to the console
                            print("Server response: ${response.body}");

                            // Clean the response by removing any leading debug text
                            String jsonResponse = response.body;
                            if (!jsonResponse.trim().startsWith('{')) {
                              jsonResponse = jsonResponse.substring(jsonResponse.indexOf('{'));
                            }

                            var data = json.decode(jsonResponse);
                            if (data['status'] == 'success') {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Password updated successfully")),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(data['message'])),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("An error occurred. Please try again.")),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Submit",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                )
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
      backgroundColor: const Color(0xFFF8FBFF), // Light background
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero, // Removes extra padding
                child: Align(
                  alignment: Alignment.topCenter, // Moves content to top
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      // Align to top
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Logo
                        Column(
                          children: [
                            Container(
                              height: 120,
                              width: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(15),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/Seed.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 5), // Spacing below the logo

                            // "SEED FOR SAFETY" text using AtomicMd Font
                            const Text(
                              'SEED FOR SAFETY',
                              style: TextStyle(
                                fontFamily: 'aAtomicMd',
                                // Use your custom font if needed
                                fontSize: 43,
                                fontWeight: FontWeight.w900,
                                // fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 1), // Small spacing
                            // Certification text using AtomicMd Font
                            const Text(
                              'ISO 9001:2015 and ISO 21001:2018 Certified Company',
                              style: TextStyle(
                                fontFamily: 'aAtomicMd',
                                // Use your custom font if needed
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),

                        const SizedBox(height: 100),

                        // Welcome Text
                        const Text(
                          'STANDARD DOCS',
                          style: TextStyle(
                            fontFamily: 'Typo',
                            fontSize: 40,
                            // Larger for a premium look
                            fontWeight: FontWeight.w900,
                            // Extra bold for impact
                            letterSpacing: 2.0,
                            // Spaced-out letters for modern style
                            color: Colors.black87, // Professional color
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // const SizedBox(height: 6),
                        // const Text(
                        //   'Login to continue',
                        //   style: TextStyle(fontSize: 16, color: Colors.black54),
                        // ),

                        const SizedBox(height: 30),

                        // Mobile Number Field
                        _buildInputField(
                          label: 'Mobile Number',
                          controller: contactController,
                          icon: Icons.phone,
                          hint: "Enter Mobile number",
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly, // Only numbers allowed
                            LengthLimitingTextInputFormatter(10), // Limit to 10 digits
                          ],
                        ),

                        const SizedBox(height: 16),

// Password Field
                        _buildInputField(
                          label: 'Password',
                          controller: passwordController,
                          icon: Icons.lock,
                          hint: "Enter Password",
                          isPassword: true, // Enables eye icon
                          obscureText: !isPasswordVisible, // Controls visibility
                          onTogglePassword: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible; // Toggle password visibility
                            });
                          },
                        ),

                        const SizedBox(height: 30),

                        // Login Button
                        isLoading
                            ? const CircularProgressIndicator(
                            color: Colors.black87)
                            : ElevatedButton(
                          onPressed: login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE00800),
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 6,
                          ),
                          child: const Text(
                            'Login',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Signup Link
                        GestureDetector(
                          onTap: () {
                            Navigator.pushNamed(context, '/signup');
                          },
                          child: const Text.rich(
                            TextSpan(
                              text: "Don't have an account? ",
                              style: TextStyle(color: Colors.black54),
                              children: [
                                TextSpan(
                                  text: 'Signup',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
// Add this widget where appropriate in your login page's build() method
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: Colors.blue, // Customize as needed
                            ),
                          ),
                        ),

                        const SizedBox(height: 180),

                        // Footer
                        const Text(
                          'Powered by Lee Safezone',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black38,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    bool isPassword = false, // Detects if it's a password field
    VoidCallback? onTogglePassword, // Callback for toggling visibility
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.normal,
              color: Colors.black54),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 6,
                spreadRadius: 2,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            // Hide/show password
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Color(0xFFE00800)),
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: onTogglePassword, // Toggle password visibility
              )
                  : null,
              // No eye icon for mobile field
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.black54, width: 2),
              ),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black45),
            ),
          ),
        ),
      ],
    );
  }
}