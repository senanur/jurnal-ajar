import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The only selectable values for "Batas Input Jurnal" (prompt §4.2). The
/// stored column is a free int, but the UX is locked to these three options.
const List<int> _batasInputJurnalOptions = [2, 3, 5];

class PeriodeOption {
  PeriodeOption({required this.id, required this.nama, required this.aktif});

  final int id;
  final String nama;
  final bool aktif;
}

class PengaturanController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Nobox.ai "send message" endpoint. Not present anywhere in the repo
  /// (checked `assets/api/jm_collection.json` and the whole `design/` folder —
  /// see design/prompt/012_pengaturan.md §10/§11.4). [testKirimPesan] reports
  /// "not configured" until this real URL + header shape are supplied.
  static const String _noboxSendUrl = '';

  final RxList<PeriodeOption> periodeOptions = <PeriodeOption>[].obs;
  final Rx<int?> selectedPeriodeId = Rx<int?>(null);
  final RxInt batasInputJurnal = 3.obs;
  final TextEditingController accountIdsCtrl = TextEditingController();
  final TextEditingController apiKeyCtrl = TextEditingController();
  final RxBool isLoading = true.obs;
  final RxBool isSaving = false.obs;
  final RxBool isTesting = false.obs;

  @override
  void onInit() {
    super.onInit();
    _load();
  }

  @override
  void onClose() {
    accountIdsCtrl.dispose();
    apiKeyCtrl.dispose();
    super.onClose();
  }

  Future<void> _load() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _supabase
            .from('master_periode')
            .select('id, nama_periode, is_active')
            .order('id'),
        _supabase.from('pengaturan_aplikasi').select('*').eq('id', 1).maybeSingle(),
      ]);

      final periodeRows = results[0] as List;
      final settings = results[1] as Map<String, dynamic>?;

      periodeOptions.value = periodeRows.map((r) {
        final row = r as Map<String, dynamic>;
        return PeriodeOption(
          id: asInt(row['id']) ?? 0,
          nama: (row['nama_periode'] as String?) ?? '',
          aktif: (row['is_active'] as bool?) ?? false,
        );
      }).toList();

      final active = periodeOptions.firstWhereOrNull((p) => p.aktif);
      selectedPeriodeId.value = active?.id;

      if (settings != null) {
        batasInputJurnal.value = asInt(settings['batas_input_jurnal']) ?? 3;
        accountIdsCtrl.text = (settings['nobox_account_ids'] as String?) ?? '';
        apiKeyCtrl.text = (settings['nobox_token'] as String?) ?? '';
      }
    } catch (error) {
      showMasterDataError('Gagal memuat pengaturan', error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> save() async {
    if (periodeOptions.isEmpty) {
      showMasterDataError(
        'Belum ada periode',
        'Buat periode tahun ajaran terlebih dahulu di menu Periode.',
      );
      return;
    }
    final selectedId = selectedPeriodeId.value;
    if (selectedId == null) {
      showMasterDataError('Data belum lengkap', 'Pilih periode aktif.');
      return;
    }
    if (!_batasInputJurnalOptions.contains(batasInputJurnal.value)) {
      showMasterDataError('Data belum lengkap', 'Pilih batas input jurnal.');
      return;
    }
    if (accountIdsCtrl.text.trim().isEmpty) {
      showMasterDataError('Data belum lengkap', 'AccountIds wajib diisi.');
      return;
    }
    if (apiKeyCtrl.text.trim().isEmpty) {
      showMasterDataError('Data belum lengkap', 'API Key Nobox.ai wajib diisi.');
      return;
    }

    isSaving.value = true;
    try {
      // No client-side transaction is available, so do these sequentially —
      // and activate the selected periode BEFORE deactivating the rest. If
      // the second call fails partway through, this leaves two periode rows
      // active rather than zero, which is a much smaller inconsistency to
      // recover from than "no active periode" (other features assume one
      // always exists). Mirrors the single-active-periode assumption used by
      // periode_page.dart.
      await _supabase.from('master_periode').update({'is_active': true}).eq('id', selectedId);
      await _supabase.from('master_periode').update({'is_active': false}).neq('id', selectedId);

      // The settings table has no id default/identity — treat id = 1 as THE
      // single settings row and upsert (insert today, update thereafter).
      await _supabase.from('pengaturan_aplikasi').upsert({
        'id': 1,
        'nobox_account_ids': accountIdsCtrl.text.trim(),
        'nobox_token': apiKeyCtrl.text.trim(),
        'batas_input_jurnal': batasInputJurnal.value,
      });

      periodeOptions.value = periodeOptions
          .map((p) => PeriodeOption(id: p.id, nama: p.nama, aktif: p.id == selectedId))
          .toList();

      showMasterDataSuccess('Pengaturan tersimpan.');
    } catch (error) {
      showMasterDataError('Gagal menyimpan pengaturan', error);
    } finally {
      isSaving.value = false;
    }
  }

  /// Uses the credentials *currently typed* in the form (not the last-saved DB
  /// values) so the admin can verify new creds before committing via [save].
  Future<void> testKirimPesan(String phone) async {
    final accountIds = accountIdsCtrl.text.trim();
    final apiKey = apiKeyCtrl.text.trim();
    if (accountIds.isEmpty || apiKey.isEmpty) {
      showMasterDataError('Data belum lengkap', 'Isi AccountIds dan API Key terlebih dahulu.');
      return;
    }
    if (_noboxSendUrl.isEmpty) {
      // The real external endpoint isn't documented anywhere in this repo
      // (design/prompt/012_pengaturan.md §10), so fail loudly instead of
      // guessing at a paid API's URL/method/header shape.
      showMasterDataError(
        'Integrasi Nobox belum dikonfigurasi',
        'Endpoint gateway Nobox belum diatur.',
      );
      return;
    }

    isTesting.value = true;
    try {
      final response = await GetConnect().post(
        _noboxSendUrl,
        {
          'to': phone,
          'accountIds': accountIds,
          'message': 'Halo ini pesan dari nobox api',
        },
        headers: {'X-Api-Key': apiKey},
      );
      final status = response.statusCode;
      if (status == null || status >= 400) {
        throw StateError('Nobox merespons dengan status $status');
      }
      showMasterDataSuccess('Pesan uji terkirim.');
    } catch (error) {
      showMasterDataError('Gagal mengirim pesan uji', error);
    } finally {
      isTesting.value = false;
    }
  }
}

class PengaturanPage extends StatefulWidget {
  const PengaturanPage({super.key});

  @override
  State<PengaturanPage> createState() => _PengaturanPageState();
}

class _PengaturanPageState extends State<PengaturanPage> {
  final PengaturanController controller = Get.put(PengaturanController());

  Future<void> _onTestKirimPesan() async {
    final phone = await _promptPhone();
    if (phone == null) return;
    await controller.testKirimPesan(phone);
  }

  Future<String?> _promptPhone() {
    final phoneCtrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Test Kirim Pesan'),
        content: TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          onSubmitted: (v) {
            final value = v.trim();
            if (value.isNotEmpty) Navigator.of(dialogContext).pop(value);
          },
          decoration: const InputDecoration(
            labelText: 'Nomor HP tujuan',
            hintText: 'Contoh: 081234567890',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              final value = phoneCtrl.text.trim();
              if (value.isEmpty) return;
              Navigator.of(dialogContext).pop(value);
            },
            style: TextButton.styleFrom(foregroundColor: MainColor.primaryColor),
            child: const Text('Kirim'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Pengaturan',
        onBack: () => Get.offAllNamed(Routes.dashboardAdmin),
      ),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPeriodeSection(),
                const SizedBox(height: 20),
                _buildBatasSection(),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 24),
                _buildNoboxSection(),
                const SizedBox(height: 24),
              ],
            ),
          );
        }),
      ),
      bottomNavigationBar: Obx(
        () => MasterDataSaveBar(
          isSaving: controller.isSaving.value,
          onSave: controller.save,
        ),
      ),
    );
  }

  Widget _buildPeriodeSection() {
    return MasterDataEntrance(
      delay: Duration.zero,
      child: Obx(() {
        final options = controller.periodeOptions;
        return MasterDataDropdown<int>(
          label: 'Periode',
          value: controller.selectedPeriodeId.value,
          items: options.map((p) => p.id).toList(),
          itemLabel: (id) => options.firstWhere((p) => p.id == id).nama,
          hint: options.isEmpty ? 'Belum ada periode' : 'Pilih Periode',
          onChanged: options.isEmpty
              ? null
              : (v) => controller.selectedPeriodeId.value = v,
        );
      }),
    );
  }

  Widget _buildBatasSection() {
    return MasterDataEntrance(
      delay: const Duration(milliseconds: 120),
      child: Obx(
        () => MasterDataDropdown<int>(
          label: 'Batas Input Jurnal',
          value: controller.batasInputJurnal.value,
          items: _batasInputJurnalOptions,
          itemLabel: (v) => '$v Hari',
          hint: 'Pilih Batas',
          onChanged: (v) {
            if (v != null) controller.batasInputJurnal.value = v;
          },
        ),
      ),
    );
  }

  Widget _buildNoboxSection() {
    return MasterDataEntrance(
      delay: const Duration(milliseconds: 240),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Konfigurasi Gateway API Nobox Whatsapp',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 20),
          MasterDataTextField(
            label: 'AccountIds',
            controller: controller.accountIdsCtrl,
            hint: 'AccountIds Nobox',
          ),
          const SizedBox(height: 20),
          MasterDataTextField(
            label: 'API Key Nobox.ai',
            controller: controller.apiKeyCtrl,
            hint: 'API Key Nobox.ai',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          Obx(
            () => OutlinedButton.icon(
              onPressed: controller.isTesting.value ? null : _onTestKirimPesan,
              style: OutlinedButton.styleFrom(
                foregroundColor: MainColor.primaryColor,
                side: BorderSide(color: MainColor.primaryColor, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: controller.isTesting.value
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: MainColor.primaryColor),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: const Text('Test Kirim Pesan', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
