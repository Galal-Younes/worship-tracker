 
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
              ),
          ]),
        ),
      ),
    ];
  }

  List<Widget> workoutView(String k) {
    final list = items(k, 'wo');
    int days(int n) => lastDays(n).where((x) => items(x, 'wo').isNotEmpty).length;
    return [
      box(
        'تمارين اليوم',
        Column(children: [
          for (var i = 0; i < list.length; i++)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${list[i]['n']} (${list[i]['m']})'),
              subtitle: Text(
                  '${list[i]['s']}×${list[i]['r']} · ${list[i]['w']} كجم · ${list[i]['d']} د'),
              trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    list.removeAt(i);
                    setItems(k, 'wo', list);
                  }),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('تسجيل تمرين'),
            onPressed: () async {
              final r = await form('تمرين',
                  ['التمرين', 'العضلة', 'المجموعات', 'العدّات', 'الوزن (كجم)', 'المدة (دقائق)']);
              if (r == null || r[0].isEmpty) return;
              list.add({'n': r[0], 'm': r[1], 's': r[2], 'r': r[3], 'w': r[4], 'd': r[5]});
              setItems(k, 'wo', list);
            },
          ),
        ]),
      ),
      box('انتظامك في التمرين',
          bars({'آخر 7 أيام': days(7) / 7 * 100, 'آخر 30 يوم': days(30) / 30 * 100})),
    ];
  }

  double habitPct(Map h) {
    final ds = List<int>.from(h['d']);
    var due = 0, ok = 0;
    for (final x in lastDays(30)) {
      if (ds.contains(DateTime.parse(x).weekday)) {
        due++;
        if ((day(x)['h'] ?? {})[h['n']] == true) ok++;
      }
    }
    return due == 0 ? 0.0 : ok / due * 100;
  }

  List<Widget> habitsView() {
    final k = keyOf(DateTime.now());
    final hs = habits;
    final done = Map<String, dynamic>.from(day(k)['h'] ?? {});
    return [
      box(
        'عادات اليوم',
        Column(children: [
          for (var i = 0; i < hs.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(hs[i]['n']),
              subtitle: Text('الأيام: ${(hs[i]['d'] as List).length == 7 ? 'يوميا' : (hs[i]['d'] as List).map((d) => dayNames[d - 1]).join('، ')}'),
              value: done[hs[i]['n']] == true,
              onChanged: (v) {
                final nd = day(k);
                final nh = Map<String, dynamic>.from(nd['h'] ?? {});
                nh[hs[i]['n']] = v == true;
                nd['h'] = nh;
                put(k, nd);
              },
              secondary: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    hs.removeAt(i);
                    saveHabits(hs);
                  }),
            ),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('عادة جديدة'),
            onPressed: () async {
              final r = await form('عادة جديدة',
                  ['الاسم (ماء، مشي، قراءة...)', 'الأيام: أرقام من 1 (الإثنين) إلى 7 (الأحد) مثل 1,4 — اتركه فارغا ليوميا']);
              if (r == null || r[0].isEmpty) return;
              var d = r[1].split(',').map((e) => int.tryParse(e.trim())).whereType<int>().where((e) => e >= 1 && e <= 7).toList();
              if (d.isEmpty) d = [1, 2, 3, 4, 5, 6, 7];
              hs.add({'n': r[0], 'd': d});
              saveHabits(hs);
            },
          ),
        ]),
      ),
      if (hs.isNotEmpty)
        box('الالتزام (آخر 30 يوم)', bars({for (final h in hs) h['n'] as String: habitPct(h)})),
    ];
  }

  Future<void> importBackup() async {
    final r = await form('استيراد نسخة احتياطية', ['الصق النص هنا']);
    if (r == null || r[0].isEmpty) return;
    try {
      final o = Map<String, dynamic>.from(jsonDecode(r[0]));
      final nd = Map<String, dynamic>.from(o['db']);
      await widget.prefs.setString('db', jsonEncode(nd));
      await widget.prefs.setString('hb', jsonEncode(o['hb'] ?? []));
      await widget.prefs.setStringList('sn', List<String>.from(o['sn'] ?? sunnahs));
      await widget.prefs.setInt('goal', (o['goal'] ?? 5) as int);
      setState(() => db = nd);
      toast('تم الاستيراد');
    } catch (e) {
      toast('النص غير صالح');
    }
  }

  List<Widget> backupView() => [
        box(
          'نسخة احتياطية',
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
                'بياناتك محفوظة على جهازك فقط. انسخ النسخة وخزنها في ملاحظاتك أو أرسلها لنفسك قبل تغيير الموبايل أو مسح التطبيق.'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('تصدير (نسخ)'),
                onPressed: () async {
                  final data = jsonEncode({
                    'db': db,
                    'hb': habits,
                    'sn': sunnahs,
                    'goal': goal,
                  });
                  await Clipboard.setData(ClipboardData(text: data));
                  toast('تم النسخ. الصقه في مكان آمن.');
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.paste),
                label: const Text('استيراد'),
                onPressed: importBackup,
              ),
            ]),
          ]),
        ),
      ];

  Color tone(double v) => v >= 75 ? Colors.green : (v >= 45 ? Colors.orange : Colors.red);

  Widget bars(Map<String, double> m) => Column(children: [
        for (final e in m.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(e.key), Text('${e.value.round()}%')]),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                    value: e.value / 100, minHeight: 9, color: tone(e.value)),
              ),
            ]),
          ),
      ]);

  Widget box(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      );

  Widget stats() {
    final m = lastDays(30), w = lastDays(14);
    final cs = Theme.of(context).colorScheme;
    int sum(List<String> ks, int Function(String) f) => ks.fold(0, (a, k) => a + f(k));
    double pct(num a, num b) => b == 0 ? 0.0 : (a / b * 100).clamp(0, 100).toDouble();
    final prayer = {
      for (final e in prayers.entries)
        e.value: pct(
            sum(m, (k) {
              final v = (day(k)['p'] ?? {})[e.key];
              return (v == 1 || v == 2) ? 1 : 0;
            }),
            30)
    };
    final md = m.where((k) {
      final wd = DateTime.parse(k).weekday;
      return wd == 1 || wd == 4;
    }).toList();
    final cats = <String, double>{
      'الصلاة': pct(sum(m, pcount), 150),
      'القرآن': pct(m.where((k) => pages(k) >= goal).length, 30),
      'السنن': pct(sum(m, scount), 30 * sunnahs.length),
      'القيام': pct(m.where(qiyam).length, 30),
      'الصيام': pct(md.where((k) => day(k)['f'] == 1).length, md.length),
    };
    final sorted = cats.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.first, worst = sorted.last;
    final hasData = db.isNotEmpty && best.value > 0;
    var maxP = goal.toDouble();
    for (final k in w) {
      if (pages(k) > maxP) maxP = pages(k).toDouble();
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      box(
        'الصورة العامة (آخر 30 يوم)',
        SizedBox(
          height: 250,
          child: CustomPaint(
            size: Size.infinite,
            painter: RadarPainter(cats.values.toList(), cats.keys.toList(), cs.primary,
                cs.outlineVariant, cs.onSurface),
          ),
        ),
      ),
      box(
        'أنت سليم في إيه ومحتاج إيه',
        hasData
            ? Column(children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.thumb_up, color: Colors.green),
                  title: Text('نقطة قوتك: ${best.key} (${best.value.round()}%)'),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: Text('أولى بالاهتمام: ${worst.key} (${worst.value.round()}%)'),
                  subtitle: const Text('ابدأ بخطوة صغيرة فيه، والمهم الاستمرار مش الكمال.'),
                ),
              ])
            : const Text('سجّل يومين أو أكتر وهتظهر لك نقاط قوتك وضعفك هنا من بياناتك الفعلية.'),
      ),
      box('الجوانب (أخضر = ممتاز، برتقالي = متوسط، أحمر = يحتاج اهتمام)', bars(cats)),
      box('كل صلاة على حدة', bars(prayer)),
      box(
        'القرآن: آخر 14 يوم (الأخضر = حققت الهدف)',
        SizedBox(
          height: 120,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final k in w.reversed)
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('${pages(k)}', style: const TextStyle(fontSize: 10)),
                  Container(
                    height: pages(k) / maxP * 80,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: pages(k) >= goal ? Colors.green : cs.primary.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      box(
        'سلاسل متتالية',
        Text('القرآن: ${streak((k) => pages(k) > 0)} يوم · القيام: ${streak(qiyam)} ليلة'),
      ),
    ]);
  }
}

class RadarPainter extends CustomPainter {
  final List<double> v;
  final List<String> l;
  final Color fill, grid, text;
  RadarPainter(this.v, this.l, this.fill, this.grid, this.text);

  @override
  void paint(Canvas c, Size s) {
    final ctr = Offset(s.width / 2, s.height / 2);
    final r = s.height / 2 - 34;
    final n = v.length;
    Offset pt(int i, double f) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      return ctr + Offset(math.cos(a), math.sin(a)) * (r * f);
    }

    final gp = Paint()
      ..style = PaintingStyle.stroke
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75, 1.0]) {
      final p = Path();
      for (var i = 0; i < n; i++) {
        final o = pt(i, f);
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      p.close();
      c.drawPath(p, gp);
    }
    for (var i = 0; i < n; i++) {
      c.drawLine(ctr, pt(i, 1), gp);
    }
    final p = Path();
    for (var i = 0; i < n; i++) {
      final o = pt(i, v[i] / 100);
      if (i == 0) {
        p.moveTo(o.dx, o.dy);
      } else {
        p.lineTo(o.dx, o.dy);
      }
    }
    p.close();
    c.drawPath(p, Paint()..color = fill.withOpacity(0.3));
    c.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = fill
          ..strokeWidth = 2.5);
    for (var i = 0; i < n; i++) {
      final tp = TextPainter(
        text: TextSpan(text: '${l[i]} ${v[i].round()}%', style: TextStyle(color: text, fontSize: 12)),
        textDirection: TextDirection.rtl,
      )..layout();
      tp.paint(c, pt(i, 1.2) - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(RadarPainter o) => true;
}
