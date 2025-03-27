import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'loginpage.dart';
import 'package:flutter/services.dart';
class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with SingleTickerProviderStateMixin {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void signupUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      const String signupUrl = "https://esheapp.in/pdf_userapp/signup.php";
      final response = await http.post(
        Uri.parse(signupUrl),
        body: {
          'name': nameController.text.trim(),
          'contact': contactController.text.trim(),
          'password': passwordController.text.trim(),
        },
      );

      setState(() {
        isLoading = false;
      });

      if (response.statusCode == 200) {
        final cleanedResponse = response.body.substring(response.body.indexOf('{'));
        final data = json.decode(cleanedResponse);

        if (data['status'] == 'success') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => LoginPage()),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'])),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error connecting to server. Please try again.")),
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("An unexpected error occurred. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF), // Light background
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),

                    // Logo & Branding
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

                        const SizedBox(height: 5),

                        // "SEED FOR SAFETY"
                        const Text(
                          'SEED FOR SAFETY',
                          style: TextStyle(
                            fontFamily: 'aAtomicMd',
                            fontSize: 43,
                            fontWeight: FontWeight.w900,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 1),

                        // ISO Certification
                        const Text(
                          'ISO 9001:2015 and ISO 21001:2018 Certified Company',
                          style: TextStyle(
                            fontFamily: 'aAtomicMd',
                            fontSize: 13,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),

                    const SizedBox(height: 50),

                    // Title
                    const Text(
                      "Create an Account",
                      style: TextStyle(
                        // fontFamily: 'Typo',
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 30),

                    // Input Fields
                    _buildInputField(
                      label: 'Full Name',
                      controller: nameController,
                      icon: Icons.person,
                      hint: "Enter your full name",
                    ),

                    const SizedBox(height: 16),

                    _buildInputField(
                      label: 'Contact Number',
                      controller: contactController,
                      icon: Icons.phone,
                      hint: "Enter Mobile number",
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _buildPasswordField(
                      label: 'Password',
                      controller: passwordController,
                      hint: "Enter Password",
                      isPasswordVisible: isPasswordVisible,
                      onToggle: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    _buildPasswordField(
                      label: 'Confirm Password',
                      controller: confirmPasswordController,
                      hint: "Re-enter Password",
                      isPasswordVisible: isConfirmPasswordVisible,
                      onToggle: () {
                        setState(() {
                          isConfirmPasswordVisible = !isConfirmPasswordVisible;
                        });
                      },
                    ),

                    const SizedBox(height: 30),

                    // Signup Button
                    isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : ElevatedButton(
                      onPressed: signupUser,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE00800),
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 80),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 6,
                      ),
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Already have an account
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      child: const Text.rich(
                        TextSpan(
                          text: "Already have an account? ",
                          style: TextStyle(color: Colors.black45),
                          children: [
                            TextSpan(
                              text: "Login",
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

                    const SizedBox(height: 30),

                    // Footer
                    const Text(
                      'Powered by Lee Safezone',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.black38,
                        fontStyle: FontStyle.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 6, spreadRadius: 2, offset: Offset(0, 3)),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, color: Color(0xFFE00800)),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.black54, width: 2)),
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.black45),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool isPasswordVisible,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black, // Black label color
          ),
        ),
        const SizedBox(height: 6), // Space between label and TextField

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
          child: TextFormField(
            controller: controller,
            obscureText: !isPasswordVisible, // Show/hide password
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock, color: Color(0xFFE00800)),
              suffixIcon: IconButton(
                icon: Icon(
                  isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: onToggle, // Toggle password visibility
              ),
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