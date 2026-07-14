import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/local_db.dart';
import '../db/session.dart';

class WebNewCasePage extends StatefulWidget {
  const WebNewCasePage({super.key});

  @override
  State<WebNewCasePage> createState() => _WebNewCasePageState();
}

class _WebNewCasePageState extends State<WebNewCasePage> {
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _accent  = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);

  final _idController        = TextEditingController();
  final _nameController      = TextEditingController();
  final _ageController       = TextEditingController();
  final _smokingDurationCtrl = TextEditingController();
  final _smokingFreqCtrl     = TextEditingController();

  bool _isSubmitting = false;
  bool _isSearching  = false;
  bool _patientFound = false;

  String sex             = "Male";
  String profilePhotoUrl = "";

  String smokingHistory  = "No";
  bool   smokelessTobacco = false;
  String alcoholUse      = "No";
  Map<String, bool> conditions = {
    "Diabetes": false, "Immunocompromised": false, "Autoimmune": false,
    "Steroids": false, "Chemotherapy": false, "Immunosuppressants": false,
  };

  String duration   = "< 2 weeks";
  String onset      = "Sudden";
  String recurrence = "First episode";
  String healing    = "Healing";
  String pain       = "Painful";

  String anatomicalSite = "Select anatomical site";
  int    lesionSize     = 0;
  String shape          = "Round/Ovoid";
  String margins        = "Well-defined";
  String edgeType       = "Select edge type";
  bool   induration     = false;
  bool   bleeding       = false;

  bool   lymphNode    = false;
  String tenderNode   = "No";
  String nodeMobility = "Mobile";
  bool   paraesthesia = false;
  bool   weightLoss   = false;
  bool   fever        = false;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _smokingDurationCtrl.dispose();
    _smokingFreqCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchPatient() async {
    if (_idController.text.trim().isEmpty) return;
    setState(() { _isSearching = true; _patientFound = false; });

    try {
      final data = await LocalDb.instance.getPatient(_idController.text.trim());
      if (data != null) {
        _nameController.text = data['name'] ?? '';
        _ageController.text  = data['age']?.toString() ?? '';
        sex                  = data['sex'] ?? 'Male';
        profilePhotoUrl      = data['photo_path'] ?? '';

        final Map<String, dynamic> clinical = (data['clinical_json'] != null && data['clinical_json'].toString().isNotEmpty)
                ? Map<String, dynamic>.from(jsonDecode(data['clinical_json'] as String))
                : {};

        if (clinical.isNotEmpty) {
          final demo = clinical['demographics'] as Map<String, dynamic>? ?? {};
          smokingHistory   = demo['smokingStatus']    ?? 'No';
          smokelessTobacco = demo['smokelessTobacco'] ?? false;
          alcoholUse       = demo['alcohol']          ?? 'No';
          _smokingDurationCtrl.text = demo['smokingDuration']  ?? '';
          _smokingFreqCtrl.text     = demo['smokingFrequency'] ?? '';
          conditions = {
            "Diabetes":          demo['diabetes']           ?? false,
            "Immunocompromised": demo['immunocompromised']  ?? false,
            "Autoimmune":        demo['autoimmune']         ?? false,
            "Steroids":          demo['steroids']           ?? false,
            "Chemotherapy":      demo['chemotherapy']       ?? false,
            "Immunosuppressants":demo['immunosuppressants'] ?? false,
          };

          final lesion = clinical['lesionHistory'] as Map<String, dynamic>? ?? {};
          duration   = lesion['duration']       ?? '< 2 weeks';
          onset      = lesion['onset']          ?? 'Sudden';
          recurrence = lesion['recurrence']     ?? 'First episode';
          pain       = lesion['pain']           ?? 'Painful';
          healing    = lesion['healingPattern'] ?? 'Healing';

          final exam = clinical['clinicalExam'] as Map<String, dynamic>? ?? {};
          anatomicalSite = exam['site']       ?? 'Select anatomical site';
          lesionSize     = (exam['size'] is int) ? exam['size'] : 0;
          shape          = exam['shape']      ?? 'Round/Ovoid';
          margins        = exam['margins']    ?? 'Well-defined';
          edgeType       = exam['edge']       ?? 'Select edge type';
          induration     = exam['induration'] ?? false;
          bleeding       = exam['bleeding']   ?? false;

          final findings = clinical['associatedFindings'] as Map<String, dynamic>? ?? {};
          lymphNode    = findings['lymphPalpable'] ?? false;
          tenderNode   = findings['tender']        ?? 'No';
          nodeMobility = findings['nodeMobility']  ?? 'Mobile';
          paraesthesia = findings['paraesthesia']  ?? false;
          weightLoss   = findings['weightLoss']    ?? false;
          fever        = findings['fever']         ?? false;
        }

        setState(() => _patientFound = true);
        _success(clinical.isNotEmpty ? "✅ Returning patient — previous records loaded" : "✅ Patient ID confirmed — fill details");
      } else {
        _clearAllFields();
        setState(() => _patientFound = false);
        _success("New patient registered — please fill form");
      }
    } catch (e) {
      _error("Patient search failed: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      final imageBytes = await pickedFile.readAsBytes();
      final String pid = _idController.text.trim().isEmpty ? "temp" : _idController.text.trim();
      final String? serverPath = await LocalDb.instance.uploadPatientPhoto(
        patientId: pid,
        localPath: null,
        imageBytes: imageBytes,
        fileName: pickedFile.name,
      );

      if (serverPath != null && serverPath.isNotEmpty) {
        setState(() {
          profilePhotoUrl = serverPath;
        });
        _success("Profile photo uploaded to server");
      }
    }
  }

  void _clearAllFields() {
    _nameController.clear();
    _ageController.clear();
    _smokingDurationCtrl.clear();
    _smokingFreqCtrl.clear();
    setState(() {
      sex              = "Male";
      profilePhotoUrl  = "";
      smokingHistory   = "No";
      smokelessTobacco = false;
      alcoholUse       = "No";
      conditions = {
        "Diabetes": false, "Immunocompromised": false,
        "Autoimmune": false, "Steroids": false,
        "Chemotherapy": false, "Immunosuppressants": false,
      };
      duration       = "< 2 weeks";
      onset          = "Sudden";
      recurrence     = "First episode";
      healing        = "Healing";
      pain           = "Painful";
      anatomicalSite = "Select anatomical site";
      lesionSize     = 0;
      shape          = "Round/Ovoid";
      margins        = "Well-defined";
      edgeType       = "Select edge type";
      induration     = false;
      bleeding       = false;
      lymphNode      = false;
      tenderNode     = "No";
      nodeMobility   = "Mobile";
      paraesthesia   = false;
      weightLoss     = false;
      fever          = false;
    });
  }

  Future<void> _submitCase() async {
    if (_idController.text.isEmpty || _nameController.text.isEmpty || _ageController.text.isEmpty) {
      _error("Please complete all Patient Identification fields");
      return;
    }
    if (anatomicalSite == "Select anatomical site") {
      _error("Please select an anatomical site");
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final String doctorId = Session.instance.doctorId;
      final Map<String, dynamic> clinicalData = {
        'demographics': {
          'smokingStatus':     smokingHistory,
          'smokingDuration':   smokingHistory != "No" ? _smokingDurationCtrl.text.trim() : "0",
          'smokingFrequency':  smokingHistory != "No" ? _smokingFreqCtrl.text.trim() : "",
          'smokelessTobacco':  smokelessTobacco,
          'alcohol':           alcoholUse,
          'diabetes':          conditions["Diabetes"],
          'immunocompromised': conditions["Immunocompromised"],
          'autoimmune':        conditions["Autoimmune"],
          'steroids':          conditions["Steroids"],
          'chemotherapy':      conditions["Chemotherapy"],
          'immunosuppressants':conditions["Immunosuppressants"],
        },
        'lesionHistory': {
          'duration':       duration,
          'onset':          onset,
          'recurrence':     recurrence,
          'pain':           pain,
          'healingPattern': healing,
        },
        'clinicalExam': {
          'site':      anatomicalSite,
          'size':      lesionSize,
          'shape':     shape,
          'margins':   margins,
          'edge':      edgeType,
          'induration':induration,
          'bleeding':  bleeding,
        },
        'associatedFindings': {
          'lymphPalpable': lymphNode,
          'tender':        lymphNode ? tenderNode : 'No',
          'nodeMobility':  lymphNode ? nodeMobility : "",
          'paraesthesia':  paraesthesia,
          'weightLoss':    weightLoss,
          'fever':         fever,
        },
      };

      await LocalDb.instance.savePatient(
        patientId:    _idController.text.trim(),
        name:         _nameController.text.trim(),
        age:          int.tryParse(_ageController.text.trim()) ?? 0,
        sex:          sex,
        photoPath:    profilePhotoUrl,
        clinicalData: clinicalData,
      );

      final int caseId = await LocalDb.instance.insertCase(
        patientId:    _idController.text.trim(),
        patientName:  _nameController.text.trim(),
        doctorId:     doctorId,
        clinicalData: clinicalData,
      );

      if (mounted) {
        Navigator.pushNamed(context, '/image_upload', arguments: caseId);
      }
    } catch (e) {
      _error("Error saving case: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _error(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: _red));
  }

  void _success(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }

  static const Color _red = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Add Diagnostic Case', style: TextStyle(color: _text, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: _text),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Identification and Demographics
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      _buildIdCard(),
                      const SizedBox(height: 24),
                      _buildDemographicsCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Center Column: Lesion History
                Expanded(
                  flex: 10,
                  child: Column(
                    children: [
                      _buildLesionHistoryCard(),
                      const SizedBox(height: 24),
                      _buildAssociatedFindingsCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                // Right Column: Clinical Examination & Action
                Expanded(
                  flex: 11,
                  child: Column(
                    children: [
                      _buildClinicalExamCard(),
                      const SizedBox(height: 28),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Patient Identification', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildInputLabelField(
                  label: 'Patient ID (UHID)',
                  controller: _idController,
                  hint: 'Enter UHID',
                  keyboardType: TextInputType.text,
                  suffix: IconButton(
                    onPressed: _searchPatient,
                    icon: _isSearching 
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 1.5, color: _maroon))
                        : const Icon(Icons.search_rounded, color: _maroon),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInputLabelField(label: 'Full Name', controller: _nameController, hint: 'Enter patient name'),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 90,
                child: _buildInputLabelField(label: 'Age', controller: _ageController, hint: 'Age', keyboardType: TextInputType.number),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Sex:  ', style: TextStyle(color: _text, fontWeight: FontWeight.bold, fontSize: 13)),
              _buildChoiceChip('Male', sex == 'Male', (val) => setState(() => sex = 'Male')),
              const SizedBox(width: 10),
              _buildChoiceChip('Female', sex == 'Female', (val) => setState(() => sex = 'Female')),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _pickProfilePhoto,
                icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: Colors.white),
                label: const Text('PHOTO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: _maroon, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemographicsCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Demographics & Habits', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildDropdownLabel('Smoking History', smokingHistory, ['No', 'Past', 'Current'], (val) {
            if (val != null) setState(() => smokingHistory = val);
          }),
          if (smokingHistory != "No") ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInputLabelField(label: 'Smoking Duration (Yrs)', controller: _smokingDurationCtrl, hint: 'e.g. 5', keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildInputLabelField(label: 'Smoking Frequency/Day', controller: _smokingFreqCtrl, hint: 'e.g. 10 cigarettes')),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Smokeless Tobacco Use', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: smokelessTobacco, activeColor: _maroon, onChanged: (val) => setState(() => smokelessTobacco = val)),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdownLabel('Alcohol Consumption', alcoholUse, ['No', 'Occasional', 'Regular'], (val) {
            if (val != null) setState(() => alcoholUse = val);
          }),
          const SizedBox(height: 20),
          const Text('Systemic Conditions', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: conditions.keys.map((key) {
              return FilterChip(
                label: Text(key, style: TextStyle(color: conditions[key]! ? Colors.white : _text, fontSize: 12)),
                selected: conditions[key]!,
                selectedColor: _maroon,
                checkmarkColor: Colors.white,
                onSelected: (selected) => setState(() => conditions[key] = selected),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLesionHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lesion History', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildDropdownLabel('Duration', duration, ['< 2 weeks', '2-3 weeks', '> 3 weeks'], (val) {
            if (val != null) setState(() => duration = val);
          }),
          const SizedBox(height: 16),
          _buildDropdownLabel('Onset Character', onset, ['Sudden', 'Gradual'], (val) {
            if (val != null) setState(() => onset = val);
          }),
          const SizedBox(height: 16),
          _buildDropdownLabel('Recurrence Pattern', recurrence, ['First episode', 'Recurrent (same site)', 'Recurrent (different sites)'], (val) {
            if (val != null) setState(() => recurrence = val);
          }),
          const SizedBox(height: 16),
          _buildDropdownLabel('Pain Characteristics', pain, ['Painful', 'Painless'], (val) {
            if (val != null) setState(() => pain = val);
          }),
          const SizedBox(height: 16),
          _buildDropdownLabel('Healing Pattern', healing, ['Healing', 'Non-healing', 'Progressive'], (val) {
            if (val != null) setState(() => healing = val);
          }),
        ],
      ),
    );
  }

  Widget _buildAssociatedFindingsCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Associated Findings', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Palpable Lymph Nodes', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: lymphNode, activeColor: _maroon, onChanged: (val) => setState(() => lymphNode = val)),
            ],
          ),
          if (lymphNode) ...[
            const SizedBox(height: 16),
            _buildDropdownLabel('Tender Lymph Node', tenderNode, ['No', 'Yes'], (val) {
              if (val != null) setState(() => tenderNode = val);
            }),
            const SizedBox(height: 16),
            _buildDropdownLabel('Node Mobility', nodeMobility, ['Mobile', 'Fixed'], (val) {
              if (val != null) setState(() => nodeMobility = val);
            }),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Paraesthesia / Anaesthesia', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: paraesthesia, activeColor: _maroon, onChanged: (val) => setState(() => paraesthesia = val)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Unexplained Weight Loss', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: weightLoss, activeColor: _maroon, onChanged: (val) => setState(() => weightLoss = val)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Systemic Fever', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: fever, activeColor: _maroon, onChanged: (val) => setState(() => fever = val)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalExamCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Clinical Examination', style: TextStyle(color: _text, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildDropdownLabel(
            'Anatomical Site',
            anatomicalSite,
            ['Select anatomical site', 'Tongue (Lateral) ⚠️', 'Tongue (Ventral) ⚠️', 'Floor of Mouth ⚠️', 'Buccal Mucosa', 'Palate', 'Gingiva', 'Lip'],
            (val) {
              if (val != null) setState(() => anatomicalSite = val);
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Lesion Size (mm)', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('$lesionSize mm', style: const TextStyle(color: _maroon, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          Slider(
            value: lesionSize.toDouble(),
            min: 0, max: 50,
            activeColor: _maroon,
            inactiveColor: _border,
            onChanged: (val) => setState(() => lesionSize = val.toInt()),
          ),
          const SizedBox(height: 16),
          _buildDropdownLabel('Shape Profile', shape, ['Round/Ovoid', 'Irregular'], (val) {
            if (val != null) setState(() => shape = val);
          }),
          const SizedBox(height: 16),
          _buildDropdownLabel('Lesion Margins', margins, ['Well-defined', 'Ill-defined'], (val) {
            if (val != null) setState(() => margins = val);
          }),
          const SizedBox(height: 16),
          _buildDropdownLabel(
            'Edge Type',
            edgeType,
            ['Select edge type', 'Sloping', 'Punched out', 'Undermined', 'Rolled', 'Everted (Risk ⚠️)'],
            (val) {
              if (val != null) setState(() => edgeType = val);
            },
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Induration (Hardness) on Palpation', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: induration, activeColor: _maroon, onChanged: (val) => setState(() => induration = val)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Bleeding on Palpation', style: TextStyle(color: _text, fontSize: 13, fontWeight: FontWeight.bold)),
              Switch.adaptive(value: bleeding, activeColor: _maroon, onChanged: (val) => setState(() => bleeding = val)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitCase,
        style: ElevatedButton.styleFrom(
          backgroundColor: _maroon,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 4,
        ),
        child: _isSubmitting
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('SUBMIT CLINICAL FINDINGS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5)),
      ),
    );
  }

  Widget _buildInputLabelField({required String label, required TextEditingController controller, required String hint, TextInputType keyboardType = TextInputType.text, Widget? suffix}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _muted.withOpacity(0.5)),
              suffixIcon: suffix,
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownLabel(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _text, fontSize: 12.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : (items.isNotEmpty ? items.first : null),
              isExpanded: true,
              onChanged: onChanged,
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13.5)))).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool selected, ValueChanged<bool> onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: _maroon,
      backgroundColor: _bg,
      labelStyle: TextStyle(color: selected ? Colors.white : _text, fontSize: 12, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      side: BorderSide(color: selected ? _maroon : _border),
    );
  }
}
