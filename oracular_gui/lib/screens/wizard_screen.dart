import 'dart:io';

import 'package:arcane/arcane.dart';

import '../main.dart';
import '../models/wizard_config.dart';
import '../services/project_service.dart';
import 'wizard/wizard.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final _config = WizardConfig();
  final _projectService = ProjectService();
  int _currentStep = 0;

  final _appNameController = TextEditingController(text: 'my_app');
  final _orgDomainController = TextEditingController(text: 'com.example');
  final _classNameController = TextEditingController(text: 'MyApp');
  final _firebaseIdController = TextEditingController();
  final _outputDirController = TextEditingController();

  String? _appNameError;
  String? _orgDomainError;
  String? _firebaseIdError;

  final List<LogEntry> _logs = [];
  bool _isCreating = false;
  bool _isComplete = false;
  double _currentProgress = 0;

  @override
  void initState() {
    super.initState();
    _outputDirController.text = _config.outputDir;
    _projectService.logStream.listen((e) => setState(() => _logs.add(e)));
    _projectService.progressStream.listen((p) => setState(() => _currentProgress = p));
  }

  @override
  void dispose() {
    _appNameController.dispose();
    _orgDomainController.dispose();
    _classNameController.dispose();
    _firebaseIdController.dispose();
    _outputDirController.dispose();
    _projectService.dispose();
    super.dispose();
  }

  void _validateAppName(String value) {
    final result = WizardValidators.validateAppName(value);
    setState(() {
      _appNameError = result.isValid ? null : result.errorMessage;
      if (result.isValid) {
        _config.appName = value;
        _classNameController.text = snakeToPascal(value);
        _config.baseClassName = _classNameController.text;
      }
    });
  }

  void _validateOrgDomain(String value) {
    final result = WizardValidators.validateOrgDomain(value);
    setState(() {
      _orgDomainError = result.isValid ? null : result.errorMessage;
      if (result.isValid) _config.orgDomain = value;
    });
  }

  void _validateFirebaseId(String value) {
    if (value.isEmpty && _config.useFirebase) {
      setState(() => _firebaseIdError = 'Firebase project ID is required');
      return;
    }
    if (value.isNotEmpty) {
      final result = WizardValidators.validateFirebaseProjectId(value);
      setState(() {
        _firebaseIdError = result.isValid ? null : result.errorMessage;
        if (result.isValid) _config.firebaseProjectId = value;
      });
    } else {
      setState(() {
        _firebaseIdError = null;
        _config.firebaseProjectId = null;
      });
    }
  }

  bool _canProceed() => switch (_currentStep) {
        0 => _appNameError == null && _appNameController.text.isNotEmpty,
        1 => true,
        2 => !_config.useFirebase || (_firebaseIdError == null && _firebaseIdController.text.isNotEmpty),
        3 => true,
        _ => false,
      };

  void _nextStep() => _currentStep < 3 ? setState(() => _currentStep++) : _createProject();
  void _prevStep() => _currentStep > 0 ? setState(() => _currentStep--) : null;

  Future<void> _createProject() async {
    setState(() {
      _isCreating = true;
      _logs.clear();
      _currentProgress = 0;
    });
    final success = await _projectService.createProject(_config);
    setState(() {
      _isCreating = false;
      _isComplete = success;
    });
  }

  void _reset() => setState(() {
        _currentStep = 0;
        _isCreating = false;
        _isComplete = false;
        _logs.clear();
        _currentProgress = 0;
      });

  @override
  Widget build(BuildContext context) {
    return Screen(
      header: Bar(
        titleText: 'Oracular',
        subtitleText: 'Arcane Project Wizard',
        trailing: [
          IconButton(
            icon: Icon(_themeIcon),
            onPressed: () => context.toggleTheme(),
          ),
        ],
      ),
      gutter: true,
      child: _isCreating
          ? ProgressScreen(progress: _currentProgress, logs: _logs)
          : _isComplete
              ? CompletionScreen(config: _config, onCreateAnother: _reset, onDone: () => exit(0))
              : _buildWizard(context),
    );
  }

  IconData get _themeIcon => switch (context.currentThemeMode) {
        ThemeMode.light => Icons.sun,
        ThemeMode.dark => Icons.moon,
        ThemeMode.system => Icons.monitor,
      };

  Widget _buildWizard(BuildContext context) {
    return Collection(
      children: [
        StepIndicator(currentStep: _currentStep),
        const Gap(32),
        _buildStep(),
        const Gap(32),
        _buildNavButtons(),
      ],
    );
  }

  Widget _buildStep() => switch (_currentStep) {
        0 => BasicsStep(
            config: _config,
            appNameController: _appNameController,
            orgDomainController: _orgDomainController,
            classNameController: _classNameController,
            outputDirController: _outputDirController,
            appNameError: _appNameError,
            orgDomainError: _orgDomainError,
            onAppNameChanged: _validateAppName,
            onOrgDomainChanged: _validateOrgDomain,
            onClassNameChanged: (v) => _config.baseClassName = v,
            onOutputDirChanged: (v) {
              _outputDirController.text = v;
              _config.outputDir = v;
            },
          ),
        1 => TemplateStep(
            selectedTemplate: _config.template,
            onTemplateChanged: (t) => setState(() => _config.updateTemplate(t)),
          ),
        2 => OptionsStep(
            config: _config,
            firebaseIdController: _firebaseIdController,
            firebaseIdError: _firebaseIdError,
            onFirebaseIdChanged: _validateFirebaseId,
            onCreateModelsChanged: (v) => setState(() => _config.createModels = v),
            onCreateServerChanged: (v) => setState(() => _config.createServer = v),
            onUseFirebaseChanged: (v) => setState(() {
              _config.useFirebase = v;
              if (!v) {
                _firebaseIdError = null;
                _config.firebaseProjectId = null;
              }
            }),
            onSetupCloudRunChanged: (v) => setState(() => _config.setupCloudRun = v),
            onPlatformToggled: (p) => setState(() => _config.togglePlatform(p)),
          ),
        3 => ReviewStep(config: _config),
        _ => const SizedBox.shrink(),
      };

  Widget _buildNavButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlineButton(
            onPressed: _prevStep,
            leading: const Icon(Icons.arrow_left),
            child: const Text('Back'),
          )
        else
          const SizedBox.shrink(),
        PrimaryButton(
          onPressed: _canProceed() ? _nextStep : null,
          trailing: _currentStep < 3 ? const Icon(Icons.arrow_right) : null,
          leading: _currentStep == 3 ? const Icon(Icons.magic_wand) : null,
          child: Text(_currentStep < 3 ? 'Continue' : 'Create Project'),
        ),
      ],
    );
  }
}
