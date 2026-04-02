import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_session.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final supabase = Supabase.instance.client;

  final emailController = TextEditingController();
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();

  String selectedRole = 'helper';

  bool loading = false;

  Future<void> addUser() async {
    final email = emailController.text.trim();
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();

    if (email.isEmpty || firstName.isEmpty) return;

    setState(() => loading = true);

    try {
      // 1️⃣ Create auth user
      final response = await supabase.auth.admin.createUser(
        AdminUserAttributes(
          email: email,
          password: 'Temp1234!',
          emailConfirm: true,
        ),
      );

      final userId = response.user!.id;

      // 2️⃣ Create profile (THIS feeds your Driver name)
      await supabase.from('profiles').insert({
        'user_id': userId,
        'name': '$firstName $lastName',
      });

      // 3️⃣ Create app_user (role + business)
      await supabase.from('app_users').insert({
        'id': userId,
        'business_id': AppSession().businessId,
        'role': selectedRole,
      });

      // 4️⃣ OPTIONAL: create person (recommended)
      await supabase.from('people').insert({
        'first_name_1st': firstName,
        'last_name_1st': lastName,
        'email_1st': email,
        'user_id': userId, // 🔥 link
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User added successfully')),
      );

      emailController.clear();
      firstNameController.clear();
      lastNameController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSession();

    if (!session.isAdmin) {
     return Scaffold(
        appBar: AppBar(
          title: const Text("Manage Users"),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text("Only admins can manage users"),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Manage Users")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(
                labelText: "First Name",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(
                labelText: "Last Name",
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: "Email",
              ),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField(
              value: selectedRole,
              items: const [
                DropdownMenuItem(value: 'helper', child: Text('Helper')),
                DropdownMenuItem(value: 'owner', child: Text('Owner')),
              ],
              onChanged: (value) {
                setState(() {
                  selectedRole = value.toString();
                });
              },
              decoration: const InputDecoration(labelText: "Role"),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: loading ? null : addUser,
              child: loading
                  ? const CircularProgressIndicator()
                  : const Text("Add User"),
            ),
          ],
        ),
      ),
    );
  }
}