import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:password_generator/model/passwords.dart';

import '../services/local_storage_service.dart';

/// Narrows the list to what the search box and the username filter ask for.
///
/// Search deliberately looks at the website or app name and nothing else. It
/// used to match the username as well, which meant typing a site name pulled in
/// unrelated entries whose email address happened to contain the same letters —
/// and the more accounts you saved under one address, the worse it got.
/// Finding a site is what search is for; finding an account is what the
/// username filter is for, and the two compose.
List<Passwords> filterPasswords(
  List<Passwords> items, {
  String query = '',
  String? username,
}) {
  final q = query.trim().toLowerCase();
  final user = username?.trim().toLowerCase();

  return items.where((p) {
    if (user != null && p.name.trim().toLowerCase() != user) return false;
    if (q.isNotEmpty && !p.webName.toLowerCase().contains(q)) return false;
    return true;
  }).toList();
}

/// The usernames offered as filter options, in alphabetical order.
///
/// Deduplicated case-insensitively, keeping the spelling of the first entry
/// saved: "Me@example.com" and "me@example.com" are one account to the person
/// reading the list, and offering both as separate filters would hide half of
/// their passwords behind whichever one they picked.
List<String> distinctUsernames(List<Passwords> items) {
  final byLower = <String, String>{};
  for (final p in items) {
    final name = p.name.trim();
    if (name.isEmpty) continue;
    byLower.putIfAbsent(name.toLowerCase(), () => name);
  }
  return byLower.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

class ViewPasswords extends StatefulWidget {
  const ViewPasswords({super.key});

  @override
  State<ViewPasswords> createState() => _ViewPasswordsState();
}

class _ViewPasswordsState extends State<ViewPasswords> {
  final DatabaseService _databaseService = DatabaseService.instance;

  // The loaded list is the single source of truth once it arrives.
  //
  // This used to be a FutureBuilder whose result was second-guessed with
  // `_allItems.isNotEmpty ? _allItems : snapshot.data`, so deleting the last
  // entry emptied the cache, fell back to the original future, and brought
  // every deleted password back on screen. An explicit loaded/error/data state
  // has nowhere to fall back to.
  List<Passwords> _items = const [];
  bool _loaded = false;
  Object? _error;

  final Map<String, bool> _showPwd = {};
  final Map<String, bool> _isEditing = {};

  final Map<String, TextEditingController> _nameCtrl = {};
  final Map<String, TextEditingController> _webNameCtrl = {};
  final Map<String, TextEditingController> _urlCtrl = {};
  final Map<String, TextEditingController> _pwdCtrl = {};

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  /// The username or email currently filtered on, or null for all of them.
  String? _userFilter;

  /// Stands in for "no filter" in the menu. A `PopupMenuItem` with a null value
  /// is read as a dismissal, so onSelected would never fire for it.
  ///
  /// The leading space is what keeps it from colliding with a real username:
  /// every option from [distinctUsernames] is trimmed and non-empty.
  static const String _allUsersValue = ' all';

  @override
  void initState() {
    super.initState();
    _load();
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

  Future<void> _load() async {
    try {
      final fresh = await _databaseService.getAddedPasswords();
      if (!mounted) return;
      setState(() {
        _items = fresh;
        _error = null;
        _loaded = true;
        _pruneUserFilter();
      });
    } catch (e) {
      // Surfaced rather than swallowed: a DatabaseLockedException means the
      // passwords are still there and must not be mistaken for an empty list.
      if (!mounted) return;
      setState(() {
        _error = e;
        _loaded = true;
      });
    }
  }

  /// Drops a username filter that no longer matches anything.
  ///
  /// Renaming or deleting the last entry for an account would otherwise leave
  /// the list filtered to a username that is gone, which reads as "all your
  /// passwords have vanished" with no obvious way back.
  ///
  /// Call from inside setState — it mutates [_userFilter] without notifying.
  void _pruneUserFilter() {
    final current = _userFilter;
    if (current == null) return;
    final stillThere = distinctUsernames(_items)
        .any((u) => u.toLowerCase() == current.toLowerCase());
    if (!stillThere) _userFilter = null;
  }

  String _mask(String pwd) => '•' * (pwd.isEmpty ? 6 : pwd.length.clamp(6, 16));

  void _ensureControllers(Passwords p) {
    _showPwd.putIfAbsent(p.id, () => false);
    _isEditing.putIfAbsent(p.id, () => false);

    _nameCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.name));
    _webNameCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.webName));
    _urlCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.webURL));
    _pwdCtrl.putIfAbsent(p.id, () => TextEditingController(text: p.pwd));
  }

  void _resetControllers(Passwords p) {
    _nameCtrl[p.id]!.text = p.name;
    _webNameCtrl[p.id]!.text = p.webName;
    _urlCtrl[p.id]!.text = p.webURL;
    _pwdCtrl[p.id]!.text = p.pwd;
  }

  void _enterEdit(Passwords p) {
    _resetControllers(p);
    setState(() => _isEditing[p.id] = true);
  }

  void _cancelEdit(Passwords p) {
    _resetControllers(p);
    setState(() => _isEditing[p.id] = false);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveEdit(Passwords p) async {
    final name = _nameCtrl[p.id]!.text.trim();
    final webName = _webNameCtrl[p.id]!.text.trim();
    final url = _urlCtrl[p.id]!.text.trim();
    final pwd = _pwdCtrl[p.id]!.text;

    if (name.isEmpty || webName.isEmpty || pwd.isEmpty) {
      _say('Website, username and password are all required.');
      return;
    }

    await _databaseService.updatePwd(
      id: p.id,
      name: name,
      webName: webName,
      url: url,
      pwd: pwd,
    );

    if (!mounted) return;
    setState(() => _isEditing[p.id] = false);
    await _load();
    _say('Updated');
  }

  /// Deletion is permanent and there is no undo, so it asks first.
  ///
  /// The entry is named in the question rather than "are you sure?", because
  /// the mistake worth catching is deleting the wrong one — and a generic
  /// prompt gives you nothing to notice that with.
  Future<void> _confirmAndDelete(Passwords p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this password?'),
        content: Text(
          '“${p.webName}” for ${p.name} will be removed from this device. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _databaseService.delPwd(p.id, p.name, p.webName, p.webURL, p.pwd);
    if (!mounted) return;

    setState(() {
      _items = _items.where((x) => x.id != p.id).toList();
      _showPwd.remove(p.id);
      _isEditing.remove(p.id);
      _nameCtrl.remove(p.id)?.dispose();
      _webNameCtrl.remove(p.id)?.dispose();
      _urlCtrl.remove(p.id)?.dispose();
      _pwdCtrl.remove(p.id)?.dispose();
      _pruneUserFilter();
    });
    _say('Deleted “${p.webName}”');
  }

  Future<void> _copy(Passwords p) async {
    final messenger = ScaffoldMessenger.of(context);
    final isEditing = _isEditing[p.id] ?? false;
    final toCopy = isEditing ? _pwdCtrl[p.id]!.text : p.pwd;
    await Clipboard.setData(ClipboardData(text: toCopy));
    messenger.showSnackBar(
      const SnackBar(content: Text('Password copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filtered = filterPasswords(
      _items,
      query: _query,
      username: _userFilter,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved passwords'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(124),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _query = v.trim()),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search website or app',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                _filterBar(theme, filtered.length),
              ],
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(theme, filtered),
      ),
    );
  }

  /// The username filter, plus a count so it is obvious something is hidden.
  ///
  /// A menu rather than a row of chips: one address per account adds up fast,
  /// and a wrapping chip row would push the list itself off the screen.
  Widget _filterBar(ThemeData theme, int shown) {
    final users = distinctUsernames(_items);
    final active = _userFilter;
    final isFiltering = active != null;

    final fg = isFiltering
        ? theme.colorScheme.onSecondaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Flexible(
            child: PopupMenuButton<String>(
              tooltip: 'Filter by username or email',
              position: PopupMenuPosition.under,
              // Nothing saved yet means nothing to filter by, and an empty
              // menu that opens is worse than a button that clearly cannot.
              enabled: users.isNotEmpty,
              onSelected: (v) => setState(
                () => _userFilter = v == _allUsersValue ? null : v,
              ),
              itemBuilder: (context) => [
                CheckedPopupMenuItem<String>(
                  value: _allUsersValue,
                  checked: !isFiltering,
                  child: const Text('All usernames'),
                ),
                const PopupMenuDivider(),
                ...users.map(
                  (u) => CheckedPopupMenuItem<String>(
                    value: u,
                    checked: isFiltering && u.toLowerCase() == active.toLowerCase(),
                    child: Text(u, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isFiltering ? theme.colorScheme.secondaryContainer : null,
                  border: Border.all(
                    color: isFiltering
                        ? Colors.transparent
                        : theme.colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_outline, size: 18, color: fg),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        isFiltering ? active : 'All usernames',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(color: fg),
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 20, color: fg),
                  ],
                ),
              ),
            ),
          ),
          if (isFiltering)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Clear filter',
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _userFilter = null),
            ),
          const Spacer(),
          Text(
            // "3 of 12" only says something while something is being hidden.
            isFiltering || _query.isNotEmpty
                ? '$shown of ${_items.length}'
                : '${_items.length} saved',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _body(ThemeData theme, List<Passwords> filtered) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.lock_outline,
              size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 16),
          Text(
            'Could not open your passwords',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '$_error',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.error),
          ),
        ],
      );
    }

    if (filtered.isEmpty) {
      // Distinguished, because "you have none", "none match this search" and
      // "none under this username" want completely different things from the
      // reader — the last two are fixed by clearing something, not by saving
      // a password, and saying the wrong one sends them to the wrong place.
      final searching = _query.isNotEmpty;
      final filtering = _userFilter != null;
      final narrowed = searching || filtering;

      final String headline;
      final String hint;
      if (searching && filtering) {
        headline = 'Nothing matches “$_query” for $_userFilter';
        hint = 'Try a different website, or clear the username filter.';
      } else if (searching) {
        headline = 'Nothing matches “$_query”';
        hint = 'Search looks at the website or app name only.';
      } else if (filtering) {
        headline = 'No passwords for $_userFilter';
        hint = 'Clear the filter to see everything you have saved.';
      } else {
        headline = 'No passwords saved yet';
        hint = 'Generate one on the Generator tab and it will appear here.';
      }

      return ListView(
        padding: const EdgeInsets.all(32),
        children: [
          const SizedBox(height: 48),
          Icon(
            narrowed ? Icons.search_off : Icons.lock_outline,
            size: 56,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            headline,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    for (final p in filtered) {
      _ensureControllers(p);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _card(theme, filtered[index]),
    );
  }

  Widget _card(ThemeData theme, Passwords p) {
    final isShown = _showPwd[p.id] ?? false;
    final isEditing = _isEditing[p.id] ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isEditing ? _editing(theme, p) : _viewing(theme, p, isShown),
      ),
    );
  }

  Widget _viewing(ThemeData theme, Passwords p, bool isShown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                p.webName.isEmpty ? '?' : p.webName.characters.first.toUpperCase(),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.webName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    p.name,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (p.webURL.isNotEmpty && p.webURL != 'No Desc')
                    Text(
                      p.webURL,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            // Destructive and edit actions live in a menu rather than as bare
            // icons beside Copy — Delete sat one tap away from Show, which is
            // how the wrong button gets pressed.
            PopupMenuButton<String>(
              tooltip: 'More actions',
              onSelected: (v) {
                if (v == 'edit') _enterEdit(p);
                if (v == 'delete') _confirmAndDelete(p);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Edit'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error),
                    title: Text('Delete',
                        style: TextStyle(color: theme.colorScheme.error)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  isShown ? p.pwd : _mask(p.pwd),
                  // Monospace so lookalike characters are distinguishable
                  // while reading a password off the screen.
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontFamily: 'monospace',
                    letterSpacing: isShown ? 0.5 : 2,
                  ),
                  maxLines: isShown ? null : 1,
                  overflow: isShown ? null : TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: isShown ? 'Hide' : 'Show',
                icon: Icon(
                    isShown ? Icons.visibility_off : Icons.visibility,
                    size: 20),
                onPressed: () => setState(() => _showPwd[p.id] = !isShown),
              ),
              IconButton(
                tooltip: 'Copy',
                icon: const Icon(Icons.copy, size: 20),
                onPressed: () => _copy(p),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _editing(ThemeData theme, Passwords p) {
    final isShown = _showPwd[p.id] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _webNameCtrl[p.id],
          decoration: const InputDecoration(labelText: 'Website or app'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameCtrl[p.id],
          decoration: const InputDecoration(labelText: 'Username or email'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _urlCtrl[p.id],
          decoration: const InputDecoration(labelText: 'Website URL'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _pwdCtrl[p.id],
          obscureText: !isShown,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: 'Password',
            suffixIcon: IconButton(
              icon: Icon(isShown ? Icons.visibility_off : Icons.visibility),
              tooltip: isShown ? 'Hide' : 'Show',
              onPressed: () => setState(() => _showPwd[p.id] = !isShown),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () => _cancelEdit(p),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => _saveEdit(p),
              child: const Text('Save'),
            ),
          ],
        ),
      ],
    );
  }
}
