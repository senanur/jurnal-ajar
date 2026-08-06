import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/routes.dart';
import 'package:jurnal_mengajar/app/utils/date_utils.dart';
import 'package:jurnal_mengajar/app/widgets/master_data_widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class JamItem {
  JamItem({
    required this.id,
    required this.jamKe,
    required this.waktuReguler,
    required this.waktuPuasa,
  });

  final int id;
  final int jamKe;
  final String waktuReguler;
  final String waktuPuasa;

  factory JamItem.fromRow(Map<String, dynamic> row) => JamItem(
        id: asInt(row['id'])!,
        jamKe: asInt(row['jam_ke']) ?? 0,
        waktuReguler: (row['waktu_reguler'] as String?) ?? '',
        waktuPuasa: (row['waktu_puasa'] as String?) ?? '',
      );
}

class JamListController extends GetxController {
  SupabaseClient get _supabase => Supabase.instance.client;

  final RxList<JamItem> items = <JamItem>[].obs;
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

  List<JamItem> get filtered {
    final q = query.value.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((e) {
      return 'jam ke ${e.jamKe}'.contains(q) ||
          e.waktuReguler.toLowerCase().contains(q) ||
          e.waktuPuasa.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> fetchItems() async {
    isLoading.value = true;
    try {
      final rows = await _supabase
          .from('master_jam')
          .select('id, jam_ke, waktu_reguler, waktu_puasa')
          .order('jam_ke', ascending: true) as List;
      items.value =
          rows.map((r) => JamItem.fromRow(r as Map<String, dynamic>)).toList();
    } catch (error) {
      showMasterDataError('Gagal memuat jam pelajaran', error);
    } finally {
      isLoading.value = false;
    }
  }
}

class JamListPage extends StatefulWidget {
  const JamListPage({super.key});

  @override
  State<JamListPage> createState() => _JamListPageState();
}

class _JamListPageState extends State<JamListPage> {
  final JamListController controller = Get.put(JamListController());

  Future<void> _openForm({JamItem? item}) async {
    final changed = await Get.to<bool>(() => JamFormPage(item: item));
    if (changed == true) controller.fetchItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: 'Master Jam',
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
                    return const MasterDataEmptyState(message: 'Belum ada data jam pelajaran.');
                  }
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final item = list[index];
                      final filled = index.isEven;
                      return MasterDataEntrance(
                        delay: Duration(milliseconds: 40 * index),
                        child: MasterDataListTile(
                          leading: _JamBadge(number: item.jamKe, filled: filled),
                          title: 'Reguler: ${item.waktuReguler}',
                          subtitle: 'Puasa: ${item.waktuPuasa}',
                          filled: filled,
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

class _JamBadge extends StatelessWidget {
  const _JamBadge({required this.number, required this.filled});

  final int number;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? Colors.white.withValues(alpha: 0.22) : MainColor.primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

class JamFormPage extends StatefulWidget {
  const JamFormPage({super.key, this.item});

  final JamItem? item;

  @override
  State<JamFormPage> createState() => _JamFormPageState();
}

class _JamFormPageState extends State<JamFormPage> {
  SupabaseClient get _supabase => Supabase.instance.client;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _jamKeController;
  late final TextEditingController _regulerController;
  late final TextEditingController _puasaController;
  final RxBool _isSaving = false.obs;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    _jamKeController =
        TextEditingController(text: widget.item != null ? '${widget.item!.jamKe}' : '');
    _regulerController = TextEditingController(text: widget.item?.waktuReguler ?? '');
    _puasaController = TextEditingController(text: widget.item?.waktuPuasa ?? '');
  }

  @override
  void dispose() {
    _jamKeController.dispose();
    _regulerController.dispose();
    _puasaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _isSaving.value = true;
    try {
      final payload = {
        'jam_ke': int.parse(_jamKeController.text.trim()),
        'waktu_reguler': _regulerController.text.trim(),
        'waktu_puasa': _puasaController.text.trim(),
      };
      if (_isEdit) {
        await _supabase.from('master_jam').update(payload).eq('id', widget.item!.id);
      } else {
        await _supabase.from('master_jam').insert(payload);
      }
      showMasterDataSuccess('Data jam pelajaran tersimpan.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menyimpan jam pelajaran', error);
    } finally {
      _isSaving.value = false;
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus jam pelajaran?'),
        content: Text('Jam ke ${widget.item!.jamKe} akan dihapus permanen.'),
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
      await _supabase.from('master_jam').delete().eq('id', widget.item!.id);
      showMasterDataSuccess('Data jam pelajaran dihapus.');
      Get.back(result: true);
    } catch (error) {
      showMasterDataError('Gagal menghapus jam pelajaran', error);
    } finally {
      _isSaving.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: masterDataBackground,
      appBar: masterDataAppBar(
        title: _isEdit ? 'Edit Jam' : 'Tambah Jam',
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
                  label: 'Jam Ke (Angka)',
                  controller: _jamKeController,
                  hint: 'Contoh: 1',
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Jam ke wajib diisi';
                    if (int.tryParse(v.trim()) == null) return 'Harus berupa angka';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                MasterDataTextField(
                  label: 'Waktu Reguler (Contoh: 07.00-07.45)',
                  controller: _regulerController,
                  hint: '07.00-07.45',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Waktu reguler wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                MasterDataTextField(
                  label: 'Waktu Puasa (Contoh: 07.30-08.05)',
                  controller: _puasaController,
                  hint: '07.30-08.05',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Waktu puasa wajib diisi' : null,
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
