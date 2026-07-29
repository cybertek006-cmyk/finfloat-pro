import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';
import 'retailers.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});
  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  String _kind = 'profit';
  bool _allTime = false;

  static const _kinds = [
    ['profit', 'Net Profit'],
    ['daily', 'Day Book'],
    ['cms', 'CMS'],
    ['shop', 'Shop'],
    ['payout', 'Manual Payout'],
    ['charges', 'Bank Charges'],
    ['tds', 'TDS'],
    ['cash', 'Cash'],
    ['wallet', 'Wallet'],
    ['dayclose', 'Day Close'],
    ['retailer', 'Retailer Due'],
    ['rissue', 'Fund Given'],
    ['rrecovery', 'Collection'],
  ];

  String? get _date => _allTime ? null : todayStr();

  Future<_Rep> _build() async {
    final r = Repo.i;
    final d = _date;
    switch (_kind) {
      case 'profit':
        final pr = await r.dayProfit(d);
        final rows = <List<String>>[];
        // Saari services database se — user jo bhi banaye
        for (final sv in await r.services()) {
          final t = await r.serviceTotals('${sv['code']}', d);
          rows.add(['${sv['name']}', 'Auto', sm(t['vol']), money(t['net'])]);
        }
        rows.insert(0, ['CMS', 'Auto', sm(await r.cmsVolume(d)), money(pr.cmsNet)]);
        rows.add(['Distributor', 'Auto', '—', money(pr.distProfit)]);
        rows.add(['Manual payouts', 'Manual', '—', money(pr.manualNet)]);
        rows.add(['Bank deposit charges', 'Auto', '—', '−${money(pr.depositCharges)}']);
        return _Rep('Net Profit Report', ['Source', 'Mode', 'Volume', 'Income'], rows, {
          'Gross income': money(pr.gross),
          'Bank deposit charges': '−${money(pr.depositCharges)}',
          'Total TDS': money(await r.totalTds(d)),
          'NET PROFIT': money(pr.net),
        });

      case 'cms':
        final e = await r.cmsEntries(date: d);
        return _Rep(
          'CMS Report',
          ['Date', 'Party', 'Amount', 'Payout', 'TDS', 'Net'],
          e.map((x) => [
                dmy('${x['date']}'), '${x['party']}',
                sm(numOf(x['amount'])), money(numOf(x['payout'])),
                money(numOf(x['tds'])), money(numOf(x['net'])),
              ]).toList(),
          {
            'Pickups': '${e.length}',
            'Volume': money(sumOf(e, 'amount')),
            'Payout': money(sumOf(e, 'payout')),
            'TDS': money(sumOf(e, 'tds')),
            'Net income': money(sumOf(e, 'net')),
          },
        );

      case 'shop':
        final e = await r.shopEntries(date: d);
        return _Rep(
          'Shop Services Report',
          ['Date', 'Service', 'Amount', 'Qty', 'Payout', 'Charge', 'Net'],
          e.map((x) => [
                dmy('${x['date']}'), '${x['service']}',
                sm(numOf(x['amount'])), '${x['txn_count']}',
                money(numOf(x['payout'])), money(numOf(x['charge'])),
                money(numOf(x['net'])),
              ]).toList(),
          {
            'Entries': '${e.length}',
            'Volume': money(sumOf(e, 'amount')),
            'Charges collected': money(sumOf(e, 'charge')),
            'TDS': money(sumOf(e, 'tds')),
            'Net income': money(sumOf(e, 'net')),
          },
        );

      case 'payout':
        final e = await r.payouts(date: d);
        return _Rep(
          'Manual Payout Report',
          ['Date', 'Company', 'Payout', 'Extra', 'TDS', 'Net'],
          e.map((x) => [
                dmy('${x['date']}'), '${x['company']}',
                money(numOf(x['payout'])), money(numOf(x['extra'])),
                money(numOf(x['tds'])), money(numOf(x['net'])),
              ]).toList(),
          {
            'Entries': '${e.length}',
            'Net': money(sumOf(e, 'net')),
          },
        );

      case 'charges':
        final e = await r.deposits(date: d);
        return _Rep(
          'Bank Deposit Charges (Loss)',
          ['Date', 'Bank', 'Amount', 'Rule', 'Charge'],
          e.map((x) {
            final rate = numOf(x['chg_rate']);
            final rule = rate <= 0
                ? 'Free'
                : (x['chg_mode'] == 'percent' ? '$rate%' : '₹$rate/txn');
            return [
              dmy('${x['date']}'), '${x['bank']}',
              sm(numOf(x['amount'])), rule, money(numOf(x['charge'])),
            ];
          }).toList(),
          {
            'Deposits': '${e.length}',
            'Deposit total': money(sumOf(e, 'amount')),
            'TOTAL LOSS': money(sumOf(e, 'charge')),
          },
        );

      case 'tds':
        final cms = await r.cmsEntries(date: d);
        final shop = await r.shopEntries(date: d);
        final mp = await r.payouts(date: d);
        final rows = <List<String>>[];
        for (final x in cms) {
          rows.add([dmy('${x['date']}'), 'CMS', '${x['party']}', money(numOf(x['tds']))]);
        }
        for (final x in shop) {
          if (numOf(x['tds']) > 0) {
            rows.add([dmy('${x['date']}'), 'Shop', '${x['service']}', money(numOf(x['tds']))]);
          }
        }
        for (final x in mp) {
          rows.add([dmy('${x['date']}'), 'Manual', '${x['company']}', money(numOf(x['tds']))]);
        }
        return _Rep('TDS Report', ['Date', 'Source', 'Detail', 'TDS'], rows, {
          'CMS TDS': money(sumOf(cms, 'tds')),
          'Shop TDS': money(sumOf(shop, 'tds')),
          'Manual TDS': money(sumOf(mp, 'tds')),
          'TOTAL TDS': money(await r.totalTds(d)),
        });

      case 'cash':
        final fl = await r.floats(date: d);
        final dep = await r.deposits(date: d);
        // Services direction ke hisaab se in/out
        final svcRows = <List<String>>[];
        for (final sv in await r.services()) {
          final t = await r.serviceTotals('${sv['code']}', d);
          if ((t['vol'] ?? 0) == 0) continue;
          final isIn = sv['direction'] == 'cashin';
          svcRows.add([
            '${sv['name']}',
            isIn ? money(t['vol']) : '—',
            isIn ? '—' : money(t['vol']),
          ]);
        }
        return _Rep('Cash Flow Report', ['Type', 'In', 'Out'], [
          ['Cash float', money(sumOf(fl, 'amount')), '—'],
          ['CMS collection', money(await r.cmsVolume(d)), '—'],
          ...svcRows,
          ['Bank deposit', '—', money(sumOf(dep, 'amount'))],
        ], {
          'Counter Cash in Hand': money(await r.counterCash()),
        });

      case 'wallet':
        final accs = await r.accounts();
        final rows = <List<String>>[];
        for (final a in accs) {
          rows.add([
            '${a['company']}', '${a['id_no']}',
            '${a['company_mode']}', money(await r.wallet(a['id'] as int)),
          ]);
        }
        return _Rep('Wallet Report', ['Company', 'ID', 'Mode', 'Wallet'], rows, {
          'Total Wallet': money(await r.totalWallet()),
          'Company IDs': '${accs.length}',
        });

      case 'retailer':
        final list = await r.retailers();
        final rows = <List<String>>[];
        var totIssued = 0.0, totRecovered = 0.0, totDue = 0.0, overCount = 0;
        for (final x in list) {
          final id = x['id'] as int;
          final iss = await r.retailerIssued(id);
          final rec = await r.retailerRecovered(id);
          final due = await r.retailerDue(id);
          final lim = numOf(x['credit_limit']);
          if (due > lim) overCount++;
          totIssued += iss;
          totRecovered += rec;
          totDue += due;
          rows.add([
            '${x['name']}', '${x['area'] ?? ''}',
            sm(iss), sm(rec), sm(due), sm(lim),
            due > lim ? 'OVER' : 'OK',
          ]);
        }
        return _Rep(
          'Retailer Outstanding',
          ['Retailer', 'Area', 'Diya', 'Aaya', 'Baaki', 'Limit', 'Status'],
          rows,
          {
            'Retailers': '${list.length}',
            'Total diya': money(totIssued),
            'Total aaya': money(totRecovered),
            'TOTAL OUTSTANDING': money(totDue),
            'Limit cross': '$overCount',
          },
        );

      case 'rissue':
        final e = await r.retailerIssues(date: d);
        return _Rep(
          'Retailer Fund Given',
          ['Date', 'Retailer', 'Company', 'Reference', 'Amount'],
          e.map((x) => [
                dmy('${x['date']}'), '${x['retailer']}', '${x['company']}',
                '${x['ref'] ?? '—'}', money(numOf(x['amount'])),
              ]).toList(),
          {
            'Entries': '${e.length}',
            'Total given': money(sumOf(e, 'amount')),
          },
        );

      case 'rrecovery':
        final e = await r.retailerRecoveries(date: d);
        final byM = await r.recoveryByMethod();
        final sum = <String, String>{};
        byM.forEach((k, v) {
          final m = RMethod.of(k);
          sum[m.name] = money(v);
        });
        sum['TOTAL COLLECTED'] = money(sumOf(e, 'amount'));
        return _Rep(
          'Retailer Collection',
          ['Date', 'Retailer', 'Method', 'Kahan gaya', 'Amount'],
          e.map((x) {
            final m = RMethod.of('${x['method']}');
            return [
              dmy('${x['date']}'), '${x['retailer']}',
              m.name, m.tag, money(numOf(x['amount'])),
            ];
          }).toList(),
          sum,
        );

      case 'dayclose':
        final s = await r.snaps();
        return _Rep(
          'Day Open / Close Report',
          ['Date', 'Type', 'Cash', 'Profit'],
          s.map((x) => [
                dmy('${x['date']}'), '${x['kind']}',
                money(numOf(x['cash'])), money(numOf(x['profit'])),
              ]).toList(),
          {'Snapshots': '${s.length}'},
        );

      default: // daily
        final rows = <List<String>>[];
        for (final x in await r.cmsEntries(date: d)) {
          rows.add(['${x['time']}', 'CMS', '${x['party']}',
            sm(numOf(x['amount'])), money(numOf(x['net']))]);
        }
        for (final x in await r.shopEntries(date: d)) {
          rows.add(['${x['time']}', '${x['service']}', '${x['note'] ?? '—'}',
            sm(numOf(x['amount'])), money(numOf(x['net']))]);
        }
        for (final x in await r.deposits(date: d)) {
          rows.add(['${x['time']}', 'Deposit', '${x['bank']}',
            sm(numOf(x['amount'])), '−${money(numOf(x['charge']))}']);
        }
        final pr = await r.dayProfit(d);
        return _Rep('Day Book', ['Time', 'Type', 'Detail', 'Amount', 'Income'], rows, {
          'Wallet': money(await r.totalWallet()),
          'Counter Cash': money(await r.counterCash()),
          'Gross income': money(pr.gross),
          'Bank charges': '−${money(pr.depositCharges)}',
          'NET PROFIT': money(pr.net),
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          children: [
            for (final k in _kinds)
              Padding(
                padding: const EdgeInsets.only(right: 7, top: 7),
                child: ChoiceChip(
                  label: Text(k[1], style: const TextStyle(fontSize: 12)),
                  selected: _kind == k[0],
                  selectedColor: C.primary,
                  labelStyle: TextStyle(
                      color: _kind == k[0] ? Colors.white : C.text,
                      fontWeight: FontWeight.w600),
                  onSelected: (_) => setState(() => _kind = k[0]),
                ),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          const Text('Period:', style: TextStyle(fontSize: 12, color: C.muted)),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Today', style: TextStyle(fontSize: 11.5)),
            selected: !_allTime,
            onSelected: (_) => setState(() => _allTime = false),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            label: const Text('All time', style: TextStyle(fontSize: 11.5)),
            selected: _allTime,
            onSelected: (_) => setState(() => _allTime = true),
          ),
        ]),
      ),
      Expanded(
        child: FutureBuilder<_Rep>(
          future: _build(),
          builder: (c, s) {
            if (s.hasError) return ErrBox(s.error!);
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final rep = s.data!;
            return ListView(padding: const EdgeInsets.all(14), children: [
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(rep.title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: C.primary)),
                    ),
                    const SizedBox(height: 6),
                    ...rep.summary.entries.map((e) {
                      final big = e.key.contains('NET PROFIT') || e.key.contains('TOTAL');
                      return Row2(e.key, e.value,
                          bold: big, color: big ? C.accent : null);
                    }),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
              if (rep.rows.isEmpty)
                const Empty('📄', 'Koi data nahi',
                    sub: 'Period badalkar dekhein ya entry banayein')
              else
                AppCard(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 38,
                      dataRowMinHeight: 32,
                      dataRowMaxHeight: 40,
                      columnSpacing: 18,
                      headingTextStyle: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700, color: C.primary),
                      dataTextStyle: const TextStyle(fontSize: 11),
                      columns: rep.head.map((h) => DataColumn(label: Text(h))).toList(),
                      rows: rep.rows
                          .take(60)
                          .map((r) => DataRow(
                              cells: r.map((x) => DataCell(Text(x))).toList()))
                          .toList(),
                    ),
                  ),
                ),
              if (rep.rows.length > 60)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text('Pehle 60 rows dikhaye. Export mein poora data.',
                      style: const TextStyle(fontSize: 11, color: C.muted)),
                ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => _pdf(rep, false),
                    child: const Text('📄 PDF', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.accent),
                    onPressed: () => _csv(rep),
                    child: const Text('📊 Excel', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pdf(rep, true),
                    child: const Text('🖨️', style: TextStyle(fontSize: 12.5)),
                  ),
                ),
              ]),
            ]);
          },
        ),
      ),
    ]);
  }

  Future<pw.Document> _doc(_Rep rep) async {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (c) => c.pageNumber != 1
          ? pw.SizedBox()
          : pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 8),
              decoration: const pw.BoxDecoration(
                  border: pw.Border(
                      bottom: pw.BorderSide(
                          color: PdfColor.fromInt(0xFF0D2A5C), width: 1.4))),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('Digitronic Services',
                        style: pw.TextStyle(
                            fontSize: 15,
                            fontWeight: pw.FontWeight.bold,
                            color: const PdfColor.fromInt(0xFF0D2A5C))),
                    pw.Text('FinFloat Pro',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text(rep.title,
                        style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text(_allTime ? 'All time' : 'Today · ${todayStr()}',
                        style: const pw.TextStyle(fontSize: 8)),
                  ]),
                ],
              ),
            ),
      footer: (c) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${c.pageNumber} / ${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
      ),
      build: (c) => [
        pw.TableHelper.fromTextArray(
          headers: rep.head,
          data: rep.rows,
          border: pw.TableBorder.all(color: PdfColors.grey300, width: .4),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0D2A5C)),
          headerStyle: pw.TextStyle(
              color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(9),
          decoration: pw.BoxDecoration(
              color: const PdfColor.fromInt(0xFFF1F4F9),
              borderRadius: pw.BorderRadius.circular(5)),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Summary',
                  style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 5),
              ...rep.summary.entries.map((e) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 2),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(e.key, style: const pw.TextStyle(fontSize: 8.5)),
                        pw.Text(e.value,
                            style: pw.TextStyle(
                                fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  )),
            ],
          ),
        ),
      ],
    ));
    return doc;
  }

  Future<void> _pdf(_Rep rep, bool print) async {
    try {
      final doc = await _doc(rep);
      if (print) {
        await Printing.layoutPdf(onLayout: (_) async => doc.save());
        return;
      }
      final dir = await getApplicationDocumentsDirectory();
      final out = Directory(p.join(dir.path, 'FinFloatPro', 'Reports'));
      if (!await out.exists()) await out.create(recursive: true);
      final f = File(p.join(out.path,
          '${rep.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${todayStr()}.pdf'));
      await f.writeAsBytes(await doc.save());
      if (mounted) toast(context, 'PDF save hui');
      await OpenFilex.open(f.path);
    } catch (e) {
      if (mounted) toast(context, 'PDF error: $e', bg: C.error);
    }
  }

  Future<void> _csv(_Rep rep) async {
    try {
      final b = StringBuffer()
        ..writeln('Digitronic Services - FinFloat Pro')
        ..writeln(rep.title)
        ..writeln(_allTime ? 'All time' : 'Today,${todayStr()}')
        ..writeln()
        ..writeln(rep.head.join(','));
      for (final r in rep.rows) {
        b.writeln(r.map((x) => '"${x.replaceAll('"', '""')}"').join(','));
      }
      b..writeln()..writeln('Summary');
      rep.summary.forEach((k, v) => b.writeln('"$k","$v"'));

      final dir = await getApplicationDocumentsDirectory();
      final out = Directory(p.join(dir.path, 'FinFloatPro', 'Reports'));
      if (!await out.exists()) await out.create(recursive: true);
      final f = File(p.join(out.path,
          '${rep.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')}_${todayStr()}.csv'));
      await f.writeAsString(b.toString());
      if (mounted) toast(context, 'Excel (CSV) save hui');
      await Share.shareXFiles([XFile(f.path)], subject: rep.title);
    } catch (e) {
      if (mounted) toast(context, 'Export error: $e', bg: C.error);
    }
  }
}

class _Rep {
  final String title;
  final List<String> head;
  final List<List<String>> rows;
  final Map<String, String> summary;
  _Rep(this.title, this.head, this.rows, this.summary);
}
