import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  List<String> get sunnahs =>
      widget.prefs.getStringList('sn') ??
      ['سنن الرواتب', 'الوتر', 'الضحى', 'أذكار الصباح', 'أذكار المساء', 'أذكار النوم'];

  int scount(String k) {
    final s = Map<String, dynamic>.from(day(k)['s'] ?? {});
    return sunnahs.where((x) => s[x] == true).length;
  }

  Future<void> addSunnah() async {
    final c = TextEditingController();
    final t = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('سنة / ذكر جديد'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('إضافة'))
        ],
      ),
    );
    if (t != null && t.isNotEmpty && !sunnahs.contains(t)) {
      await widget.prefs.setStringList('sn', [...sunnahs, t]);
      setState(() {});
    }
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
    final pages_ = [today(), calendar(), stats(), more()];
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
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'المزيد'),
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('السنن والأذكار ${scount(k)}/${sunnahs.length}',
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(icon: const Icon(Icons.add), onPressed: addSunnah),
            ]),
            for (final s in sunnahs)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s),
                value: (d['s'] ?? {})[s] == true,
                onChanged: (v) {
                  final nd = day(k);
                  final ns = Map<String, dynamic>.from(nd['s'] ?? {});
                  ns[s] = v == true;
                  nd['s'] = ns;
                  put(k, nd);
                },
              ),
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

  int sub = 0;

  List get habits => jsonDecode(widget.prefs.getString('hb') ?? '[]');

  void saveHabits(List h) {
    widget.prefs.setString('hb', jsonEncode(h));
    setState(() {});
  }

  void toast(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  Future<List<String>?> form(String title, List<String> labels) {
    final cs = [for (final _ in labels) TextEditingController()];
    return showDialog<List<String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var i = 0; i < labels.length; i++)
              TextField(controller: cs[i], decoration: InputDecoration(labelText: labels[i])),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, [for (final c in cs) c.text.trim()]),
              child: const Text('حفظ'))
        ],
      ),
    );
  }

  Future<String?> pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  int mins(String s) {
    final p = s.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  List<Map<String, dynamic>> items(String k, String f) => List<Map<String, dynamic>>.from(
      (day(k)[f] ?? []).map((e) => Map<String, dynamic>.from(e)));

  void setItems(String k, String f, List l) {
    final nd = day(k);
    nd[f] = l;
    put(k, nd);
  }

  Widget dateBar() => Card(
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => sel = sel.subtract(const Duration(days: 1)))),
          Text('${dayNames[sel.weekday - 1]}  ${keyOf(sel)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => sel = sel.add(const Duration(days: 1)))),
        ]),
      );

  Widget more() {
    final k = keyOf(sel);
    const names = ['مذاكرة', 'نوم', 'تمارين', 'عادات', 'نسخ احتياطي'];
    final body = [studyView(k), sleepView(k), workoutView(k), habitsView(), backupView()][sub];
    return ListView(padding: const EdgeInsets.all(12), children: [
      Wrap(spacing: 8, children: [
        for (var i = 0; i < names.length; i++)
          ChoiceChip(
              label: Text(names[i]), selected: sub == i, onSelected: (_) => setState(() => sub = i)),
      ]),
      if (sub < 3) dateBar(),
      ...body,
    ]);
  }

  List<Widget> studyView(String k) {
    final list = items(k, 'st');
    final m = lastDays(30), w = lastDays(7);
    int tot(List<String> ks) =>
        ks.fold(0, (a, x) => a + items(x, 'st').fold(0, (b, s) => b + (s['min'] as int)));
    final sj = <String, double>{};
    for (final x in m) {
      for (final s in items(x, 'st')) {
        sj[s['sub'] as String] = (sj[s['sub'] as String] ?? 0.0) + (s['min'] as int);
      }
    }
    final t = sj.values.fold(0.0, (a, b) => a + b);
    return [
      box(
        'جلسات المذاكرة',
        Column(children: [
          for (var i = 0; i < list.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${list[i]['sub']} — ${list[i]['min']} د'),
              trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    list.removeAt(i);
                    setItems(k, 'st', list);
                  }),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('إضافة جلسة'),
            onPressed: () async {
              final r = await form('جلسة مذاكرة', ['المادة', 'المدة بالدقائق']);
              final mm = r == null ? null : int.tryParse(r[1]);
              if (r == null || r[0].isEmpty || mm == null) return;
              list.add({'sub': r[0], 'min': mm});
              setItems(k, 'st', list);
            },
          ),
        ]),
      ),
      box(
        'الساعات',
        Text(
            'اليوم ${(tot([k]) / 60).toStringAsFixed(1)} · الأسبوع ${(tot(w) / 60).toStringAsFixed(1)} · الشهر ${(tot(m) / 60).toStringAsFixed(1)}'),
      ),
      if (t > 0)
        box('توزيع المواد (30 يوم)', bars({for (final e in sj.entries) e.key: e.value / t * 100})),
    ];
  }

  void saveSleep(String k, {String? f, String? t, int? q}) {
    final nd = day(k);
    final sl = Map<String, dynamic>.from(nd['sl'] ?? {});
    if (f != null) sl['f'] = f;
    if (t != null) sl['t'] = t;
    if (q != null) sl['q'] = q;
    if (sl['f'] != null && sl['t'] != null) {
      sl['h'] = ((mins(sl['t']) - mins(sl['f']) + 1440) % 1440) / 60;
    }
    nd['sl'] = sl;
    put(k, nd);
  }

  List<Widget> sleepView(String k) {
    final sl = Map<String, dynamic>.from(day(k)['sl'] ?? {});
    final w = lastDays(7).reversed.toList();
    double hrs(String x) => ((day(x)['sl'] ?? {})['h'] ?? 0).toDouble();
    final withData = lastDays(30).where((x) => hrs(x) > 0).toList();
    final avg =
        withData.isEmpty ? 0.0 : withData.fold(0.0, (a, x) => a + hrs(x)) / withData.length;
    return [
      box(
        'نوم الليلة المنتهية في هذا اليوم',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('نمت: ${sl['f'] ?? '—'}   ·   صحيت: ${sl['t'] ?? '—'}'),
          if (sl['h'] != null) Text('المدة: ${(sl['h'] as num).toStringAsFixed(1)} ساعة'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () async {
                  final t = await pickTime();
                  if (t != null) saveSleep(k, f: t);
                },
                child: const Text('وقت النوم')),
            OutlinedButton(
                onPressed: () async {
                  final t = await pickTime();
                  if (t != null) saveSleep(k, t: t);
                },
                child: const Text('وقت الاستيقاظ')),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            const Text('الجودة:'),
            for (var q = 1; q <= 5; q++)
              ChoiceChip(
                  label: Text('$q'), selected: sl['q'] == q, onSelected: (_) => saveSleep(k, q: q)),
          ]),
        ]),
      ),
      box(
        'آخر 7 أيام (ساعات) — المتوسط ${avg.toStringAsFixed(1)} (الأخضر = 7 إلى 9)',
        SizedBox(
          height: 110,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final x in w)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(hrs(x) > 0 ? hrs(x).toStringAsFixed(1) : '-',
                      style: const TextStyle(fontSize: 10)),
                  Container(
                    height: hrs(x) / 12 * 70,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: hrs(x) >= 7 && hrs(x) <= 9 ? Colors.green : Colors.orange,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ]),
 .chevron_left),
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
