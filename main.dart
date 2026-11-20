import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const prayers = {
  'fajr': 'الفجر',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};
const states = ['—', 'في وقتها', 'متأخرة', 'فاتت'];
const dayNames = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];

String keyOf(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(App(prefs));
}

class App extends StatelessWidget {
  final SharedPreferences prefs;
  const App(this.prefs, {super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0F766E);
    return MaterialApp(
      title: 'متتبع العبادة',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      themeMode: ThemeMode.system,
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: Home(prefs),
    );
  }
}

class Home extends StatefulWidget {
  final SharedPreferences prefs;
  const Home(this.prefs, {super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  late Map<String, dynamic> db;
  int tab = 0;
  DateTime sel = DateTime.now();
  DateTime month = DateTime.now();

  int get goal => widget.prefs.getInt('goal') ?? 5;

  @override
  void initState() {
    super.initState();
    final s = widget.prefs.getString('db');
    db = s == null ? {} : Map<String, dynamic>.from(jsonDecode(s));
  }

  Map<String, dynamic> day(String k) => Map<String, dynamic>.from(db[k] ?? {});

  void put(String k, Map<String, dynamic> d) {
    setState(() => db[k] = d);
    widget.prefs.setString('db', jsonEncode(db));
  }

  int pcount(String k) {
    final p = Map<String, dynamic>.from(day(k)['p'] ?? {});
    return p.values.where((v) => v == 1 || v == 2).length;
  }

  int pages(String k) => (day(k)['q'] ?? 0) as int;
  bool qiyam(String k) => day(k)['qi'] == true;

  double score(String k) {
    final s = pcount(k) / 5 * 0.6 +
        (pages(k) / goal).clamp(0.0, 1.0).toDouble() * 0.25 +
        (qiyam(k) ? 0.15 : 0.0);
    return s > 1.0 ? 1.0 : s;
  }

  List<String> lastDays(int n) =>
      List.generate(n, (i) => keyOf(DateTime.now().subtract(Duration(days: i))));

  int streak(bool Function(String) f) {
    var d = DateTime.now();
    if (!f(keyOf(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (f(keyOf(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final pages_ = [today(), calendar(), stats()];
    return Scaffold(
      appBar: AppBar(title: const Text('متتبع العبادة والحياة')),
      body: SafeArea(child: pages_[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'اليوم'),
          NavigationDestination(icon: Icon(Icons.calendar_month), label: 'التقويم'),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'الإحصاءات'),
        ],
      ),
    );
  }

  Widget today() {
    final k = keyOf(sel);
    final d = day(k);
    final p = Map<String, dynamic>.from(d['p'] ?? {});
    final q = pages(k);
    final cs = Theme.of(context).colorScheme;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => sel = sel.subtract(const Duration(days: 1)))),
          Text('${dayNames[sel.weekday - 1]}  $k',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => sel = sel.add(const Duration(days: 1)))),
        ]),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الصلوات ${pcount(k)}/5', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in prayers.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                trailing: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: p[e.key] == 3
                        ? cs.errorContainer
                        : (p[e.key] == 1 || p[e.key] == 2)
                            ? cs.primary
                            : null,
                    foregroundColor: (p[e.key] == 1 || p[e.key] == 2) ? cs.onPrimary : null,
                  ),
                  onPressed: () {
                    final nd = day(k);
                    final np = Map<String, dynamic>.from(nd['p'] ?? {});
                    np[e.key] = (((np[e.key] ?? 0) as int) + 1) % 4;
                    nd['p'] = np;
                    put(k, nd);
                  },
                  child: Text(states[(p[e.key] ?? 0) as int]),
                ),
              ),
          ]),
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('القرآن: $q / $goal صفحات', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: (q / goal).clamp(0.0, 1.0).toDouble()),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final n in [1, 2, 5, -1])
                OutlinedButton(
                  onPressed: () {
                    final nd = day(k);
                    nd['q'] = (q + n) < 0 ? 0 : q + n;
                    put(k, nd);
                  },
                  child: Text(n > 0 ? '+$n' : '$n'),
                ),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('الهدف:'),
              for (final g in [2, 5, 10])
                ChoiceChip(
                  label: Text('$g'),
                  selected: goal == g,
                  onSelected: (_) {
                    widget.prefs.setInt('goal', g);
                    setState(() {});
                  },
                ),
            ]),
          ]),
        ),
      ),
      Card(
        child: SwitchListTile(
          title: const Text('قيام الليل'),
          value: qiyam(k),
          onChanged: (v) {
            final nd = day(k);
            nd['qi'] = v;
            put(k, nd);
          },
        ),
      ),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('صيام ${[1, 4].contains(sel.weekday) ? "(${dayNames[sel.weekday - 1]})" : "تطوع"}',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              emptySelectionAllowed: true,
              segments: const [
                ButtonSegment(value: 0, label: Text('لم أصم')),
                ButtonSegment(value: 1, label: Text('صمت')),
                ButtonSegment(value: 2, label: Text('معذور')),
              ],
              selected: d['f'] == null ? <int>{} : {d['f'] as int},
              onSelectionChanged: (s) {
                final nd = day(k);
                if (s.isEmpty) {
                  nd.remove('f');
                } else {
                  nd['f'] = s.first;
                }
                put(k, nd);
              },
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget calendar() {
    final cs = Theme.of(context).colorScheme;
    final first = DateTime(month.year, month.month, 1);
    final n = DateTime(month.year, month.month + 1, 0).day;
    final off = (first.weekday + 1) % 7;
    final cells = <Widget>[
      for (final h in ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج']) Center(child: Text(h)),
      for (var i = 0; i < off; i++) const SizedBox(),
      for (var i = 1; i <= n; i++)
        GestureDetector(
          onTap: () => setState(() {
            sel = DateTime(month.year, month.month, i);
            tab = 0;
          }),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Color.lerp(cs.surfaceContainerHighest,
                  cs.primary, score(keyOf(DateTime(month.year, month.month, i)))),
              borderRadius: BorderRadius.circular(8),
              border: keyOf(DateTime(month.year, month.month, i)) == keyOf(DateTime.now())
                  ? Border.all(color: cs.tertiary, width: 2)
                  : null,
            ),
            alignment: Alignment.center,
            child: Text('$i'),
          ),
        ),
    ];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => month = DateTime(month.year, month.month - 1))),
        Text('${month.year} / ${month.month}',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => month = DateTime(month.year, month.month + 1))),
      ]),
      GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cells,
      ),
      const Padding(
        padding: EdgeInsets.all(8),
        child: Text('اضغط على أي يوم لفتح سجله. اللون الأغمق = التزام أكبر.'),
      ),
    ]);
  }

  Widget stats() {
    final m = lastDays(30), w = lastDays(7);
    int sum(List<String> ks, int Function(String) f) => ks.fold(0, (a, k) => a + f(k));
    final all = sum(m, pcount);
    final fasted = db.keys.where((k) => day(k)['f'] == 1).toList();
    final mon = fasted.where((k) => DateTime.parse(k).weekday == 1).length;
    final thu = fasted.where((k) => DateTime.parse(k).weekday == 4).length;
    return ListView(padding: const EdgeInsets.all(12), children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الصلوات (آخر 30 يوم): ${(all / 150 * 100).round()}%',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final e in prayers.entries) ...[
              Builder(builder: (_) {
                final c = sum(m, (k) {
                  final v = (day(k)['p'] ?? {})[e.key];
                  return (v == 1 || v == 2) ? 1 : 0;
                });
                return Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(e.value), Text('${(c / 30 * 100).round()}%')]),
                  LinearProgressIndicator(value: c / 30),
                  const SizedBox(height: 6),
                ]);
              }),
            ],
          ]),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('القرآن'),
          subtitle: Text(
              'هذا الأسبوع: ${sum(w, pages)} صفحة\nآخر 30 يوم: ${sum(m, pages)} صفحة (المتوسط ${(sum(m, pages) / 30).toStringAsFixed(1)})\nسلسلة القراءة: ${streak((k) => pages(k) > 0)} يوم'),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('القيام'),
          subtitle: Text(
              'هذا الأسبوع: ${w.where(qiyam).length} ليالي\nآخر 30 يوم: ${m.where(qiyam).length} ليلة\nالسلسلة: ${streak(qiyam)}'),
        ),
      ),
      Card(
        child: ListTile(
          title: const Text('الصيام'),
          subtitle: Text('إثنين: $mon · خميس: $thu · إجمالي أيام الصيام: ${fasted.length}'),
        ),
      ),
    ]);
  }
}
