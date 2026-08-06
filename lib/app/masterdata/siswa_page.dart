import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class KelasOption {
  KelasOption({required this.id, required this.nama});

  final int id;
  final String nama;
}

class SiswaItem {
  SiswaItem({
    required this.id,
    required this.nama,
    required this.nisn,
    required this.kelasId,
    required this.kelasNama,
    required this.noHpOrtu,
  });

  final int id;
  final String nama;
  final String nisn;
  final int? kelasId;
  final String kelasNama;
  final String noHpOrtu;
}

class SiswaListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final RxList<SiswaItem> items = <SiswaItem>[].obs;
  final RxList<KelasOption> kelasOptions = <KelasOption>[].obs;
  final RxBool isLoading = true.obs;
  final TextEditingController searchController = TextEditingController();
  final RxString query = ''.obs;

  @override
  void onInit() {
    super.onInit();
    searchController.addListener(() => query.value = searchController.text);
    fetchItems();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  List<SiswaItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) {
      return e.nama.toLowerCase().contains(q) ||
          e.nisn.toLowerCase().contains(q) ||
          e.kelasNama.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    try {
      final kelasRows = await _supabase
          .from('master_kelas')
          .select('id, nama_kelas')
          .order('nama_kelas', ascending: true) as List;
      kelasOptions.value = kelasRows
          .map((r) => KelasOption(
                id: asInt((r as Map<String, dynamic>)['id'])!,
                nama: (r['nama_kelas'] as String?) ?? '',
              ))
          .toList();
      final kelasNameById = {for (final k in kelasOptions) k.id: k.nama};

      final rows = await _supabase
          .from('master_siswa')
          .select('id, nama_siswa, nisn, kelas_id, no_hp_ortu')
          .order('nama_siswa', ascending: true) as List;
      items.value = rows.map((r) {
        final row = r as Map<String, dynamic>;
        final kelasId = asInt(row['kelas_id']);
        return SiswaItem(
          id: asInt(row['id'])!,
          nama: (row['nama_siswa'] as String?) ?? '',
          nisn: (row['nisn'] as String?) ?? '',
          kelasId: kelasId,
          kelasNama: kelasNameById[kelasId] ?? '-',
          noHpOrtu: (row['no_hp_ortu'] as String?) ?? '',
        );
      }).toList();
    } catch (error) {
      showMasterDataError('Gagal memuat siswa', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class SiswaListPage extends StatefulWidget {
  const SiswaListPage({super.key});

  @override
  State<SiswaListPage> createState() => _SiswaListPageState();
}

class _SiswaListPageState extends State<SiswaListPage> {
  final SiswaListController controller = Get.put(SiswaListController());

  Future<void> _openForm({SiswaItem? item}) async {
    final changed = await Get.to<bool>(
      () => SiswaFormPage(item: item, kelasOptions: controller.kelasOptions),
    );
    if (changed == true) controller.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Master Siswa',
        onBack: () => Get.offAllNamed(Routes.dashboardAdmin),
        onAdd: () => _openForm(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              MasterDataSearchField(
                controller: controller.searchController,
                hint: 'Pencarian (Nama, NISN, Kelas)',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = controller.filtered;
                  if (list.isEmpty) {
                    return const MasterDataEmptyState(message: 'Belum ada data siswa.');
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return MasterDataEntrance(
                        delay: Duration(milliseconds: 20 * index),
                        child: MasterDataListTile(
                          title: item.nama,
                          subtitle: 'NISN: ${item.nisn}',
                          trailingChip: item.kelasNama,
                          filled: index.isEven,
                          onTap: () => _openForm(item: item),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SiswaFormPage extends StatefulWidget {
  const SiswaFormPage({super.key, this.item, required this.kelasOptions});

  final SiswaItem? item;
  final List<KelasOption> kelasOptions;

  @override
  State<SiswaFormPage> createState() => _SiswaFormPageState();
}

class _SiswaFormPageState extends State<SiswaFormPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  late final TextEditingController _nisnController;
  late final TextEditingController _hpController;
  final Rxn<KelasOption> _kelas = Rxn<KelasOption>();
  final RxBool _isSaving = false.obs;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.item?.nama ?? '');
    _nisnController = TextEditingController(text: widget.item?.nisn ?? '');
    _hpController = TextEditingController(text: widget.item?.noHpOrtu ?? '');
    if (widget.item?.kelasId != null) {
      for (final k in widget.kelasOptions) {
        if (k.id == widget.item!.kelasId) {
          _kelas.value = k;
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nisnController.dispose();
    _hpController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final formValid = _formKey.currentState?.validate() ?? false;
    if (!formValid || _kelas.value == null) {
      if (_kelas.value == null) {
        showMasterDataError('Data belum lengkap', 'Kelas wajib dipilih');
      }
      return;
    }
    _isSaving.value = true;
    try {
      final payload = {
        'nama_siswa': _namaController.text.trim(),
        'nisn': _nisnController.text.trim(),
        'kelas_id': _kelas.value!.id,
        'no_hp_ortu': _hpController.text.trim(),
      };
      if (_isEdit) {
        await _supabase.from('master_siswa').update(payload).eq('id', widget.item!.id);
      } else {
        await _supabase.from('master_siswa').insert(payload);
      }
      showMasterDataSuccess('Data siswa tersimpan.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menyimpan siswa', error);
    } finally {
      _isSaving.value = false;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus siswa?'),
        content: Text('Data "${widget.item!.nama}" akan dihapus permanen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red.shade600),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _isSaving.value = true;
    try {
      await _supabase.from('master_siswa').delete().eq('id', widget.item!.id);
      showMasterDataSuccess('Data siswa dihapus.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menghapus siswa', error);
    } finally {
      _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: _isEdit ? 'Edit Siswa' : 'Tambah Siswa',
        onBack: () => Get.back(),
        onDelete: _isEdit ? _confirmDelete : null,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MasterDataTextField(
                  label: 'Nama Siswa',
                  controller: _namaController,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama siswa wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                MasterDataTextField(
                  label: 'NISN',
                  controller: _nisnController,
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'NISN wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                MasterDataTextField(
                  label: 'No. HP Orang Tua',
                  controller: _hpController,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                Obx(
                  () => MasterDataDropdown<KelasOption>(
                    label: 'Kelas',
                    value: _kelas.value,
                    items: widget.kelasOptions,
                    itemLabel: (k) => k.nama,
                    hint: 'Pilih Kelas',
                    onChanged: (v) => _kelas.value = v,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Obx(
        () => MasterDataSaveBar(isSaving: _isSaving.value, onSave: _save),
      ),
    );
  }
}
