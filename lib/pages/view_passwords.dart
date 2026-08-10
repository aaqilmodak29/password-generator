import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:password_generator/model/passwords.dart';
import '../services/local_storage_service.dart';

class ViewPasswords extends StatefulWidget {
  const ViewPasswords({super.key});

  @override
  State<ViewPasswords> createState() => _ViewPasswordsState();
}

class _ViewPasswordsState extends State<ViewPasswords> {
  final DatabaseService _databaseService = DatabaseService.instance;
  late Future<List<Passwords>> _pwdFuture;

  final Map<String, bool> _showPwd = {};

  final Map<String, bool> _isEditing = {};

  final Map<String, TextEditingController> _nameCtrl = {};
  final Map<String, TextEditingController> _webNameCtrl = {};
  final Map<String, TextEditingController> _urlCtrl = {};
  final Map<String, TextEditingController> _pwdCtrl = {};

  final TextEditingController _searchCtrl = TextEditingController();
  List<Passwords> _allItems = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _pwdFuture = _databaseService.getAddedPasswords().then((list) {
      _allItems = list;
      return list;
    });
  }

  @override
  void dispose() {
    for (final c in _nameCtrl.values) {
      c.dispose();
    }
    for (final c in _webNameCtrl.values) {
      c.dispose();
    }
    for (final c in _urlCtrl.values) {
      c.dispose();
    }
    for (final c in _pwdCtrl.values) {
      c.dispose();
    }
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final fresh = await _databaseService.getAddedPasswords();
    setState(() {
      _allItems = fresh;
    });
  }

  String _mask(String pwd) {
    return '•' * (pwd.isEmpty ? 6 : (pwd.length.clamp(6, 16)));
  }

  void _ensureControllers(Passwords p) {
    _showPwd.putIfAbsent(p.id, () => false);
    _isEditing.putIfAbsent(p.id, () => false);

    _nameCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.name));
    _webNameCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.webName));
    _urlCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.webURL));
    _pwdCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.pwd));
  }

  void _enterEdit(Passwords p) {
    _nameCtrl[p.id]!.text = p.name;
    _webNameCtrl[p.id]!.text = p.webName;
    _urlCtrl[p.id]!.text = p.webURL;
    _pwdCtrl[p.id]!.text = p.pwd;

    setState(() => _isEditing[p.id] = true);
  }

  void _cancelEdit(Passwords p) {
    _nameCtrl[p.id]!.text = p.name;
    _webNameCtrl[p.id]!.text = p.webName;
    _urlCtrl[p.id]!.text = p.webURL;
    _pwdCtrl[p.id]!.text = p.pwd;

    setState(() => _isEditing[p.id] = false);
  }

  Future<void> _saveEdit(Passwords p) async {
    final name = _nameCtrl[p.id]!.text.trim();
    final webName = _webNameCtrl[p.id]!.text.trim();
    final url = _urlCtrl[p.id]!.text.trim();
    final pwd = _pwdCtrl[p.id]!.text;

    // simple validation
    if (name.isEmpty || webName.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    await _databaseService.updatePwd(
      id: p.id,
      name: name,
      webName: webName,
      url: url,
      pwd: pwd,
    );

    setState(() {
      _isEditing[p.id] = false;
      _pwdFuture = _databaseService.getAddedPasswords();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Updated")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Saved Passwords"),
        centerTitle: true,
      ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: "Search by website/app name...",
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: FutureBuilder<List<Passwords>>(
                  future: _pwdFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              "Error: ${snapshot.error}",
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      );
                    }

                    // Use cached list if available
                    final items = _allItems.isNotEmpty ? _allItems : (snapshot.data ?? []);

                    // Filter by website/app name
                    final filtered = _query.isEmpty
                        ? items
                        : items
                        .where((p) => p.webName.toLowerCase().contains(_query))
                        .toList();

                    if (filtered.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 80),
                          Center(child: Text("No matching passwords found.")),
                        ],
                      );
                    }

                    // ensure maps/controllers exist for filtered items
                    for (final p in filtered) {
                      _ensureControllers(p);
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isShown = _showPwd[p.id] ?? false;
                        final isEditing = _isEditing[p.id] ?? false;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title (Website/App)
                                isEditing
                                    ? TextField(
                                  controller: _webNameCtrl[p.id],
                                  decoration: const InputDecoration(
                                    labelText: "Website/App name",
                                    isDense: true,
                                  ),
                                )
                                    : Text(
                                  p.webName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),

                                const SizedBox(height: 10),

                                // Username
                                isEditing
                                    ? TextField(
                                  controller: _nameCtrl[p.id],
                                  decoration: const InputDecoration(
                                    labelText: "Username / Email",
                                    isDense: true,
                                  ),
                                )
                                    : Text("User: ${p.name}"),

                                const SizedBox(height: 8),

                                // URL
                                isEditing
                                    ? TextField(
                                  controller: _urlCtrl[p.id],
                                  decoration: const InputDecoration(
                                    labelText: "Website URL",
                                    isDense: true,
                                  ),
                                )
                                    : Text("URL: ${p.webURL}"),

                                const SizedBox(height: 10),

                                // Password (make it fully visible)
                                if (isEditing) ...[
                                  TextField(
                                    controller: _pwdCtrl[p.id],
                                    decoration: const InputDecoration(
                                      labelText: "Password",
                                      isDense: true,
                                    ),
                                    obscureText: !isShown,
                                  ),
                                ] else ...[
                                  Text(
                                    "Password:",
                                    style: Theme.of(context).textTheme.labelMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  SelectableText(
                                    isShown ? p.pwd : _mask(p.pwd),
                                    // allow wrapping / full visibility
                                  ),
                                ],

                                const SizedBox(height: 8),

                                // Actions row 1 (Edit/Delete or Save/Cancel + Delete)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (!isEditing)
                                      IconButton(
                                        tooltip: "Edit",
                                        icon: const Icon(Icons.edit_outlined),
                                        onPressed: () => _enterEdit(p),
                                      )
                                    else ...[
                                      IconButton(
                                        tooltip: "Save",
                                        icon: const Icon(Icons.check),
                                        onPressed: () => _saveEdit(p),
                                      ),
                                      IconButton(
                                        tooltip: "Cancel",
                                        icon: const Icon(Icons.close),
                                        onPressed: () => _cancelEdit(p),
                                      ),
                                    ],
                                    IconButton(
                                      tooltip: "Delete",
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        await _databaseService.delPwd(
                                          p.id,
                                          p.name,
                                          p.webName,
                                          p.webURL,
                                          p.pwd,
                                        );

                                        setState(() {
                                          _allItems.removeWhere((x) => x.id == p.id);

                                          _showPwd.remove(p.id);
                                          _isEditing.remove(p.id);

                                          _nameCtrl.remove(p.id)?.dispose();
                                          _webNameCtrl.remove(p.id)?.dispose();
                                          _urlCtrl.remove(p.id)?.dispose();
                                          _pwdCtrl.remove(p.id)?.dispose();
                                        });
                                      },
                                    ),
                                  ],
                                ),

                                // Actions row 2 (below): Show/Copy
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: Icon(isShown ? Icons.visibility_off : Icons.visibility),
                                      label: Text(isShown ? "Hide" : "Show"),
                                      onPressed: () => setState(() => _showPwd[p.id] = !isShown),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      icon: const Icon(Icons.copy),
                                      label: const Text("Copy"),
                                      onPressed: () async {
                                        // Resolved before the await: afterwards
                                        // this builder's context may be gone,
                                        // and the State's `mounted` says
                                        // nothing about it.
                                        final messenger = ScaffoldMessenger.of(context);
                                        final toCopy = isEditing ? _pwdCtrl[p.id]!.text : p.pwd;
                                        await Clipboard.setData(ClipboardData(text: toCopy));
                                        messenger.showSnackBar(
                                          const SnackBar(content: Text("Password copied")),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
    );
  }
}
