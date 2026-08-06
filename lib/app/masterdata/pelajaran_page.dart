import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PelajaranItem {
  PelajaranItem({required this.id, required this.nama});

  final int id;
  final String nama;

  factory PelajaranItem.fromRow(Map<String, dynamic> row) => PelajaranItem(
        id: asInt(row['id'])!,
        nama: (row['nama_mata_pelajaran'] as String?) ?? '',
      );
}

class PelajaranListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final RxList<PelajaranItem> items = <PelajaranItem>[].obs;
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

  List<PelajaranItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) => e.nama.toLowerCase().contains(q)).toList();
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    try {
      final rows = await _supabase
          .from('master_mata_pelajaran')
          .select('id, nama_mata_pelajaran')
          .order('nama_mata_pelajaran', ascending: true) as List;
      items.value = rows
          .map((r) => PelajaranItem.fromRow(r as Map<String, dynamic>))
          .toList();
    } catch (error) {
      showMasterDataError('Gagal memuat pelajaran', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class PelajaranListPage extends StatefulWidget {
  const PelajaranListPage({super.key});

  @override
  State<PelajaranListPage> createState() => _PelajaranListPageState();
}

class _PelajaranListPageState extends State<PelajaranListPage> {
  final PelajaranListController controller = Get.put(PelajaranListController());

  Future<void> _openForm({PelajaranItem? item}) async {
    final changed = await Get.to<bool>(() => PelajaranFormPage(item: item));
    if (changed == true) controller.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Pelajaran',
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
                    return const MasterDataEmptyState(message: 'Belum ada data pelajaran.');
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      return MasterDataEntrance(
                        delay: Duration(milliseconds: 30 * index),
                        child: MasterDataListTile(
                          title: item.nama,
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

class PelajaranFormPage extends StatefulWidget {
  const PelajaranFormPage({super.key, this.item});

  final PelajaranItem? item;

  @override
  State<PelajaranFormPage> createState() => _PelajaranFormPageState();
}

class _PelajaranFormPageState extends State<PelajaranFormPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _namaController;
  final RxBool _isSaving = false.obs;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.item?.nama ?? '');
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
      final payload = {'nama_mata_pelajaran': _namaController.text.trim()};
      if (_isEdit) {
        await _supabase
            .from('master_mata_pelajaran')
            .update(payload)
            .eq('id', widget.item!.id);
      } else {
        await _supabase.from('master_mata_pelajaran').insert(payload);
      }
      showMasterDataSuccess('Data pelajaran tersimpan.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menyimpan pelajaran', error);
    } finally {
      _isSaving.value = false;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus pelajaran?'),
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
      await _supabase.from('master_mata_pelajaran').delete().eq('id', widget.item!.id);
      showMasterDataSuccess('Data pelajaran dihapus.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menghapus pelajaran', error);
    } finally {
      _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Pelajaran',
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
                  label: 'Pelajaran',
                  controller: _namaController,
                  hint: 'Contoh: Pemrograman Web',
                  textCapitalization: TextCapitalization.words,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Nama pelajaran wajib diisi' : null,
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
