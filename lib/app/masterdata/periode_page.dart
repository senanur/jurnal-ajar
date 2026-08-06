import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PeriodeItem {
  PeriodeItem({required this.id, required this.nama, required this.aktif});

  final int id;
  final String nama;
  final bool aktif;

  factory PeriodeItem.fromRow(Map<String, dynamic> row) => PeriodeItem(
        id: asInt(row['id'])!,
        nama: (row['nama_periode'] as String?) ?? '',
        aktif: (row['is_active'] as bool?) ?? false,
      );
}

class PeriodeListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final RxList<PeriodeItem> items = <PeriodeItem>[].obs;
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

  List<PeriodeItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) => e.nama.toLowerCase().contains(q)).toList();
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    try {
      final rows = await _supabase
          .from('master_periode')
          .select('id, nama_periode, is_active')
          .order('id', ascending: false) as List;
      items.value = rows
          .map((r) => PeriodeItem.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      showMasterDataError('Gagal memuat periode', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class PeriodeListPage extends StatefulWidget {
  const PeriodeListPage({super.key});

  @override
  State<PeriodeListPage> createState() => _PeriodeListPageState();
}

class _PeriodeListPageState extends State<PeriodeListPage> {
  final PeriodeListController controller = Get.put(PeriodeListController());

  Future<void> _openForm({PeriodeItem? item}) async {
    final changed = await Get.to<bool>(() => PeriodeFormPage(item: item));
    if (changed == true) controller.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Periode',
        onBack: () => Get.offAllNamed(Routes.dashboardAdmin),
        onAdd: () => _openForm(),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              MasterDataSearchField(controller: controller.searchController),
              const SizedBox(height: 16),
              Expanded(
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = controller.filtered;
                  if (list.isEmpty) {
                    return const MasterDataEmptyState(message: 'Belum ada data periode.');
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return MasterDataEntrance(
                        delay: Duration(milliseconds: 40 * index),
                        child: MasterDataListTile(
                          title: item.nama,
                          trailingChip: item.aktif ? 'Aktif' : null,
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

class PeriodeFormPage extends StatefulWidget {
  const PeriodeFormPage({super.key, this.item});

  final PeriodeItem? item;

  @override
  State<PeriodeFormPage> createState() => _PeriodeFormPageState();
}

class _PeriodeFormPageState extends State<PeriodeFormPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  final RxBool _aktif = false.obs;
  final RxBool _isSaving = false.obs;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.item?.nama ?? '');
    _aktif.value = widget.item?.aktif ?? false;
  }

  @override
  void dispose() {
    _namaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _isSaving.value = true;
    try {
      final payload = {
        'nama_periode': _namaController.text.trim(),
        'is_active': _aktif.value,
      };
      if (_isEdit) {
        await _supabase.from('master_periode').update(payload).eq('id', widget.item!.id);
      } else {
        await _supabase.from('master_periode').insert(payload);
      }
      showMasterDataSuccess('Data periode tersimpan.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menyimpan periode', error);
    } finally {
      _isSaving.value = false;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus periode?'),
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
      await _supabase.from('master_periode').delete().eq('id', widget.item!.id);
      showMasterDataSuccess('Data periode dihapus.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menghapus periode', error);
    } finally {
      _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Periode',
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
                  label: 'Nama',
                  controller: _namaController,
                  hint: 'Contoh: 2025/2026 Ganjil',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama periode wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                Obx(
                  () => MasterDataCheckboxRow(
                    label: 'Aktif',
                    value: _aktif.value,
                    onChanged: (v) => _aktif.value = v,
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
