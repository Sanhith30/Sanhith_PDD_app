import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'db/local_db.dart';
import 'db/session.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  NEW CASE PAGE  —  "Surgical Luxury" design system
//  ✅ On patient search: auto-fills ALL previous clinical data
//  ✅ On submit: saves all clinical data back to patients collection
//  ✅ New patient: clean blank form
// ─────────────────────────────────────────────────────────────────────────────

class NewCasePage extends StatefulWidget {
  const NewCasePage({super.key});

  @override
  State<NewCasePage> createState() => _NewCasePageState();
}

class _NewCasePageState extends State<NewCasePage> {

  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFFAF7F4);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _maroon  = Color(0xFF7B1E3A);
  static const Color _maroonD = Color(0xFF5C1028);
  static const Color _gold    = Color(0xFFC9A84C);
  static const Color _muted   = Color(0xFF9E8A8F);
  static const Color _border  = Color(0xFFE8DDD8);
  static const Color _text    = Color(0xFF1E0A10);
  static const Color _riskRed = Color(0xFFB71C1C);

  // ── Controllers ───────────────────────────────────────────────────────────
  final _idController        = TextEditingController();
  final _nameController      = TextEditingController();
  final _ageController       = TextEditingController();
  final _smokingDurationCtrl = TextEditingController();
  final _smokingFreqCtrl     = TextEditingController();

  bool _isSubmitting = false;
  bool _isSearching  = false;
  bool _patientFound = false; // shows green banner when existing patient loaded

  // ── Form state ────────────────────────────────────────────────────────────
  String sex             = "Male";
  String profilePhotoUrl = "";

  // A. Demographics
  String smokingHistory  = "No";
  bool   smokelessTobacco = false;
  String alcoholUse      = "No";
  Map<String, bool> conditions = {
    "Diabetes": false, "Immunocompromised": false, "Autoimmune": false,
    "Steroids": false, "Chemotherapy": false, "Immunosuppressants": false,
  };

  // B. Lesion History
  String duration   = "< 2 weeks";
  String onset      = "Sudden";
  String recurrence = "First episode";
  String healing    = "Healing";
  String pain       = "Painful";

  // C. Clinical Examination
  String anatomicalSite = "Select anatomical site";
  int    lesionSize     = 0;
  String shape          = "Round/Ovoid";
  String margins        = "Well-defined";
  String edgeType       = "Select edge type";
  bool   induration     = false;
  bool   bleeding       = false;

  // D. Associated Findings
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

  // ══════════════════════════════════════════════════════════════════════════
  //  SEARCH PATIENT — loads ALL previous clinical data
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _searchPatient() async {
    if (_idController.text.trim().isEmpty) return;
    setState(() { _isSearching = true; _patientFound = false; });

    try {
      final data = await LocalDb.instance.getPatient(
          _idController.text.trim());

      if (data != null) {
        // ── Basic info ──────────────────────────────────────────────────
        _nameController.text = data['name'] ?? '';
        _ageController.text  = data['age']?.toString() ?? '';
        sex                  = data['sex'] ?? 'Male';
        profilePhotoUrl      = data['photo_path'] ?? '';

        // ── Load last clinical data ─────────────────────────────────────
        final Map<String, dynamic> clinical =
            (data['clinical_json'] != null &&
                    data['clinical_json'].toString().isNotEmpty)
                ? Map<String, dynamic>.from(
                    jsonDecode(data['clinical_json'] as String))
                : {};

        if (clinical.isNotEmpty) {
          final demo =
              clinical['demographics'] as Map<String, dynamic>? ?? {};
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

          final lesion =
              clinical['lesionHistory'] as Map<String, dynamic>? ?? {};
          duration   = lesion['duration']       ?? '< 2 weeks';
          onset      = lesion['onset']          ?? 'Sudden';
          recurrence = lesion['recurrence']     ?? 'First episode';
          pain       = lesion['pain']           ?? 'Painful';
          healing    = lesion['healingPattern'] ?? 'Healing';

          final exam =
              clinical['clinicalExam'] as Map<String, dynamic>? ?? {};
          anatomicalSite = exam['site']       ?? 'Select anatomical site';
          lesionSize     = (exam['size'] is int) ? exam['size'] : 0;
          shape          = exam['shape']      ?? 'Round/Ovoid';
          margins        = exam['margins']    ?? 'Well-defined';
          edgeType       = exam['edge']       ?? 'Select edge type';
          induration     = exam['induration'] ?? false;
          bleeding       = exam['bleeding']   ?? false;

          final findings =
              clinical['associatedFindings'] as Map<String, dynamic>? ?? {};
          lymphNode    = findings['lymphPalpable'] ?? false;
          tenderNode   = findings['tender']        ?? 'No';
          nodeMobility = findings['nodeMobility']  ?? 'Mobile';
          paraesthesia = findings['paraesthesia']  ?? false;
          weightLoss   = findings['weightLoss']    ?? false;
          fever        = findings['fever']         ?? false;
        }

        setState(() => _patientFound = true);
        _showSnackBar(
          clinical.isNotEmpty
              ? "✅ Returning patient — all previous data loaded"
              : "✅ Patient found — please fill clinical details",
          isSuccess: true,
        );
      } else {
        _clearAllFields();
        setState(() => _patientFound = false);
        _showSnackBar("New patient — please fill in all details.");
      }
    } catch (e) {
      _showSnackBar("Error searching patient: $e");
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 400,
    );

    if (pickedFile != null) {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String dest = p.join(appDocDir.path, "profile_${DateTime.now().millisecondsSinceEpoch}_${p.basename(pickedFile.path)}");
      await File(pickedFile.path).copy(dest);
      
      setState(() {
        profilePhotoUrl = dest;
      });
      _showSnackBar("Profile photo captured and saved", isSuccess: true);
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

  // ══════════════════════════════════════════════════════════════════════════
  //  SUBMIT CASE — saves clinical data back to patients collection too
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _submitCase() async {
    if (_idController.text.isEmpty ||
        _nameController.text.isEmpty ||
        _ageController.text.isEmpty) {
      _showSnackBar("Please complete all Patient Identification fields");
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final String doctorId = Session.instance.doctorId;

      final Map<String, dynamic> clinicalData = {
        'demographics': {
          'smokingStatus':     smokingHistory,
          'smokingDuration':   smokingHistory != "No"
              ? _smokingDurationCtrl.text.trim() : "0",
          'smokingFrequency':  smokingHistory != "No"
              ? _smokingFreqCtrl.text.trim() : "",
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

      // 1. Save/Update Patient in SQLite
      await LocalDb.instance.savePatient(
        patientId:    _idController.text.trim(),
        name:         _nameController.text.trim(),
        age:          int.tryParse(_ageController.text.trim()) ?? 0,
        sex:          sex,
        photoPath:    profilePhotoUrl,
        clinicalData: clinicalData,
      );

      // 2. Insert Case in SQLite
      final int caseId = await LocalDb.instance.insertCase(
        patientId:    _idController.text.trim(),
        patientName:  _nameController.text.trim(),
        doctorId:     doctorId,
        clinicalData: clinicalData,
      );

      if (mounted) {
        Navigator.pushNamed(context, '/image_upload',
            arguments: caseId);
      }
    } catch (e) {
      _showSnackBar("Error saving case: $e");
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSnackBar(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isSuccess
              ? Icons.check_circle_outline
              : Icons.error_outline,
          color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: const TextStyle(
                  fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor:
          isSuccess ? const Color(0xFF2E7D32) : _maroon,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              children: [
                // Returning patient banner
                if (_patientFound) ...[
                  _buildReturnPatientBanner(),
                  const SizedBox(height: 12),
                ],
                _buildPatientIdCard(),
                const SizedBox(height: 12),
                _buildSection(
                  title: "A. Patient Demographics",
                  icon: Icons.people_outline_rounded,
                  step: "01",
                  children: _demographicsChildren(),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: "B. Lesion History",
                  icon: Icons.history_rounded,
                  step: "02",
                  children: _lesionHistoryChildren(),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: "C. Clinical Examination",
                  icon: Icons.biotech_outlined,
                  step: "03",
                  children: _clinicalExamChildren(),
                ),
                const SizedBox(height: 12),
                _buildSection(
                  title: "D. Associated Findings",
                  icon: Icons.visibility_outlined,
                  step: "04",
                  children: _associatedFindingsChildren(),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          _buildProceedButton(),
        ],
      ),
    );
  }

  // ── Returning patient banner ──────────────────────────────────────────────
  Widget _buildReturnPatientBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF2E7D32).withOpacity(0.3), width: 1),
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32).withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.person_search_rounded,
              color: Color(0xFF2E7D32), size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Returning Patient",
                  style: TextStyle(
                    color: Color(0xFF1B5E20), fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  )),
              Text(
                "All previous medical data loaded — review and update if needed",
                style: TextStyle(
                  color: const Color(0xFF2E7D32).withOpacity(0.8),
                  fontSize: 11),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_maroonD, _maroon],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 20),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("New Case Assessment",
                      style: TextStyle(
                        color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.w600, letterSpacing: 0.3,
                      )),
                  Text("Complete all sections before proceeding",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.60),
                        fontSize: 11.5, letterSpacing: 0.2,
                      )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _gold.withOpacity(0.35), width: 1),
              ),
              child: Text("4 Sections",
                  style: TextStyle(
                    color: _gold.withOpacity(0.90), fontSize: 10,
                    fontWeight: FontWeight.w700, letterSpacing: 1.0,
                  )),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Patient ID card ───────────────────────────────────────────────────────
  Widget _buildPatientIdCard() {
    return _buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            title: "Patient Identification",
            subtitle: "Search existing or enter new patient",
            icon: Icons.badge_outlined,
            step: "ID",
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Photo
              GestureDetector(
                onTap: _pickProfilePhoto,
                child: Container(
                  width: 68, height: 68,
                  decoration: BoxDecoration(
                    color: _maroon.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _border, width: 1.2),
                    image: profilePhotoUrl.isNotEmpty && !kIsWeb && File(profilePhotoUrl).existsSync()
                      ? DecorationImage(image: FileImage(File(profilePhotoUrl)), fit: BoxFit.cover)
                      : null,
                  ),
                  child: profilePhotoUrl.isEmpty || kIsWeb || !File(profilePhotoUrl).existsSync()
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              color: _muted.withOpacity(0.6), size: 22),
                          const SizedBox(height: 4),
                          Text("Photo",
                              style: TextStyle(
                                color: _muted.withOpacity(0.6),
                                fontSize: 9.5, fontWeight: FontWeight.w500,
                              )),
                        ],
                      )
                    : null,
                ),
              ),
              const SizedBox(width: 14),

              // Patient ID + Search
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel("Patient ID *"),
                    _buildTextField(
                      controller: _idController,
                      hint: "e.g. PT001",
                      suffix: _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _maroon)))
                          : GestureDetector(
                              onTap: _searchPatient,
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _maroon,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text("Search",
                                    style: TextStyle(
                                      color: Colors.white, fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    )),
                              ),
                            ),
                      onSubmit: (_) => _searchPatient(),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          _fieldLabel("Full Name *"),
          _buildTextField(
              controller: _nameController,
              hint: "Enter patient name"),

          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel("Age *"),
                  _buildTextField(
                    controller: _ageController,
                    hint: "Years",
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _fieldLabel("Sex *"),
                  _buildDropdown<String>(
                    value: sex,
                    items: ["Male", "Female", "Other"],
                    onChanged: (v) => setState(() => sex = v!),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Section wrapper ───────────────────────────────────────────────────────
  Widget _buildSection({
    required String title,
    required IconData icon,
    required String step,
    required List<Widget> children,
  }) {
    return _buildCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: _maroon.withOpacity(0.04),
        ),
        child: ExpansionTile(
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _maroon.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _maroon, size: 18),
          ),
          title: Text(title,
              style: const TextStyle(
                color: _text, fontSize: 13.5,
                fontWeight: FontWeight.w600, letterSpacing: 0.1,
              )),
          trailing: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _maroon.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(step,
                style: const TextStyle(
                  color: _maroon, fontSize: 10,
                  fontWeight: FontWeight.w700, letterSpacing: 0.5,
                )),
          ),
          tilePadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: children,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SECTION CONTENT
  // ══════════════════════════════════════════════════════════════════════════

  List<Widget> _demographicsChildren() => [
    _sectionDivider(),
    _buildChoiceGroup("Smoking History",
        ["No", "Past", "Current"], smokingHistory,
        (v) => setState(() => smokingHistory = v)),

    if (smokingHistory != "No") ...[
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel("Duration (Years)"),
            _buildTextField(
              controller: _smokingDurationCtrl,
              hint: "e.g. 5",
              keyboardType: TextInputType.number,
            ),
          ],
        )),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel("Frequency / day"),
            _buildTextField(
              controller: _smokingFreqCtrl,
              hint: "e.g. 10",
              keyboardType: TextInputType.number,
            ),
          ],
        )),
      ]),
    ],

    _buildSwitchTile("Smokeless Tobacco Use",
        smokelessTobacco,
        (v) => setState(() => smokelessTobacco = v)),

    _buildChoiceGroup("Alcohol Use",
        ["No", "Occasional", "Regular"], alcoholUse,
        (v) => setState(() => alcoholUse = v)),

    _sectionDivider(label: "Medical Conditions"),
    ...conditions.keys.map((k) => _buildSwitchTile(
        k, conditions[k]!,
        (v) => setState(() => conditions[k] = v))),
  ];

  List<Widget> _lesionHistoryChildren() => [
    _sectionDivider(),
    _buildChoiceGroup("Duration",
        ["< 2 weeks", "2-3 weeks", "> 3 weeks"], duration,
        (v) => setState(() => duration = v)),
    _buildChoiceGroup("Onset",
        ["Sudden", "Gradual"], onset,
        (v) => setState(() => onset = v)),
    const SizedBox(height: 14),
    _fieldLabel("Recurrence Pattern"),
    _buildDropdown<String>(
      value: recurrence,
      items: ["First episode",
              "Recurrent (same site)",
              "Recurrent (different sites)"],
      onChanged: (v) => setState(() => recurrence = v!),
    ),
    _buildChoiceGroup("Healing Pattern",
        ["Healing", "Non-healing", "Progressive"], healing,
        (v) => setState(() => healing = v)),
    _buildChoiceGroup("Pain Characteristics",
        ["Painful", "Painless"], pain,
        (v) => setState(() => pain = v)),
  ];

  List<Widget> _clinicalExamChildren() => [
    _sectionDivider(),
    _fieldLabel("Anatomical Site"),
    _buildDropdown<String>(
      value: (anatomicalSite == "Select anatomical site")
          ? null : anatomicalSite,
      hint: "Select anatomical site",
      items: [
        "Tongue (Lateral) ⚠️", "Tongue (Ventral) ⚠️",
        "Floor of Mouth ⚠️", "Buccal Mucosa",
        "Palate", "Gingiva", "Lip",
      ],
      onChanged: (v) => setState(() => anatomicalSite = v!),
      isRisk: (item) => item.contains('⚠️'),
    ),

    const SizedBox(height: 16),
    // Size stepper
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        const Icon(Icons.straighten_rounded, size: 16, color: _muted),
        const SizedBox(width: 10),
        Text("Lesion Size",
            style: TextStyle(
              color: _text.withOpacity(0.8), fontSize: 13,
              fontWeight: FontWeight.w500)),
        const Spacer(),
        GestureDetector(
          onTap: () =>
              setState(() { if (lesionSize > 0) lesionSize--; }),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.remove_rounded,
                size: 16, color: _text),
          ),
        ),
        SizedBox(
          width: 56,
          child: Center(
            child: Text("$lesionSize mm",
                style: const TextStyle(
                  color: _text, fontSize: 14,
                  fontWeight: FontWeight.w700)),
          ),
        ),
        GestureDetector(
          onTap: () => setState(() => lesionSize++),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: _maroon,
              borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.add_rounded,
                size: 16, color: Colors.white),
          ),
        ),
      ]),
    ),

    _buildChoiceGroup("Shape",
        ["Round/Ovoid", "Irregular"], shape,
        (v) => setState(() => shape = v)),
    _buildChoiceGroup("Margins",
        ["Well-defined", "Ill-defined"], margins,
        (v) => setState(() => margins = v)),

    const SizedBox(height: 14),
    _fieldLabel("Edge Type"),
    _buildDropdown<String>(
      value: (edgeType == "Select edge type") ? null : edgeType,
      hint: "Select edge type",
      items: ["Sloping", "Punched out", "Undermined",
              "Rolled", "Everted (Risk ⚠️)"],
      onChanged: (v) => setState(() => edgeType = v!),
      isRisk: (item) => item.contains('⚠️'),
    ),
    _buildSwitchTile("Induration Present",
        induration, (v) => setState(() => induration = v)),
    _buildSwitchTile("Bleeding on Touch",
        bleeding, (v) => setState(() => bleeding = v)),
  ];

  List<Widget> _associatedFindingsChildren() => [
    _sectionDivider(),
    _buildSwitchTile("Palpable Lymph Node",
        lymphNode, (v) => setState(() => lymphNode = v)),
    if (lymphNode) ...[
      _buildChoiceGroup("Tender (Lymph Node)",
          ["Yes", "No"], tenderNode,
          (v) => setState(() => tenderNode = v)),
      _buildChoiceGroup("Node Mobility",
          ["Mobile", "Fixed"], nodeMobility,
          (v) => setState(() => nodeMobility = v)),
    ],
    _buildSwitchTile("Paraesthesia / Anaesthesia",
        paraesthesia, (v) => setState(() => paraesthesia = v)),
    _buildSwitchTile("Unexplained Weight Loss",
        weightLoss, (v) => setState(() => weightLoss = v)),
    _buildSwitchTile("Persistent Fever",
        fever, (v) => setState(() => fever = v)),
  ];

  // ══════════════════════════════════════════════════════════════════════════
  //  SHARED UI COMPONENTS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCardHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required String step,
  }) {
    return Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _maroon, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                  color: _text, fontSize: 14,
                  fontWeight: FontWeight.w600)),
            Text(subtitle,
                style: TextStyle(
                    color: _muted, fontSize: 11.5)),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _maroon.withOpacity(0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(step,
            style: const TextStyle(
              color: _maroon, fontSize: 10,
              fontWeight: FontWeight.w700, letterSpacing: 0.5,
            )),
      ),
    ]);
  }

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Text(text,
        style: const TextStyle(
          color: _text, fontSize: 12,
          fontWeight: FontWeight.w600, letterSpacing: 0.2,
        )),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    String hint = '',
    TextInputType keyboardType = TextInputType.text,
    Widget? suffix,
    Function(String)? onSubmit,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onSubmitted: onSubmit,
        style: const TextStyle(
            color: _text, fontSize: 14,
            fontWeight: FontWeight.w400),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
              color: _muted.withOpacity(0.55), fontSize: 13.5),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    T? value,
    String? hint,
    required List<String> items,
    required Function(T?) onChanged,
    bool Function(String)? isRisk,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F3F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: hint != null
              ? Text(hint,
                  style: TextStyle(
                      color: _muted.withOpacity(0.55),
                      fontSize: 13.5))
              : null,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: _muted, size: 20),
          items: items.map((s) {
            final risk = isRisk?.call(s) ?? false;
            return DropdownMenuItem<T>(
              value: s as T,
              child: Text(s,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: risk ? _riskRed : _text,
                    fontWeight: risk
                        ? FontWeight.w600 : FontWeight.w400,
                  )),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildChoiceGroup(String label, List<String> opts,
      String current, Function(String) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        _fieldLabel(label),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: opts.map((o) {
            final selected = o == current;
            return GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? _maroon : const Color(0xFFF7F3F0),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? _maroon : _border,
                    width: 1,
                  ),
                ),
                child: Text(o,
                    style: TextStyle(
                      color: selected ? Colors.white : _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    )),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
      String label, bool val, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(
                color: _text, fontSize: 13,
                fontWeight: FontWeight.w400,
              )),
        ),
        Switch(
          value: val,
          onChanged: onChanged,
          activeColor: _maroon,
          activeTrackColor: _maroon.withOpacity(0.25),
          inactiveThumbColor: _muted.withOpacity(0.5),
          inactiveTrackColor: _border,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }

  Widget _sectionDivider({String? label}) {
    if (label == null) {
      return Container(
          height: 1, color: _border,
          margin: const EdgeInsets.symmetric(vertical: 12));
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Row(children: [
        Text(label,
            style: TextStyle(
              color: _muted, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 0.8,
            )),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 0.8, color: _border)),
      ]),
    );
  }

  // ── Proceed button ────────────────────────────────────────────────────────
  Widget _buildProceedButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isSubmitting ? null : _submitCase,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_maroon, _maroonD],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _maroon.withOpacity(0.35),
                    blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: Center(
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Proceed to Image Analysis",
                              style: TextStyle(
                                color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              )),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded,
                              color: Colors.white, size: 17),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}