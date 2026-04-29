import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

// ==========================================
// SUPABASE CONFIGURATION
// Replace these placeholders with your actual project credentials
// ==========================================

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");
  // REQUIRED: Initialize Health plugin for Android Health Connect
  Health().configure();
  //
  //await Supabase.initialize(
  //  url: SUPABASE_URL,
  //  anonKey: SUPABASE_ANON_KEY,
  //);

  await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL'] ?? '',
  anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  runApp(const ShiApp());
}

class ShiApp extends StatelessWidget {
  const ShiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHI-Sync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          primary: const Color(0xFF1E40AF),
          secondary: const Color(0xFF0D9488),
          surface: const Color(0xFFF8FAFC),
        ),
        useMaterial3: true,
        fontFamily: 'sans-serif', 
      ),
      home: const MainGatekeeper(),
    );
  }
}

// ==========================================
// TACTILE UI COMPONENTS (Design System)
// ==========================================

class AnimatedTactileButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color? color;
  final bool disabled;

  const AnimatedTactileButton({
    super.key,
    required this.child,
    this.onPressed,
    this.color,
    this.disabled = false,
  });

  @override
  State<AnimatedTactileButton> createState() => _AnimatedTactileButtonState();
}

class _AnimatedTactileButtonState extends State<AnimatedTactileButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => widget.disabled ? null : _controller.forward(),
      onTapUp: (_) => widget.disabled ? null : _controller.reverse(),
      onTapCancel: () => widget.disabled ? null : _controller.reverse(),
      onTap: widget.disabled ? null : widget.onPressed,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            color: widget.disabled ? const Color(0xFFE2E8F0) : (widget.color ?? const Color(0xFF1E40AF)),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.disabled ? null : [
              BoxShadow(
                color: (widget.color ?? const Color(0xFF1E40AF)).withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          alignment: Alignment.center,
          child: widget.child,
        ),
      ),
    );
  }
}

class TactileCard extends StatelessWidget {
  final Widget child;
  final Color? accentColor;

  const TactileCard({super.key, required this.child, this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (accentColor ?? const Color(0xFF64748B)).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: child,
    );
  }
}

// ==========================================
// CORE APP SCREENS
// ==========================================

class MainGatekeeper extends StatefulWidget {
  const MainGatekeeper({super.key});

  @override
  State<MainGatekeeper> createState() => _MainGatekeeperState();
}

class _MainGatekeeperState extends State<MainGatekeeper> {
  bool _isLoading = true;
  String? _uuid;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _uuid = prefs.getString('resident_uuid');
      _hasPermissions = prefs.getBool('health_permissions_granted') ?? false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_uuid != null && _hasPermissions) {
      return const DashboardScreen();
    } else if (_uuid != null) {
      return const PermissionScreen();
    } else {
      return const SetupScreen();
    }
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _barangayId = 1;
  String _ageGroup = '18-24';
  String _gender = 'Female'; // NEW
  bool _hasConsented = false;

  Future<void> _completeSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final newUuid = const Uuid().v4();
    
    await prefs.setString('resident_uuid', newUuid);
    await prefs.setInt('resident_barangay_id', _barangayId);
    await prefs.setString('resident_age', _ageGroup);
    await prefs.setString('resident_gender', _gender); // NEW
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const PermissionScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E40AF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sync, color: Color(0xFF1E40AF), size: 32),
              ),
              const SizedBox(height: 24),
              const Text('Onboarding', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Color(0xFF64748B), letterSpacing: 1.5)),
              const Text('SHI-Sync', 
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFF0F172A), height: 1.1)),
              const SizedBox(height: 16),
              const Text('Help build a healthier community in Quezon City by anonymously sharing your activity baseline.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.4)),
              const SizedBox(height: 32),
              
              TactileCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('RESIDENT LOCATION', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    DropdownButton<int>(
                      isExpanded: true,
                      value: _barangayId,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('Bgy. UP Campus', style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 2, child: Text('Bgy. Fairview', style: TextStyle(fontWeight: FontWeight.bold))),
                        DropdownMenuItem(value: 3, child: Text('Bgy. Payatas', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      onChanged: (val) => setState(() => _barangayId = val!),
                    ),
                    const Divider(height: 32),
                    const Text('AGE BRACKET', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _ageGroup,
                      underline: const SizedBox(),
                      items: ['18-24', '25-34', '35-44', '45-54', '55-64', '65+'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)));
                      }).toList(),
                      onChanged: (val) => setState(() => _ageGroup = val!),
                    ),

                    // INSERT THIS right below the Age Bracket DropdownButton
                    const Divider(height: 32),
                    const Text('GENDER AT BIRTH', 
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: _gender,
                      underline: const SizedBox(),
                      items: ['Female', 'Male'].map((String value) {
                        return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)));
                      }).toList(),
                      onChanged: (val) => setState(() => _gender = val!),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _hasConsented,
                      activeColor: const Color(0xFF1E40AF),
                      onChanged: (val) => setState(() => _hasConsented = val!),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _hasConsented = !_hasConsented),
                        child: const Text(
                          'I consent to share my anonymized data (RA 10173). No GPS or personal names are collected.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              AnimatedTactileButton(
                disabled: !_hasConsented,
                onPressed: _completeSetup,
                child: const Text('Initialize Sync', 
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  bool _isSyncing = false;
  bool _showError = false;

  Future<void> _requestAndSync() async {
    setState(() {
      _isSyncing = true;
      _showError = false;
    });
    
    try {
      Health health = Health();
      // FIX 1: Revert to WORKOUT so it matches the AndroidManifest permissions
      var types = [HealthDataType.STEPS, HealthDataType.WORKOUT];
      
      bool requested = await health.requestAuthorization(types);
      
      if (requested) {
        final prefs = await SharedPreferences.getInstance();
        
        var now = DateTime.now();
        var sevenDaysAgo = now.subtract(const Duration(days: 7));
        
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: sevenDaysAgo, 
          endTime: now, 
          types: types
        );
        
        // EDGE COMPUTING: ROLLING AVERAGE & DAILY LOGIC
        Map<String, int> dailySteps = {};
        Map<String, int> dailyMins = {};
        
        // FIX 2 & 3: Restore the Fingerprint Deduplicator and correct NumericHealthValue cast
        Map<String, int> uniqueStepChunks = {};
        List<HealthDataPoint> rawSteps = healthData.where((p) => p.type == HealthDataType.STEPS).toList();

        for (var p in rawSteps) {
          var stepsObject = p.value as NumericHealthValue;
          int val = stepsObject.numericValue.toInt();
          String fingerprint = "${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}_$val";
          uniqueStepChunks[fingerprint] = val;
        }

        for (var p in rawSteps) {
          var stepsObject = p.value as NumericHealthValue;
          int val = stepsObject.numericValue.toInt();
          String fingerprint = "${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}_$val";
          
          if (uniqueStepChunks.containsKey(fingerprint)) {
            String dateKey = DateFormat('yyyy-MM-dd').format(p.dateFrom);
            dailySteps[dateKey] = (dailySteps[dateKey] ?? 0) + val;
            uniqueStepChunks.remove(fingerprint); // Remove to prevent double counting exact clones
          }
        }

        // FIX 4: Restore the Workout duration calculation logic
        List<HealthDataPoint> workoutData = healthData.where((p) => p.type == HealthDataType.WORKOUT).toList();
        
        int walkWeekly = 0;
        int runWeekly = 0;
        int bikeWeekly = 0;
        int otherWeekly = 0;

        for (var p in workoutData) {
          String dateKey = DateFormat('yyyy-MM-dd').format(p.dateFrom);
          int durationMins = p.dateTo.difference(p.dateFrom).inMinutes;
          dailyMins[dateKey] = (dailyMins[dateKey] ?? 0) + durationMins;

          var workoutValue = p.value as WorkoutHealthValue;

          // Categorize the 7-day totals based on HealthConnect Activity Types
          if (workoutValue.workoutActivityType == HealthWorkoutActivityType.WALKING) {
            walkWeekly += durationMins;
          } else if (workoutValue.workoutActivityType == HealthWorkoutActivityType.RUNNING) {
            runWeekly += durationMins;
          } else if (workoutValue.workoutActivityType == HealthWorkoutActivityType.BIKING) {
            bikeWeekly += durationMins;
          } else {
            otherWeekly += durationMins;
          }
        }
        
        int weeklySum = walkWeekly + runWeekly + bikeWeekly + otherWeekly; // Calculate total

        // Extract Today's Data
        String todayKey = DateFormat('yyyy-MM-dd').format(now);
        int todaySteps = dailySteps[todayKey] ?? 0;
        int todayMins = dailyMins[todayKey] ?? 0;

        // Calculate Averages
        var activeStepDays = dailySteps.values.where((s) => s > 0).toList();
        int avgSteps = activeStepDays.isEmpty ? 0 : (activeStepDays.reduce((a, b) => a + b) / activeStepDays.length).round();
        
        var activeMinDays = dailyMins.values.where((s) => s > 0).toList();
        int avgMins = activeMinDays.isEmpty ? 0 : (activeMinDays.reduce((a, b) => a + b) / activeMinDays.length).round();

        await prefs.setBool('health_permissions_granted', true);
        await prefs.setInt('today_steps', todaySteps);
        await prefs.setInt('today_mins', todayMins);
        await prefs.setInt('avg_steps', avgSteps);
        await prefs.setInt('avg_mins', avgMins);
        
        // NEW: Save weekly breakdown and sum
        await prefs.setInt('walk_mins_weekly', walkWeekly);
        await prefs.setInt('run_mins_weekly', runWeekly);
        await prefs.setInt('bike_mins_weekly', bikeWeekly);
        await prefs.setInt('other_mins_weekly', otherWeekly);
        await prefs.setInt('weekly_exercise_mins', weeklySum);

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const DashboardScreen()),
          );
        }
      } else {
        setState(() => _showError = true);
      }
    } catch (e) {
      debugPrint("Health error: $e");
      setState(() => _showError = true);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFF43F5E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, size: 48, color: Color(0xFFF43F5E)),
              ),
              const SizedBox(height: 32),
              const Text('Connect Device', 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
              const SizedBox(height: 16),
              Text(
                _showError 
                  ? 'Permission Required: SHI-Sync cannot establish your activity baseline without access to Google Health Connect.'
                  : 'Allow SHI-Sync to read your Step and Exercise data to help establish a community health baseline.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              AnimatedTactileButton(
                onPressed: _isSyncing ? null : _requestAndSync,
                child: _isSyncing 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Grant Access', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
              if (_showError)
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const SetupScreen()));
                  },
                  child: const Text('Back to Setup', style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _todaySteps = 0;
  int _todayMins = 0;
  int _avgSteps = 0;
  int _avgMins = 0;
  int _weeklyExerciseMins = 0; // NEW
  String _uuid = '';
  bool _isSyncing = false;

  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadData().then((_) {
      _fetchFreshHealthData(); 
    });
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _todaySteps = prefs.getInt('today_steps') ?? 0;
      _todayMins = prefs.getInt('today_mins') ?? 0;
      _avgSteps = prefs.getInt('avg_steps') ?? 0;
      _avgMins = prefs.getInt('avg_mins') ?? 0;
      _weeklyExerciseMins = prefs.getInt('weekly_exercise_mins') ?? 0; // NEW
      _uuid = prefs.getString('resident_uuid') ?? '';
    });
  }

  // NEW FUNCTION: Fetch fresh data from Health Connect
  Future<void> _fetchFreshHealthData() async {
    setState(() => _isRefreshing = true);
    
    try {
      Health health = Health();
      var types = [HealthDataType.STEPS, HealthDataType.WORKOUT];
      bool hasPermissions = await health.hasPermissions(types) ?? false;
      
      if (!hasPermissions) {
        hasPermissions = await health.requestAuthorization(types);
      }

      if (hasPermissions) {
        var now = DateTime.now();
        var sevenDaysAgo = now.subtract(const Duration(days: 7));
        
        List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          startTime: sevenDaysAgo, endTime: now, types: types
        );
        
        // --- DEDUPLICATION & MATH (Same as we built before) ---
        Map<String, int> dailySteps = {};
        Map<String, int> dailyMins = {};
        Map<String, int> uniqueStepChunks = {};
        
        List<HealthDataPoint> rawSteps = healthData.where((p) => p.type == HealthDataType.STEPS).toList();
        for (var p in rawSteps) {
          var stepsObject = p.value as NumericHealthValue;
          int val = stepsObject.numericValue.toInt();
          String fingerprint = "${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}_$val";
          uniqueStepChunks[fingerprint] = val;
        }

        for (var p in rawSteps) {
          var stepsObject = p.value as NumericHealthValue;
          int val = stepsObject.numericValue.toInt();
          String fingerprint = "${p.dateFrom.millisecondsSinceEpoch}_${p.dateTo.millisecondsSinceEpoch}_$val";
          if (uniqueStepChunks.containsKey(fingerprint)) {
            String dateKey = DateFormat('yyyy-MM-dd').format(p.dateFrom);
            dailySteps[dateKey] = (dailySteps[dateKey] ?? 0) + val;
            uniqueStepChunks.remove(fingerprint); 
          }
        }

        List<HealthDataPoint> workoutData = healthData.where((p) => p.type == HealthDataType.WORKOUT).toList();
        
        int walkWeekly = 0;
        int runWeekly = 0;
        int bikeWeekly = 0;
        int otherWeekly = 0;

        for (var p in workoutData) {
          String dateKey = DateFormat('yyyy-MM-dd').format(p.dateFrom);
          int durationMins = p.dateTo.difference(p.dateFrom).inMinutes;
          dailyMins[dateKey] = (dailyMins[dateKey] ?? 0) + durationMins;

          var workoutValue = p.value as WorkoutHealthValue;

          // Categorize the 7-day totals based on HealthConnect Activity Types
          if (workoutValue.workoutActivityType == HealthWorkoutActivityType.WALKING) {
            walkWeekly += durationMins;
          } else if (workoutValue.workoutActivityType == HealthWorkoutActivityType.RUNNING) {
            runWeekly += durationMins;
          } else if (workoutValue.workoutActivityType == HealthWorkoutActivityType.BIKING) {
            bikeWeekly += durationMins;
          } else {
            otherWeekly += durationMins;
          }
        }
        
        int weeklySum = walkWeekly + runWeekly + bikeWeekly + otherWeekly; // Calculate total

        String todayKey = DateFormat('yyyy-MM-dd').format(now);
        int todaySteps = dailySteps[todayKey] ?? 0;
        int todayMins = dailyMins[todayKey] ?? 0;

        var activeStepDays = dailySteps.values.where((s) => s > 0).toList();
        int avgSteps = activeStepDays.isEmpty ? 0 : (activeStepDays.reduce((a, b) => a + b) / activeStepDays.length).round();
        
        var activeMinDays = dailyMins.values.where((s) => s > 0).toList();
        int avgMins = activeMinDays.isEmpty ? 0 : (activeMinDays.reduce((a, b) => a + b) / activeMinDays.length).round();

        // Save to cache
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('today_steps', todaySteps);
        await prefs.setInt('today_mins', todayMins);
        await prefs.setInt('avg_steps', avgSteps);
        await prefs.setInt('avg_mins', avgMins);
        
        // NEW: Save weekly breakdown and sum
        await prefs.setInt('walk_mins_weekly', walkWeekly);
        await prefs.setInt('run_mins_weekly', runWeekly);
        await prefs.setInt('bike_mins_weekly', bikeWeekly);
        await prefs.setInt('other_mins_weekly', otherWeekly);
        await prefs.setInt('weekly_exercise_mins', weeklySum);

        // Update UI instantly
        if (mounted) {
          setState(() {
            _todaySteps = todaySteps;
            _todayMins = todayMins;
            _avgSteps = avgSteps;
            _avgMins = avgMins;
            _weeklyExerciseMins = weeklySum;
          });
        }

        // --- NEW: AUTOMATIC SILENT UPLOAD LOGIC ---
        bool isFirstSession = prefs.getBool('is_first_session') ?? true;

        if (isFirstSession) {
          // It's a fresh install. Do not upload yet. Let them use Manual Push.
          await prefs.setBool('is_first_session', false);
          debugPrint("First session detected. Skipping automatic silent upload.");
        } else {
          // It's a succeeding session. Silently push to the database!
          debugPrint("Succeeding session detected. Triggering silent upload.");
          await _pushToSupabase(isSilent: true);
        }
        
      }
    } catch (e) {
      debugPrint("Background fetch error: $e");
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }
// ...

  Future<void> _launchHealthConnectGuide() async {
    final Uri url = Uri.parse('https://support.google.com/android/answer/12201227?hl=en');
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  Future<void> _pushToSupabase({bool isSilent = false}) async {
    if (!isSilent && mounted) {
      setState(() => _isSyncing = true);
    }
    
    try {

      if (_uuid.isEmpty) {
        debugPrint("Upload aborted: Resident UUID is missing.");
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final barangayId = prefs.getInt('resident_barangay_id') ?? 1;
      final ageGroup = prefs.getString('resident_age') ?? '25-34';
      final gender = prefs.getString('resident_gender') ?? 'Female'; // NEW
      
      final walkWeekly = prefs.getInt('walk_mins_weekly') ?? 0; // NEW
      final runWeekly = prefs.getInt('run_mins_weekly') ?? 0;   // NEW
      final bikeWeekly = prefs.getInt('bike_mins_weekly') ?? 0; // NEW
      final otherWeekly = prefs.getInt('other_mins_weekly') ?? 0; // NEW
      final weeklySum = prefs.getInt('weekly_exercise_mins') ?? 0; // NEW
      
      // 1. Ensure Resident Profile Exists
      await Supabase.instance.client
          .from('residents')
          .upsert({
            'id': _uuid,
            'barangay_id': barangayId,
            'age_group': ageGroup,
            'gender_at_birth': gender, // NEW
            'primary_source': 'HEALTH_CONNECT',
          });

      // 2. GLOBAL DEDUPLICATION CHECK (One record per resident)
      final existingLogs = await Supabase.instance.client
          .from('activity_logs')
          .select('id')
          .eq('resident_id', _uuid)
          .limit(1); // Grabs the resident's single record if it exists

      if (existingLogs.isNotEmpty) {
        // SCENARIO A: Update the resident's existing baseline record
        await Supabase.instance.client
            .from('activity_logs')
            .update({
              'source_type': 'HEALTH_CONNECT', 
              'daily_steps': _avgSteps,
              'weekly_exercise_mins': weeklySum, // FIXED: Now uses the actual sum, not the daily average
              'walking_mins_weekly': walkWeekly,
              'running_mins_weekly': runWeekly,
              'biking_mins_weekly': bikeWeekly,
              'other_sports_mins_weekly': otherWeekly,
              'local_timestamp': DateTime.now().toIso8601String(), // Refresh the timestamp
              'is_synced': true,
            })
            .eq('id', existingLogs[0]['id']); 
            
      } else {
        // SCENARIO B: Insert new database record (First time syncing)
        await Supabase.instance.client
            .from('activity_logs')
            .insert({
              'resident_id': _uuid,
              'source_type': 'HEALTH_CONNECT',
              'daily_steps': _avgSteps,
              'weekly_exercise_mins': weeklySum, // FIXED: Now uses the actual sum, not the daily average
              'walking_mins_weekly': walkWeekly,
              'running_mins_weekly': runWeekly,
              'biking_mins_weekly': bikeWeekly,
              'other_sports_mins_weekly': otherWeekly,
              'local_timestamp': DateTime.now().toIso8601String(),
              'is_synced': true,
            });
      }

      if (mounted && !isSilent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Activity baseline synced successfully!'), backgroundColor: Color(0xFF0D9488)),
        );
      }
    } catch (e) {
      debugPrint("Supabase Error: $e");
      if (mounted && !isSilent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync failed. Check connection.'), backgroundColor: Color(0xFFE11D48)),
        );
      }
    } finally {
        if (mounted && !isSilent) {
        setState(() => _isSyncing = false);
        }
      }
    }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('SHI-Sync', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: const Icon(Icons.shield_outlined, color: Color(0xFF0D9488)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            //Row(
            //  children: [
            //    const SizedBox(
            //      width: 8,
            //      height: 8,
            //      child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle)),
            //    ),
            //    const SizedBox(width: 8),
            //    const Text('Background Sync Active', 
            //      style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
            //  ],
            //),

            Row(
              children: [
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF0D9488), shape: BoxShape.circle)),
                ),
                const SizedBox(width: 8),
                const Text('Background Sync Active', 
                  style: TextStyle(color: Color(0xFF0D9488), fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                
                const Spacer(), // Pushes the refresh button to the far right
                
                // NEW: The Refresh Button
                _isRefreshing 
                  ? const SizedBox(
                      width: 16, height: 16, 
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0D9488))
                    )
                  : InkWell(
                      onTap: _fetchFreshHealthData,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.refresh, size: 20, color: Color(0xFF94A3B8)),
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 24),
            
            // --- NEW: Today's Progress ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFF64748B).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFFEDD5), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.local_fire_department, color: Color(0xFFEA580C), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text("Today's Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Steps Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('STEPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(NumberFormat('#,###').format(_todaySteps), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          const SizedBox(width: 4),
                          const Text('/ 10k', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_todaySteps / 10000).clamp(0.0, 1.0),
                      child: Container(decoration: BoxDecoration(color: const Color(0xFFF97316), borderRadius: BorderRadius.circular(6))),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Mins Progress
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('ACTIVE MINS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(_todayMins.toString(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                          const SizedBox(width: 4),
                          const Text('mins', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8))),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (_todayMins / 30).clamp(0.0, 1.0),
                      child: Container(decoration: BoxDecoration(color: const Color(0xFF14B8A6), borderRadius: BorderRadius.circular(6))),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // --- EXISTING (Modified): 7-Day Baseline ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                boxShadow: [BoxShadow(color: const Color(0xFF64748B).withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFE0E7FF), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.trending_up, color: Color(0xFF4F46E5), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Text("7-Day Baseline", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('This is the rolling average securely synced to the Quezon City census database.', 
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.4)),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AVG STEPS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Text(NumberFormat('#,###').format(_avgSteps), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF4338CA))),
                            ],
                          ),
                        )
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF1F5F9))),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AVG MINS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
                              const SizedBox(height: 4),
                              Text('$_weeklyExerciseMins', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0F766E))),
                            ],
                          ),
                        )
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // --- Anonymous ID ---
          //  Container(
          //    width: double.infinity,
          //    padding: const EdgeInsets.all(16),
          //    decoration: BoxDecoration(
          //     color: const Color(0xFFEFF6FF),
          //      borderRadius: BorderRadius.circular(16),
          //      border: Border.all(color: const Color(0xFFDBEAFE)),
          //    ),
          //    child: Column(
          //      children: [
          //        const Text('ANONYMOUS IDENTIFIER', 
          //          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Color(0xFF60A5FA), letterSpacing: 1)),
          //        const SizedBox(height: 4),
          //        Text(_uuid, 
          //          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center),
          //      ],
          //    ),
          //  ),


          //  const SizedBox(height: 24),

            // --- Troubleshooting Link ---
            Center(
              child: GestureDetector(
                onTap: _launchHealthConnectGuide,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Column(
                    children: [
                      Text(
                        "Not seeing your data?",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF64748B), // Slate 500
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.only(bottom: 2),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF0D9488), width: 1.5) // Teal underline
                          )
                        ),
                        child: const Text(
                          "View Health Connect Guide",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0D9488), // Teal 600
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            
            
            const SizedBox(height: 32),
            
            AnimatedTactileButton(
              onPressed: _isSyncing ? null : _pushToSupabase,
              color: const Color(0xFF0D9488),
              child: _isSyncing 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Manual Push to Cloud', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                    ],
                  ),
            ),
            
            const SizedBox(height: 12),
            
            Center(
              child: TextButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset Profile?', style: TextStyle(fontWeight: FontWeight.w900)),
                      content: const Text('This will generate a NEW anonymous ID. All future data will be attributed to your new demographics in the city database.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            if (mounted) {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (context) => const SetupScreen()),
                                (route) => false,
                              );
                            }
                          },
                          child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Update Demographics & Profile', 
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),

            const SizedBox(height: 32),

            // --- MOVED: Anonymous ID Block ---
            Center(
              child: Opacity(
                opacity: 0.5,
                child: Column(
                  children: [
                    const Text(
                      'ANONYMOUS IDENTIFIER', 
                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.5)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _uuid, 
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94A3B8))
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}