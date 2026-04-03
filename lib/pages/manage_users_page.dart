
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/app_user.dart';

class ManageUsersPage extends StatefulWidget {
  const ManageUsersPage({super.key});

  @override
  State<ManageUsersPage> createState() => _ManageUsersPageState();
}

class _ManageUsersPageState extends State<ManageUsersPage> {
  final supabase = Supabase.instance.client;

  List users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    final data = await supabase
        .from('app_users')
        .select()
        .order('created_at');

    setState(() {
      users = data;
      loading = false;
    });
  }

  void editUser(Map user) {
    final firstNameController =
        TextEditingController(text: user['first_name'] ?? '');
    final lastNameController =
        TextEditingController(text: user['last_name'] ?? '');
    final phoneController =
        TextEditingController(text: user['phone'] ?? '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user['email'] ?? ''),

            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: 'First Name'),
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: 'Last Name'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('app_users').update({
                'first_name': firstNameController.text,
                'last_name': lastNameController.text,
                'phone': phoneController.text,
              }).eq('id', user['id']);

              if (context.mounted) Navigator.pop(context);

              fetchUsers();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }


  Future<void> updateUser(String id, Map values) async {
    await supabase.from('app_users').update(values).eq('id', id);
    fetchUsers();
  }

  Future<void> deleteUser(String id) async {
    await supabase.from('app_users').delete().eq('id', id);
    fetchUsers();
  }

  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  void inviteUser() {
    final emailController = TextEditingController();
    final firstNameController = TextEditingController();
    final lastNameController = TextEditingController();
    final phoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Invite User'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();

              // 1. Invite user
              await supabase.auth.admin.inviteUserByEmail(email);

              // 2. Wait a moment for trigger to create app_user
              await Future.delayed(const Duration(milliseconds: 500));

              // 3. Get the new user
              final user = await supabase
                  .from('app_users')
                  .select()
                  .eq('email', email)
                  .maybeSingle();

              if (user != null) {
                // 4. Update with name + phone
                await supabase.from('app_users').update({
                  'first_name': firstNameController.text,
                  'last_name': lastNameController.text,
                  'phone': phoneController.text,
                }).eq('id', user['id']);
              }

              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Send Invite'),
          ),
        ],
      ),
    );
  }

  Widget roleSwitch(String label, bool value, Function(bool) onChanged) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppUser.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Access denied')),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: inviteUser,
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, i) {
                final user = users[i];
              return GestureDetector(
                onTap: () => editUser(user),
                child: Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if ((user['first_name'] ?? '').isNotEmpty ||
                                    (user['last_name'] ?? '').isNotEmpty)
                                  Text(
                                    '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  )
                                else
                                  Text(
                                    user['email'] ?? user['id'],
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),

                                const SizedBox(height: 4),

                                // Only show email IF name exists
                                if ((user['first_name'] ?? '').isNotEmpty ||
                                    (user['last_name'] ?? '').isNotEmpty)
                                  Text(user['email'] ?? ''),

                                if ((user['phone'] ?? '').isNotEmpty)
                                  Text(user['phone']),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(user['email'] ?? ''),
                            Text(user['phone'] ?? ''),
                          ],
                        ),

                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 10,
                          children: [
                            roleSwitch(
                              'Admin',
                              user['is_admin'] ?? false,
                              (v) => updateUser(user['id'], {'is_admin': v}),
                            ),
                            roleSwitch(
                              'Breeder',
                              user['is_breeder'] ?? false,
                              (v) =>
                                  updateUser(user['id'], {'is_breeder': v}),
                            ),
                            roleSwitch(
                              'Helper',
                              user['is_helper'] ?? false,
                              (v) =>
                                  updateUser(user['id'], {'is_helper': v}),
                            ),
                            roleSwitch(
                              'Driver',
                              user['is_driver'] ?? false,
                              (v) =>
                                  updateUser(user['id'], {'is_driver': v}),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),


                        Row(
                          children: [
                            TextButton(
                              onPressed: () {
                                resetPassword(user['email'] ?? '');
                              },
                              child: const Text('Reset PW'),
                            ),
                            TextButton(
                              onPressed: () {
                                deleteUser(user['id']);
                              },
                              child: const Text('Delete'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
              },
            ),
    );
  }
}